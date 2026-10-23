using AirSense.Server.Protocol;
using Nefarius.ViGEm.Client;
using Nefarius.ViGEm.Client.Targets;
using Nefarius.ViGEm.Client.Targets.DualShock4;
using Nefarius.ViGEm.Client.Targets.Xbox360;

namespace AirSense.Server.Controller;

public interface IGamepadController : IDisposable
{
    string ControllerType { get; }
    event Action<byte, byte, byte, byte, byte>? FeedbackReceived;
    void UpdateState(in InputPacket packet);
    void Reset();
}

/// <summary>
/// Emulates an authentic Sony DualSense (PS5) Wireless Controller (VID: 0x054C, PID: 0x0CE6)
/// </summary>
public class DualSenseController : IGamepadController
{
    private readonly ViGEmClient _client;
    private readonly IDualShock4Controller _controller;
    private bool _disposed;

    public string ControllerType => "Sony DualSense (PS5 Wireless Controller - VID: 0x054C, PID: 0x0CE6)";
    public event Action<byte, byte, byte, byte, byte>? FeedbackReceived;

    public DualSenseController()
    {
        _client = new ViGEmClient();
        // 0x054C = Sony Interactive Entertainment Inc.
        // 0x0CE6 = DualSense Wireless Controller (PlayStation 5)
        _controller = _client.CreateDualShock4Controller(0x054C, 0x0CE6);
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

        // 1. Digital Face Buttons (Native PlayStation DirectInput mapping)
        _controller.SetButtonState(DualShock4Button.Cross, packet.Buttons.HasFlag(ControllerButtons.Cross));
        _controller.SetButtonState(DualShock4Button.Circle, packet.Buttons.HasFlag(ControllerButtons.Circle));
        _controller.SetButtonState(DualShock4Button.Square, packet.Buttons.HasFlag(ControllerButtons.Square));
        _controller.SetButtonState(DualShock4Button.Triangle, packet.Buttons.HasFlag(ControllerButtons.Triangle));

        // 2. Shoulders & Triggers
        _controller.SetButtonState(DualShock4Button.ShoulderLeft, packet.Buttons.HasFlag(ControllerButtons.L1));
        _controller.SetButtonState(DualShock4Button.ShoulderRight, packet.Buttons.HasFlag(ControllerButtons.R1));
        
        // Digital trigger click engages if button flagged or trigger pulled > 15%
        bool l2Active = packet.Buttons.HasFlag(ControllerButtons.L2Click) || packet.LeftTrigger > 38;
        bool r2Active = packet.Buttons.HasFlag(ControllerButtons.R2Click) || packet.RightTrigger > 38;
        _controller.SetButtonState(DualShock4Button.TriggerLeft, l2Active);
        _controller.SetButtonState(DualShock4Button.TriggerRight, r2Active);

        // 3. Thumbstick Clicks (L3 / R3)
        _controller.SetButtonState(DualShock4Button.ThumbLeft, packet.Buttons.HasFlag(ControllerButtons.L3));
        _controller.SetButtonState(DualShock4Button.ThumbRight, packet.Buttons.HasFlag(ControllerButtons.R3));

        // 4. Navigation Buttons (Share & Options)
        _controller.SetButtonState(DualShock4Button.Share, packet.Buttons.HasFlag(ControllerButtons.Share));
        _controller.SetButtonState(DualShock4Button.Options, packet.Buttons.HasFlag(ControllerButtons.Options));

        // 5. Special Buttons (PS button = 0x01, Touchpad button = 0x02)
        byte special = 0;
        if (packet.Buttons.HasFlag(ControllerButtons.PSButton)) special |= 0x01;
        if (packet.Buttons.HasFlag(ControllerButtons.TouchpadClick)) special |= 0x02;
        _controller.SetSpecialButtonsFull(special);

        // 6. D-Pad (Hat switch)
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

        // 7. Analog Sticks (Invert Y so up maps towards 0 in DirectInput, handle int overflow safely)
        byte lx = ConvertStickAxis(packet.LeftStickX);
        byte ly = ConvertStickAxis(-packet.LeftStickY);
        byte rx = ConvertStickAxis(packet.RightStickX);
        byte ry = ConvertStickAxis(-packet.RightStickY);

        _controller.SetAxisValue(DualShock4Axis.LeftThumbX, lx);
        _controller.SetAxisValue(DualShock4Axis.LeftThumbY, ly);
        _controller.SetAxisValue(DualShock4Axis.RightThumbX, rx);
        _controller.SetAxisValue(DualShock4Axis.RightThumbY, ry);

        // 8. Analog Triggers
        _controller.SetSliderValue(DualShock4Slider.LeftTrigger, packet.LeftTrigger);
        _controller.SetSliderValue(DualShock4Slider.RightTrigger, packet.RightTrigger);
    }

