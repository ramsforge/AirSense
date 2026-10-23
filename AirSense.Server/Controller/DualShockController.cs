using AirSense.Server.Protocol;
using Nefarius.ViGEm.Client;
using Nefarius.ViGEm.Client.Targets;
using Nefarius.ViGEm.Client.Targets.DualShock4;

namespace AirSense.Server.Controller;

public class DualShockController : IDisposable
{
    private readonly ViGEmClient _client;
    private readonly IDualShock4Controller _controller;
    private bool _disposed;

    public event Action<byte, byte, byte, byte, byte>? FeedbackReceived; // largeMotor, smallMotor, r, g, b

    public DualShockController()
    {
        _client = new ViGEmClient();
        _controller = _client.CreateDualShock4Controller();
        _controller.FeedbackReceived += OnFeedbackReceived;
        _controller.Connect();
    }

    private void OnFeedbackReceived(object sender, DualShock4FeedbackReceivedEventArgs e)
    {
        FeedbackReceived?.Invoke(
            e.LargeMotor,
            e.SmallMotor,
            e.LightbarColor.Red,
            e.LightbarColor.Green,
            e.LightbarColor.Blue
        );
    }

    public void UpdateState(in InputPacket packet)
    {
        if (_disposed) return;

        // 1. Digital Buttons
        _controller.SetButtonState(DualShock4Button.Cross, packet.Buttons.HasFlag(ControllerButtons.Cross));
        _controller.SetButtonState(DualShock4Button.Circle, packet.Buttons.HasFlag(ControllerButtons.Circle));
        _controller.SetButtonState(DualShock4Button.Square, packet.Buttons.HasFlag(ControllerButtons.Square));
        _controller.SetButtonState(DualShock4Button.Triangle, packet.Buttons.HasFlag(ControllerButtons.Triangle));

        _controller.SetButtonState(DualShock4Button.ShoulderLeft, packet.Buttons.HasFlag(ControllerButtons.L1));
        _controller.SetButtonState(DualShock4Button.ShoulderRight, packet.Buttons.HasFlag(ControllerButtons.R1));
        _controller.SetButtonState(DualShock4Button.TriggerLeft, packet.Buttons.HasFlag(ControllerButtons.L2Click) || packet.LeftTrigger > 200);
        _controller.SetButtonState(DualShock4Button.TriggerRight, packet.Buttons.HasFlag(ControllerButtons.R2Click) || packet.RightTrigger > 200);

        _controller.SetButtonState(DualShock4Button.ThumbLeft, packet.Buttons.HasFlag(ControllerButtons.L3));
        _controller.SetButtonState(DualShock4Button.ThumbRight, packet.Buttons.HasFlag(ControllerButtons.R3));

        _controller.SetButtonState(DualShock4Button.Share, packet.Buttons.HasFlag(ControllerButtons.Share));
        _controller.SetButtonState(DualShock4Button.Options, packet.Buttons.HasFlag(ControllerButtons.Options));

        // 2. Special Buttons (PS button = 0x01, Touchpad button = 0x02)
        byte special = 0;
        if (packet.Buttons.HasFlag(ControllerButtons.PSButton)) special |= 0x01;
        if (packet.Buttons.HasFlag(ControllerButtons.TouchpadClick)) special |= 0x02;
        _controller.SetSpecialButtonsFull(special);

        // 3. D-Pad (Hat switch)
        bool up = packet.Buttons.HasFlag(ControllerButtons.DPadUp);
        bool down = packet.Buttons.HasFlag(ControllerButtons.DPadDown);
        bool left = packet.Buttons.HasFlag(ControllerButtons.DPadLeft);
        bool right = packet.Buttons.HasFlag(ControllerButtons.DPadRight);

        DualShock4DPadDirection dpad = DualShock4DPadDirection.None;
        if (up && right) dpad = DualShock4DPadDirection.Northeast;
        else if (up && left) dpad = DualShock4DPadDirection.Northwest;
        else if (down && right) dpad = DualShock4DPadDirection.Southeast;
        else if (down && left) dpad = DualShock4DPadDirection.Southwest;
        else if (up) dpad = DualShock4DPadDirection.North;
        else if (down) dpad = DualShock4DPadDirection.South;
        else if (left) dpad = DualShock4DPadDirection.West;
        else if (right) dpad = DualShock4DPadDirection.East;

        _controller.SetDPadDirection(dpad);

        // 4. Analog Sticks: Convert short (-32768..32767) to byte (0..255), with Y inverted (DirectInput up is 0)
        byte lx = ConvertStickAxis(packet.LeftStickX);
        byte ly = ConvertStickAxis((short)-packet.LeftStickY); // Invert so positive Y (up) maps towards 0
        byte rx = ConvertStickAxis(packet.RightStickX);
        byte ry = ConvertStickAxis((short)-packet.RightStickY);

        _controller.SetAxisValue(DualShock4Axis.LeftThumbX, lx);
        _controller.SetAxisValue(DualShock4Axis.LeftThumbY, ly);
        _controller.SetAxisValue(DualShock4Axis.RightThumbX, rx);
        _controller.SetAxisValue(DualShock4Axis.RightThumbY, ry);

        // 5. Analog Triggers
        _controller.SetSliderValue(DualShock4Slider.LeftTrigger, packet.LeftTrigger);
        _controller.SetSliderValue(DualShock4Slider.RightTrigger, packet.RightTrigger);
    }

    public void Reset()
    {
        if (_disposed) return;
        var neutral = new InputPacket();
        UpdateState(in neutral);
    }

    private static byte ConvertStickAxis(short value)
    {
        // -32768 -> 0, 0 -> 128, 32767 -> 255
        int normalized = (value + 32768) / 256;
        return (byte)Math.Clamp(normalized, 0, 255);
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        try
        {
            _controller.Disconnect();
            _client.Dispose();
        }
        catch { }
    }
}
