import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../models/packet.dart';

class NetworkService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  InternetAddress? _serverAddress;
  int _serverPort = 9050;
  bool _isConnected = false;
  Timer? _streamTimer;
  Timer? _heartbeatTimer;

  final ControllerPacket currentPacket = ControllerPacket();
  Color lightbarColor = const Color(0xFF003791); // Default PlayStation Blue

  bool get isConnected => _isConnected;
  InternetAddress? get serverAddress => _serverAddress;
  int get serverPort => _serverPort;

  Future<bool> connect(String hostIp, [int port = 9050]) async {
    disconnect();
    try {
      _serverAddress = InternetAddress(hostIp);
      _serverPort = port;

      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.listen(_onSocketEvent);

      _isConnected = true;

      // Start 120 Hz input stream loop (~8.3ms)
      _streamTimer = Timer.periodic(const Duration(milliseconds: 8), (_) {
        sendCurrentState();
      });

      // Heartbeat timer every 1s
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _sendHeartbeat();
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AirSense Network] Connect error: $e');
      disconnect();
      return false;
    }
  }

  void sendCurrentState() {
    if (!_isConnected || _socket == null || _serverAddress == null) return;
    try {
      final bytes = currentPacket.toBytes();
      _socket?.send(bytes, _serverAddress!, _serverPort);
    } catch (e) {
      debugPrint('[AirSense Network] Send error: $e');
    }
  }

  void _sendHeartbeat() {
    if (!_isConnected || _socket == null || _serverAddress == null) return;
    final buffer = Uint8List(5);
    buffer[0] = 0x41;
    buffer[1] = 0x49;
    buffer[2] = 0x52;
    buffer[3] = 0x53;
    buffer[4] = PacketType.heartbeat.value;
    try {
      _socket?.send(buffer, _serverAddress!, _serverPort);
    } catch (_) {}
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram == null) return;

      final data = datagram.data;
      if (data.length >= 10 &&
          data[0] == 0x41 &&
          data[1] == 0x49 &&
          data[2] == 0x52 &&
          data[3] == 0x53 &&
          data[4] == PacketType.rumbleFeedback.value) {
        final largeMotor = data[5];
        final smallMotor = data[6];
        final r = data[7];
        final g = data[8];
        final b = data[9];

        _handleRumble(largeMotor, smallMotor);
        _handleLightbar(r, g, b);
      }
    }
  }

  void _handleRumble(int largeMotor, int smallMotor) {
    if (largeMotor > 0 || smallMotor > 0) {
      final intensity = (largeMotor > smallMotor ? largeMotor : smallMotor);
      Vibration.hasVibrator().then((hasVib) {
        if (hasVib == true) {
          Vibration.vibrate(duration: 80, amplitude: intensity);
        }
      });
    }
  }

  void _handleLightbar(int r, int g, int b) {
    if (r == 0 && g == 0 && b == 0) return;
    lightbarColor = Color.fromARGB(255, r, g, b);
    notifyListeners();
  }

  void disconnect() {
    _streamTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
