using System.Net;
using System.Net.Sockets;
using System.Text;
using AirSense.Server.Controller;
using AirSense.Server.Protocol;

namespace AirSense.Server.Network;

public class UdpServer : IDisposable
{
    public const int DefaultPort = 9050;
    private readonly UdpClient _udpClient;
    private readonly DualShockController _controller;
    private readonly CancellationTokenSource _cts = new();
    private IPEndPoint? _activeClient;
    private DateTime _lastInputTime = DateTime.MinValue;
    private long _packetsReceived = 0;
    private bool _disposed;

    public UdpServer(DualShockController controller, int port = DefaultPort)
    {
        _controller = controller;
        _controller.FeedbackReceived += OnControllerFeedback;

        _udpClient = new UdpClient(new IPEndPoint(IPAddress.Any, port));
        _udpClient.EnableBroadcast = true;
    }

    public void Start()
    {
        Console.WriteLine($"[AirSense Server] Listening on UDP port {((IPEndPoint)_udpClient.Client.LocalEndPoint!).Port}...");
        Task.Run(ReceiveLoop);
        Task.Run(WatchdogLoop);
    }

    private async Task ReceiveLoop()
    {
        var buffer = new byte[1024];

        while (!_cts.IsCancellationRequested)
        {
            try
            {
                var result = await _udpClient.ReceiveAsync(_cts.Token);
                var data = result.Buffer;

                if (data.Length < 5) continue;

                // Magic check: "AIRS"
                if (data[0] != 0x41 || data[1] != 0x49 || data[2] != 0x52 || data[3] != 0x53)
                    continue;

                var type = (PacketType)data[4];

                switch (type)
                {
                    case PacketType.DiscoveryPing:
                        await HandleDiscoveryPing(result.RemoteEndPoint);
                        break;

                    case PacketType.InputFrame:
                        if (InputPacket.TryParse(data, out var packet))
                        {
                            if (_activeClient == null || !_activeClient.Equals(result.RemoteEndPoint))
                            {
                                _activeClient = result.RemoteEndPoint;
                                Console.ForegroundColor = ConsoleColor.Green;
                                Console.WriteLine($"\n[Connected] Controller paired with {_activeClient}");
                                Console.ResetColor();
                            }

                            _lastInputTime = DateTime.UtcNow;
                            _packetsReceived++;
                            _controller.UpdateState(in packet);
                        }
                        break;

                    case PacketType.Heartbeat:
                        _lastInputTime = DateTime.UtcNow;
                        break;
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                if (!_disposed)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"[Error] UDP receive error: {ex.Message}");
                    Console.ResetColor();
                }
            }
        }
    }

    private async Task HandleDiscoveryPing(IPEndPoint remoteEndPoint)
    {
        // Response format: "AIRS" + 0x02 + HostNameLength (1 byte) + HostName (UTF8)
        var hostName = Environment.MachineName;
        var hostNameBytes = Encoding.UTF8.GetBytes(hostName);
        var response = new byte[5 + 1 + hostNameBytes.Length];

        response[0] = 0x41; // A
        response[1] = 0x49; // I
        response[2] = 0x52; // R
        response[3] = 0x53; // S
        response[4] = (byte)PacketType.DiscoveryPong;
        response[5] = (byte)hostNameBytes.Length;
        Array.Copy(hostNameBytes, 0, response, 6, hostNameBytes.Length);

        await _udpClient.SendAsync(response, response.Length, remoteEndPoint);
        Console.WriteLine($"[Discovery] Responded to discovery beacon from {remoteEndPoint}");
    }

    private void OnControllerFeedback(byte largeMotor, byte smallMotor, byte r, byte g, byte b)
    {
        if (_activeClient == null || _disposed) return;

        // Feedback packet: "AIRS" + 0x20 + LargeMotor + SmallMotor + R + G + B (9 bytes)
        var packet = new byte[10];
        packet[0] = 0x41;
        packet[1] = 0x49;
        packet[2] = 0x52;
        packet[3] = 0x53;
        packet[4] = (byte)PacketType.RumbleFeedback;
        packet[5] = largeMotor;
        packet[6] = smallMotor;
        packet[7] = r;
        packet[8] = g;
        packet[9] = b;

        try
        {
            _udpClient.Send(packet, packet.Length, _activeClient);
        }
        catch { }
    }

    private async Task WatchdogLoop()
    {
        while (!_cts.IsCancellationRequested)
        {
            await Task.Delay(1000, _cts.Token);

            if (_activeClient != null && (DateTime.UtcNow - _lastInputTime).TotalSeconds > 2.5)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"[Disconnected] No inputs received from {_activeClient} for >2.5s. Resetting virtual controller...");
                Console.ResetColor();

                _activeClient = null;
                _controller.Reset();
            }
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _cts.Cancel();
        _controller.FeedbackReceived -= OnControllerFeedback;
        _udpClient.Dispose();
        _cts.Dispose();
    }
}