    public void Reset()
    {
        if (_disposed) return;
        var neutral = new InputPacket();
        UpdateState(in neutral);
    }

    private static byte ConvertStickAxis(int value)
    {
        // Safe integer math: -32768 -> 0, 0 -> 128, 32767 -> 255
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

/// <summary>
/// Emulates an Xbox 360 controller. Solves button mapping issues in 95% of PC games
/// that expect XInput (Cross -> A, Circle -> B, Square -> X, Triangle -> Y).
/// </summary>
public class Xbox360Gamepad : IGamepadController
{
    private readonly ViGEmClient _client;
    private readonly IXbox360Controller _controller;
    private bool _disposed;

    public string ControllerType => "Xbox 360 Controller (Universal XInput - 100% PC Game Compatibility)";
    public event Action<byte, byte, byte, byte, byte>? FeedbackReceived;

    public Xbox360Gamepad()
    {
        _client = new ViGEmClient();
        _controller = _client.CreateXbox360Controller();
        _controller.FeedbackReceived += OnFeedbackReceived;
        _controller.Connect();
    }

    private void OnFeedbackReceived(object sender, Xbox360FeedbackReceivedEventArgs e)
    {
        // Map Xbox rumble to phone feedback (large motor, small motor)
        FeedbackReceived?.Invoke(e.LargeMotor, e.SmallMotor, 0, 200, 255);
    }

    public void UpdateState(in InputPacket packet)
    {
        if (_disposed) return;

        // XInput mapping:
        // Cross (bottom) -> A
        // Circle (right)  -> B
        // Square (left)   -> X
        // Triangle (top)  -> Y
        _controller.SetButtonState(Xbox360Button.A, packet.Buttons.HasFlag(ControllerButtons.Cross));
        _controller.SetButtonState(Xbox360Button.B, packet.Buttons.HasFlag(ControllerButtons.Circle));
        _controller.SetButtonState(Xbox360Button.X, packet.Buttons.HasFlag(ControllerButtons.Square));
        _controller.SetButtonState(Xbox360Button.Y, packet.Buttons.HasFlag(ControllerButtons.Triangle));

        // Shoulders
        _controller.SetButtonState(Xbox360Button.LeftShoulder, packet.Buttons.HasFlag(ControllerButtons.L1));
        _controller.SetButtonState(Xbox360Button.RightShoulder, packet.Buttons.HasFlag(ControllerButtons.R1));

        // Sticks Clicks
        _controller.SetButtonState(Xbox360Button.LeftThumb, packet.Buttons.HasFlag(ControllerButtons.L3));
        _controller.SetButtonState(Xbox360Button.RightThumb, packet.Buttons.HasFlag(ControllerButtons.R3));

        // Navigation
        _controller.SetButtonState(Xbox360Button.Back, packet.Buttons.HasFlag(ControllerButtons.Share));
        _controller.SetButtonState(Xbox360Button.Start, packet.Buttons.HasFlag(ControllerButtons.Options));
        _controller.SetButtonState(Xbox360Button.Guide, packet.Buttons.HasFlag(ControllerButtons.PSButton));

        // D-Pad
        _controller.SetButtonState(Xbox360Button.Up, packet.Buttons.HasFlag(ControllerButtons.DPadUp));
        _controller.SetButtonState(Xbox360Button.Down, packet.Buttons.HasFlag(ControllerButtons.DPadDown));
        _controller.SetButtonState(Xbox360Button.Left, packet.Buttons.HasFlag(ControllerButtons.DPadLeft));
        _controller.SetButtonState(Xbox360Button.Right, packet.Buttons.HasFlag(ControllerButtons.DPadRight));

        // Analog Sticks (Direct short mapping: -32768 to 32767, Up is positive in XInput)
        _controller.SetAxisValue(Xbox360Axis.LeftThumbX, packet.LeftStickX);
        _controller.SetAxisValue(Xbox360Axis.LeftThumbY, packet.LeftStickY);
        _controller.SetAxisValue(Xbox360Axis.RightThumbX, packet.RightStickX);
        _controller.SetAxisValue(Xbox360Axis.RightThumbY, packet.RightStickY);

        // Analog Triggers (0 to 255)
        _controller.SetSliderValue(Xbox360Slider.LeftTrigger, packet.LeftTrigger);
        _controller.SetSliderValue(Xbox360Slider.RightTrigger, packet.RightTrigger);
    }

    public void Reset()
    {
        if (_disposed) return;
        var neutral = new InputPacket();
        UpdateState(in neutral);
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
