import 'dart:typed_data';

enum PacketType {
  discoveryPing(0x01),
  discoveryPong(0x02),
  inputFrame(0x10),
  rumbleFeedback(0x20),
  heartbeat(0x30);

  final int value;
  const PacketType(this.value);
}

class ControllerButtons {
  static const int none = 0;
  static const int cross = 1 << 0;
  static const int circle = 1 << 1;
  static const int square = 1 << 2;
  static const int triangle = 1 << 3;
  static const int dpadUp = 1 << 4;
  static const int dpadDown = 1 << 5;
  static const int dpadLeft = 1 << 6;
  static const int dpadRight = 1 << 7;
  static const int l1 = 1 << 8;
  static const int r1 = 1 << 9;
  static const int l2Click = 1 << 10;
  static const int r2Click = 1 << 11;
  static const int l3 = 1 << 12;
  static const int r3 = 1 << 13;
  static const int share = 1 << 14;
  static const int options = 1 << 15;
  static const int psButton = 1 << 16;
  static const int touchpadClick = 1 << 17;
}

class ControllerPacket {
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
    final buffer = ByteData(36);

    // Magic "AIRS"
    buffer.setUint8(0, 0x41);
    buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x52);
    buffer.setUint8(3, 0x53);

    // Type
    buffer.setUint8(4, PacketType.inputFrame.value);

    // Buttons
    buffer.setUint32(5, buttons, Endian.little);

    // Left Stick
    buffer.setInt16(9, leftStickX, Endian.little);
    buffer.setInt16(11, leftStickY, Endian.little);

    // Right Stick
    buffer.setInt16(13, rightStickX, Endian.little);
    buffer.setInt16(15, rightStickY, Endian.little);

    // Triggers
    buffer.setUint8(17, leftTrigger);
    buffer.setUint8(18, rightTrigger);

    // Gyro
    buffer.setFloat32(19, gyroPitch, Endian.little);
    buffer.setFloat32(23, gyroYaw, Endian.little);
    buffer.setFloat32(27, gyroRoll, Endian.little);

    // Touchpad
    buffer.setUint8(31, touchpadActive);
    buffer.setUint16(32, touchpadX, Endian.little);
    buffer.setUint16(34, touchpadY, Endian.little);

    return buffer.buffer.asUint8List();
  }
}
