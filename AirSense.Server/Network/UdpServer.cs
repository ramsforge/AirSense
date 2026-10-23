using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using AirSense.Server.Controller;
using AirSense.Server.Protocol;

namespace AirSense.Server.Network;

public class UdpServer : IDisposable
{
    public const int DefaultPort = 9050;
    private readonly UdpClient _udpClient;
    private IGamepadController _controller;
    private readonly CancellationTokenSource _cts = new();
    private IPEndPoint? _activeClient;
    private DateTime _lastInputTime = DateTime.MinValue;
    private long _packetsReceived = 0;
    private bool _disposed;

    // Sequence tracking for out-of-order UDP packet protection
    private uint _lastProcessedSequence = 0;
    private bool _hasReceivedFirstSequence = false;

    // Windows mouse emulation for touchpad
    [DllImport("user32.dll")]
    private static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
    private const uint MOUSEEVENTF_MOVE = 0x0001;
    private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const uint MOUSEEVENTF_LEFTUP = 0x0004;
    private bool _lastTouchpadActive = false;
    private ushort _lastTouchpadX = 0;
    private ushort _lastTouchpadY = 0;
    private bool _touchpadClickDown = false;

    public IGamepadController Controller => _controller;
    public ControllerMode ActiveMode => _controller is Xbox360Gamepad ? ControllerMode.Xbox360 : ControllerMode.DualSensePS5;

    public UdpServer(IGamepadController controller, int port = DefaultPort)
    {
        _controller = controller;
        _controller.FeedbackReceived += OnControllerFeedback;

        _udpClient = new UdpClient(new IPEndPoint(IPAddress.Any, port));
        _udpClient.EnableBroadcast = true;
    }

    public void SwitchController(IGamepadController newController)
    {
        _controller.FeedbackReceived -= OnControllerFeedback;
        _controller.Dispose();

        _controller = newController;
        _controller.FeedbackReceived += OnControllerFeedback;
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine($"\n[Switched] Active Gamepad is now: {_controller.ControllerType}");
        Console.ResetColor();
    }

    public void Start()
    {
        Console.WriteLine($"[AirSense Server] Listening on UDP port {((IPEndPoint)_udpClient.Client.LocalEndPoint!).Port}...");
        Task.Run(ReceiveLoop);
        Task.Run(WatchdogLoop);
    }

    private async Task ReceiveLoop()
    {
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

                    case PacketType.ConnectRequest:
                        await HandleConnectRequest(result.RemoteEndPoint);
                        break;

                    case PacketType.InputFrame:
                        HandleInputFrame(data, result.RemoteEndPoint);
                        break;

                    case PacketType.Heartbeat:
                        await HandleHeartbeat(data, result.RemoteEndPoint);
                        break;

                    case PacketType.SetControllerMode:
                        await HandleSetControllerMode(data, result.RemoteEndPoint);
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
    }

    private async Task HandleConnectRequest(IPEndPoint remoteEndPoint)
    {
        _activeClient = remoteEndPoint;
        _hasReceivedFirstSequence = false;
        _lastProcessedSequence = 0;
        _lastInputTime = DateTime.UtcNow;

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine($"\n[Connected] Controller paired with {_activeClient} ({ActiveMode})");
        Console.ResetColor();

        var hostName = Environment.MachineName;
        var hostNameBytes = Encoding.UTF8.GetBytes(hostName);
        var response = new byte[5 + 1 + 1 + hostNameBytes.Length];

        response[0] = 0x41;
        response[1] = 0x49;
        response[2] = 0x52;
        response[3] = 0x53;
        response[4] = (byte)PacketType.ConnectAck;
        response[5] = (byte)ActiveMode;
        response[6] = (byte)hostNameBytes.Length;
        Array.Copy(hostNameBytes, 0, response, 7, hostNameBytes.Length);

        await _udpClient.SendAsync(response, response.Length, remoteEndPoint);
    }

    private void HandleInputFrame(byte[] data, IPEndPoint remoteEndPoint)
    {
        if (!InputPacket.TryParse(data, out var packet))
            return;

        // Sequence number check: discard duplicate or out-of-order UDP packets
        if (!_hasReceivedFirstSequence)
        {
            _hasReceivedFirstSequence = true;
            _lastProcessedSequence = packet.SequenceNumber;
        }
        else
        {
            // Handle 32-bit wrap around using signed difference
            int diff = unchecked((int)(packet.SequenceNumber - _lastProcessedSequence));
            if (diff <= 0)
            {
                // Discard stale/duplicate packet
                return;
            }
            _lastProcessedSequence = packet.SequenceNumber;
        }

        if (_activeClient == null || !_activeClient.Equals(remoteEndPoint))
        {
            _activeClient = remoteEndPoint;
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"\n[Connected] Controller paired with {_activeClient}");
            Console.ResetColor();
        }

