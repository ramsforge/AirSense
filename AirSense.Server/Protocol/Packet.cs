namespace AirSense.Server.Protocol;

public enum PacketType : byte
{
    DiscoveryPing = 0x01,
    DiscoveryPong = 0x02,
    ConnectRequest = 0x05,
    ConnectAck = 0x06,
    InputFrame = 0x10,
    RumbleFeedback = 0x20,
    Heartbeat = 0x30,
    HeartbeatAck = 0x31,
    SetControllerMode = 0x40,
    ControllerModeAck = 0x41
}

public enum ControllerMode : byte
{
    DualSensePS5 = 0x00,
    Xbox360 = 0x01
}

[Flags]
public enum ControllerButtons : uint
{
    None = 0,
    Cross = 1 << 0,       // A on Xbox
    Circle = 1 << 1,      // B on Xbox
    Square = 1 << 2,      // X on Xbox
    Triangle = 1 << 3,    // Y on Xbox
    DPadUp = 1 << 4,
    DPadDown = 1 << 5,
    DPadLeft = 1 << 6,
    DPadRight = 1 << 7,
    L1 = 1 << 8,          // Left Bumper
    R1 = 1 << 9,          // Right Bumper
    L2Click = 1 << 10,
    R2Click = 1 << 11,
    L3 = 1 << 12,         // Left Stick Click
    R3 = 1 << 13,         // Right Stick Click
    Share = 1 << 14,      // Select / Create
    Options = 1 << 15,    // Start
    PSButton = 1 << 16,   // Guide / Home
    TouchpadClick = 1 << 17
}

public struct InputPacket
{
    public uint SequenceNumber;
    public ControllerButtons Buttons;
    public short LeftStickX;   // -32768 to 32767
    public short LeftStickY;   // -32768 to 32767 (Up is positive)
    public short RightStickX;  // -32768 to 32767
    public short RightStickY;  // -32768 to 32767 (Up is positive)
    public byte LeftTrigger;   // 0 to 255
    public byte RightTrigger;  // 0 to 255
    public float GyroPitch;    // Delta rad/s
    public float GyroYaw;      // Delta rad/s
    public float GyroRoll;     // Delta rad/s
    public byte TouchpadActive;
    public ushort TouchpadX;   // 0 to 1920
    public ushort TouchpadY;   // 0 to 1080

    public static bool TryParse(ReadOnlySpan<byte> buffer, out InputPacket packet)
    {
        packet = default;
        // Expected payload size: 4 (Magic) + 1 (Type) + 4 (Seq) + 4 (Buttons) + 8 (Sticks) + 2 (Triggers) + 12 (Gyro) + 5 (Touchpad) = 40 bytes
        if (buffer.Length < 40)
            return false;

        // Magic "AIRS" = 0x41, 0x49, 0x52, 0x53
        if (buffer[0] != 0x41 || buffer[1] != 0x49 || buffer[2] != 0x52 || buffer[3] != 0x53)
            return false;

        if (buffer[4] != (byte)PacketType.InputFrame)
            return false;

        packet.SequenceNumber = BitConverter.ToUInt32(buffer.Slice(5, 4));
        packet.Buttons = (ControllerButtons)BitConverter.ToUInt32(buffer.Slice(9, 4));
        packet.LeftStickX = BitConverter.ToInt16(buffer.Slice(13, 2));
        packet.LeftStickY = BitConverter.ToInt16(buffer.Slice(15, 2));
        packet.RightStickX = BitConverter.ToInt16(buffer.Slice(17, 2));
        packet.RightStickY = BitConverter.ToInt16(buffer.Slice(19, 2));
        packet.LeftTrigger = buffer[21];
        packet.RightTrigger = buffer[22];

        packet.GyroPitch = BitConverter.ToSingle(buffer.Slice(23, 4));
        packet.GyroYaw = BitConverter.ToSingle(buffer.Slice(27, 4));
        packet.GyroRoll = BitConverter.ToSingle(buffer.Slice(31, 4));

        packet.TouchpadActive = buffer[35];
        packet.TouchpadX = BitConverter.ToUInt16(buffer.Slice(36, 2));
        packet.TouchpadY = BitConverter.ToUInt16(buffer.Slice(38, 2));

        return true;
    }
}
