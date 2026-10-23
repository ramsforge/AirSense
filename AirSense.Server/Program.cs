using System.Net;
using System.Net.Sockets;
using AirSense.Server.Controller;
using AirSense.Server.Network;

Console.Title = "AirSense Server - PS5 DualSense & Universal PC Controller";
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
   ║   Virtual PS5 DualSense & Universal Gamepad Bridge    ║
   ╚═══════════════════════════════════════════════════════╝
");
Console.ResetColor();

try
{
    // Start with PS5 DualSense Controller (VID 0x054C, PID 0x0CE6)
    IGamepadController activeGamepad = new DualSenseController();

    Console.ForegroundColor = ConsoleColor.Green;
    Console.WriteLine($"✓ {activeGamepad.ControllerType} initialized and connected!");
    Console.ResetColor();

    using var server = new UdpServer(activeGamepad);
    server.Start();

    Console.WriteLine("\n[Hotkeys]");
    Console.WriteLine("  Press [P] -> Switch to PS5 DualSense Mode (VID: 0x054C, PID: 0x0CE6)");
    Console.WriteLine("  Press [X] -> Switch to Xbox 360 / Universal PC Mode (Fixes rotated buttons in non-Sony PC games)");
    Console.WriteLine("  Press [Ctrl+C] -> Disconnect and Exit");

    Console.WriteLine("\nLocal IP Addresses for AirSense mobile app:");
    var host = Dns.GetHostEntry(Dns.GetHostName());
    foreach (var ip in host.AddressList)
    {
        if (ip.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(ip))
        {
            Console.WriteLine($"  ➜  {ip}:{UdpServer.DefaultPort}");
        }
    }

    Console.WriteLine("\n[Status] Waiting for AirSense phone app to connect...\n");

    // Hotkey listener loop
    while (true)
    {
        var key = Console.ReadKey(intercept: true).Key;

        if (key == ConsoleKey.X)
        {
            if (server.Controller is not Xbox360Gamepad)
            {
                server.SwitchController(new Xbox360Gamepad());
                Console.WriteLine("💡 Tip: Xbox 360 Mode maps Cross -> A, Circle -> B, Square -> X, Triangle -> Y.");
            }
        }
        else if (key == ConsoleKey.P)
        {
            if (server.Controller is not DualSenseController)
            {
                server.SwitchController(new DualSenseController());
                Console.WriteLine("💡 Tip: PS5 DualSense Mode uses Sony VID 0x054C & PID 0x0CE6.");
            }
        }
    }
}
catch (Exception ex)
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.WriteLine($"\n[Fatal Error] AirSense Server encountered an error: {ex.Message}");
    Console.ResetColor();
}