        _lastInputTime = DateTime.UtcNow;
        _packetsReceived++;

        // Update physical gamepad state
        _controller.UpdateState(in packet);

        // Process Touchpad Desktop Mouse Emulation if on Windows
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            ProcessTouchpad(packet);
        }
    }

    private void ProcessTouchpad(in InputPacket packet)
    {
        if (packet.TouchpadActive != 0)
        {
            if (_lastTouchpadActive)
            {
                int dx = packet.TouchpadX - _lastTouchpadX;
                int dy = packet.TouchpadY - _lastTouchpadY;

                // Ignore sudden finger jumps (e.g. lift and tap new location)
                if (Math.Abs(dx) < 180 && Math.Abs(dy) < 180 && (dx != 0 || dy != 0))
                {
                    // Scale sensitivity gently
                    int moveX = (int)(dx * 1.5f);
                    int moveY = (int)(dy * 1.5f);
                    mouse_event(MOUSEEVENTF_MOVE, moveX, moveY, 0, UIntPtr.Zero);
                }
            }

            _lastTouchpadActive = true;
            _lastTouchpadX = packet.TouchpadX;
            _lastTouchpadY = packet.TouchpadY;
        }
        else
        {
            _lastTouchpadActive = false;
        }

        // Handle Touchpad Click -> Left Mouse Click
        bool isClick = packet.Buttons.HasFlag(ControllerButtons.TouchpadClick);
        if (isClick && !_touchpadClickDown)
        {
            _touchpadClickDown = true;
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        }
        else if (!isClick && _touchpadClickDown)
        {
            _touchpadClickDown = false;
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
        }
    }

    private async Task HandleHeartbeat(byte[] data, IPEndPoint remoteEndPoint)
    {
        _lastInputTime = DateTime.UtcNow;

        if (data.Length >= 13)
        {
            long timestampMs = BitConverter.ToInt64(data.AsSpan(5, 8));

            // Echo back timestamp in HeartbeatAck along with current controller mode
            var response = new byte[14];
            response[0] = 0x41;
            response[1] = 0x49;
            response[2] = 0x52;
            response[3] = 0x53;
            response[4] = (byte)PacketType.HeartbeatAck;
            BitConverter.TryWriteBytes(response.AsSpan(5, 8), timestampMs);
            response[13] = (byte)ActiveMode;

            await _udpClient.SendAsync(response, response.Length, remoteEndPoint);
        }
    }

    private async Task HandleSetControllerMode(byte[] data, IPEndPoint remoteEndPoint)
    {
        if (data.Length >= 6)
        {
            var requestedMode = (ControllerMode)data[5];
            if (requestedMode == ControllerMode.DualSensePS5 && _controller is not DualSenseController)
            {
                SwitchController(new DualSenseController());
            }
            else if (requestedMode == ControllerMode.Xbox360 && _controller is not Xbox360Gamepad)
            {
                SwitchController(new Xbox360Gamepad());
            }

            // Acknowledge controller mode switch
            var response = new byte[6];
            response[0] = 0x41;
            response[1] = 0x49;
            response[2] = 0x52;
            response[3] = 0x53;
            response[4] = (byte)PacketType.ControllerModeAck;
            response[5] = (byte)ActiveMode;

            await _udpClient.SendAsync(response, response.Length, remoteEndPoint);
        }
    }

    private void OnControllerFeedback(byte largeMotor, byte smallMotor, byte r, byte g, byte b)
    {
        if (_activeClient == null || _disposed) return;

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

            if (_activeClient != null && (DateTime.UtcNow - _lastInputTime).TotalSeconds > 3.0)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"[Disconnected] No inputs received from {_activeClient} for >3.0s. Neutralizing controller...");
                Console.ResetColor();

                _activeClient = null;
                _controller.Reset();
                _hasReceivedFirstSequence = false;
                _lastProcessedSequence = 0;
            }
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _cts.Cancel();
        _controller.FeedbackReceived -= OnControllerFeedback;
        _controller.Dispose();
        _udpClient.Dispose();
        _cts.Dispose();
    }
}
