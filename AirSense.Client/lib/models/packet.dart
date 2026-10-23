import 'dart:typed_data';

enum PacketType {
  discoveryPing(0x01),
  discoveryPong(0x02),
  connectRequest(0x05),
  connectAck(0x06),
  inputFrame(0x10),
  rumbleFeedback(0x20),
  heartbeat(0x30),
  heartbeatAck(0x31),
  setControllerMode(0x40),
  controllerModeAck(0x41);

  final int value;
  const PacketType(this.value);
}

enum ControllerMode {
  dualSensePS5(0x00, 'PS5 DualSense'),
  xbox360(0x01, 'Xbox 360 (PC)');

  final int value;
  final String displayName;
  const ControllerMode(this.value, this.displayName);

  static ControllerMode fromValue(int val) {
    return val == 1 ? ControllerMode.xbox360 : ControllerMode.dualSensePS5;
  }
}

class ControllerButtons {
  static const int none = 0;
  static const int cross = 1 << 0;       // A on Xbox
  static const int circle = 1 << 1;      // B on Xbox
  static const int square = 1 << 2;      // X on Xbox
  static const int triangle = 1 << 3;    // Y on Xbox
  static const int dpadUp = 1 << 4;
  static const int dpadDown = 1 << 5;
  static const int dpadLeft = 1 << 6;
  static const int dpadRight = 1 << 7;
  static const int l1 = 1 << 8;          // LB
  static const int r1 = 1 << 9;          // RB
  static const int l2Click = 1 << 10;
  static const int r2Click = 1 << 11;
  static const int l3 = 1 << 12;         // LS Click
  static const int r3 = 1 << 13;         // RS Click
  static const int share = 1 << 14;      // Back / View
  static const int options = 1 << 15;    // Start / Menu
  static const int psButton = 1 << 16;   // Guide / Home
  static const int touchpadClick = 1 << 17;
}

class ControllerPacket {
  int sequenceNumber = 0;
  int buttons = 0;
  int leftStickX = 0;   // -32768 to 32767
  int leftStickY = 0;   // -32768 to 32767 (Up is positive)
  int rightStickX = 0;  // -32768 to 32767
  int rightStickY = 0;  // -32768 to 32767
  int leftTrigger = 0;  // 0 to 255
  int rightTrigger = 0; // 0 to 255
  double gyroPitch = 0.0;
  double gyroYaw = 0.0;
  double gyroRoll = 0.0;
  int touchpadActive = 0;
  int touchpadX = 0;
  int touchpadY = 0;

  Uint8List toBytes() {
    final buffer = ByteData(40);

    // Magic "AIRS"
    buffer.setUint8(0, 0x41);
    buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x52);
    buffer.setUint8(3, 0x53);

    // Type
    buffer.setUint8(4, PacketType.inputFrame.value);

    // Sequence Number (uint32 LittleEndian)
    buffer.setUint32(5, sequenceNumber, Endian.little);

    // Buttons (uint32 LittleEndian)
    buffer.setUint32(9, buttons, Endian.little);

    // Left Stick (int16 LittleEndian)
    buffer.setInt16(13, leftStickX, Endian.little);
    buffer.setInt16(15, leftStickY, Endian.little);

    // Right Stick (int16 LittleEndian)
    buffer.setInt16(17, rightStickX, Endian.little);
    buffer.setInt16(19, rightStickY, Endian.little);

    // Triggers
    buffer.setUint8(21, leftTrigger);
    buffer.setUint8(22, rightTrigger);

    // Gyro (float32 LittleEndian)
    buffer.setFloat32(23, gyroPitch, Endian.little);
    buffer.setFloat32(27, gyroYaw, Endian.little);
    buffer.setFloat32(31, gyroRoll, Endian.little);

    // Touchpad
    buffer.setUint8(35, touchpadActive);
    buffer.setUint16(36, touchpadX, Endian.little);
    buffer.setUint16(38, touchpadY, Endian.little);

    return buffer.buffer.asUint8List();
  }
}
