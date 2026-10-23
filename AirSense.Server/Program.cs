using System.Net;
using System.Net.Sockets;
using AirSense.Server.Controller;
using AirSense.Server.Network;

Console.Title = "AirSense Server - Virtual DualSense / PS4 Bridge";
Console.OutputEncoding = System.Text.Encoding.UTF8;

Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine(@"
   ╔═══════════════════════════════════════════════════════╗
   ║                                                       ║
   ║       █████╗ ██╗██████╗ ███████╗███████╗███╗   ██╗     ║
   ║      ██╔══██╗██║██╔══██╗██╔════╝██╔════╝████╗  ██║     ║
   ║      ███████║██║██████╔╝███████╗█████╗  ██╔██╗ ██║     ║
   ║      ██╔══██║██║██╔══██╗╚════██║██╔══╝  ██║╚██╗██║     ║
   ║      ██║  ██║██║██║  ██║███████║███████╗██║ ╚████║     ║
   ║      ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═══╝     ║
   ║                                                       ║
   ║      Virtual PlayStation Controller Bridge for PC     ║
   ╚═══════════════════════════════════════════════════════╝
");
Console.ResetColor();

Console.WriteLine("Initializing ViGEmBus virtual controller...");

try
{
    using var controller = new DualShockController();
    Console.ForegroundColor = ConsoleColor.Green;
    Console.WriteLine("✓ Virtual DualShock 4 Controller created and plugged in successfully!");
    Console.ResetColor();

    using var server = new UdpServer(controller);
    server.Start();

    // Print local IPs for manual connection fallback
    Console.WriteLine("\nLocal IP Addresses for manual connection (if auto-discovery is blocked):");
    var host = Dns.GetHostEntry(Dns.GetHostName());
    foreach (var ip in host.AddressList)
    {
        if (ip.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(ip))
        {
            Console.WriteLine($"  ➜  {ip}:{UdpServer.DefaultPort}");
        }
    }

    Console.WriteLine("\n[Status] Waiting for AirSense mobile client to connect...");
    Console.WriteLine("Press [Ctrl+C] to disconnect controller and exit.\n");

    var tcs = new TaskCompletionSource();
    Console.CancelKeyPress += (s, e) =>
    {
        e.Cancel = true;
        Console.WriteLine("\nShutting down AirSense Server...");
        tcs.TrySetResult();
    };

    await tcs.Task;
}
catch (Exception ex)
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.WriteLine($"\n[Fatal Error] Failed to start AirSense Server: {ex.Message}");
    Console.WriteLine(ex.ToString());
    Console.ResetColor();
}
