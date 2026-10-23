import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/packet.dart';

class NetworkService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  InternetAddress? _serverAddress;
  int _serverPort = 9050;
  bool _isConnected = false;
  bool _isReconnecting = false;
  int _currentRtt = 0; // Live RTT in milliseconds
  ControllerMode _controllerMode = ControllerMode.dualSensePS5;
  String _serverHostName = 'AirSense Host';

  Timer? _streamTimer;
  Timer? _heartbeatTimer;
  Timer? _watchdogTimer;
  Completer<bool>? _handshakeCompleter;
  DateTime _lastServerResponseTime = DateTime.now();

  final ControllerPacket currentPacket = ControllerPacket();
  int _nextSequence = 1;
  Color lightbarColor = const Color(0xFF003791); // Default PlayStation Blue

  // Haptic Feedback rate limiting
  int _lastHapticTime = 0;
  int _lastLargeMotor = 0;
  int _lastSmallMotor = 0;

  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  int get currentRtt => _currentRtt;
  ControllerMode get controllerMode => _controllerMode;
  String get serverHostName => _serverHostName;
  InternetAddress? get serverAddress => _serverAddress;
  int get serverPort => _serverPort;

  /// Performs authentic UDP handshake with the server and verifies connection
  Future<bool> connect(String hostIp, [int port = 9050]) async {
    disconnect();
    try {
      _serverAddress = InternetAddress(hostIp);
      _serverPort = port;

      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.listen(_onSocketEvent);

      // Prepare handshake completer with timeout
      _handshakeCompleter = Completer<bool>();

      // Send ConnectRequest packet (AIRS + 0x05 + uint32 version)
      _sendConnectRequest();

      // Retry up to 3 times every 600ms if no response received
      int attempts = 0;
      Timer.periodic(const Duration(milliseconds: 600), (timer) {
        if (_handshakeCompleter == null || _handshakeCompleter!.isCompleted) {
          timer.cancel();
          return;
        }
        attempts++;
        if (attempts >= 4) {
          timer.cancel();
          if (!_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(false);
          }
          return;
        }
        _sendConnectRequest();
      });

      // Wait for server ConnectAck within 2500ms
      final acknowledged = await _handshakeCompleter!.future.timeout(
        const Duration(milliseconds: 2500),
        onTimeout: () => false,
      );

      if (!acknowledged) {
        debugPrint('[AirSense Network] Handshake timed out. Host did not respond.');
        disconnect();
        return false;
      }

      _isConnected = true;
      _isReconnecting = false;
      _lastServerResponseTime = DateTime.now();
      _nextSequence = 1;

      // Start 120 Hz input stream loop (~8.3ms)
      _streamTimer = Timer.periodic(const Duration(milliseconds: 8), (_) {
        sendCurrentState();
      });

      // Heartbeat & live RTT ping loop every 800ms
      _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
        _sendHeartbeatPing();
      });

      // Watchdog loop: detects network loss after 3.0s of silence
      _watchdogTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _checkConnectionWatchdog();
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AirSense Network] Connect exception: $e');
      disconnect();
      return false;
    }
  }

  void _sendConnectRequest() {
    if (_socket == null || _serverAddress == null) return;
    final buffer = ByteData(9);
    buffer.setUint8(0, 0x41);
    buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x52);
    buffer.setUint8(3, 0x53);
    buffer.setUint8(4, PacketType.connectRequest.value);
    buffer.setUint32(5, 1, Endian.little); // Protocol Version 1

    try {
      _socket?.send(buffer.buffer.asUint8List(), _serverAddress!, _serverPort);
    } catch (_) {}
  }

  void sendCurrentState() {
    if (!_isConnected || _socket == null || _serverAddress == null) return;
    try {
      // Monotonically increment sequence number for UDP out-of-order protection
      currentPacket.sequenceNumber = _nextSequence;
      _nextSequence = (_nextSequence + 1) & 0xFFFFFFFF;
      if (_nextSequence == 0) _nextSequence = 1;

      final bytes = currentPacket.toBytes();
      _socket?.send(bytes, _serverAddress!, _serverPort);
    } catch (e) {
      debugPrint('[AirSense Network] Send error: $e');
    }
  }

  void _sendHeartbeatPing() {
    if (!_isConnected || _socket == null || _serverAddress == null) return;
    final buffer = ByteData(13);
    buffer.setUint8(0, 0x41);
    buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x52);
    buffer.setUint8(3, 0x53);
    buffer.setUint8(4, PacketType.heartbeat.value);
    // Include 64-bit current local timestamp in ms
    buffer.setInt64(5, DateTime.now().millisecondsSinceEpoch, Endian.little);

    try {
      _socket?.send(buffer.buffer.asUint8List(), _serverAddress!, _serverPort);
    } catch (_) {}
  }

  /// Remotely requests server to switch controller mode (PS5 DualSense vs Xbox 360)
  void setControllerMode(ControllerMode mode) {
    if (_controllerMode == mode) return;
    _controllerMode = mode;
    notifyListeners();

    if (!_isConnected || _socket == null || _serverAddress == null) return;
    final buffer = Uint8List(6);
    buffer[0] = 0x41;
    buffer[1] = 0x49;
    buffer[2] = 0x52;
    buffer[3] = 0x53;
    buffer[4] = PacketType.setControllerMode.value;
    buffer[5] = mode.value;

    try {
      _socket?.send(buffer, _serverAddress!, _serverPort);
    } catch (_) {}
  }

  void _checkConnectionWatchdog() {
    if (!_isConnected) return;

    final silenceDuration =
        DateTime.now().difference(_lastServerResponseTime).inMilliseconds;

    if (silenceDuration > 3000) {
      if (!_isReconnecting) {
        _isReconnecting = true;
        notifyListeners();
      }
    } else {
      if (_isReconnecting) {
        _isReconnecting = false;
        notifyListeners();
      }
    }
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram == null) return;

      final data = datagram.data;
      if (data.length < 5 ||
          data[0] != 0x41 ||
          data[1] != 0x49 ||
          data[2] != 0x52 ||
          data[3] != 0x53) {
        return;
      }

      final type = data[4];
      _lastServerResponseTime = DateTime.now();
      if (_isReconnecting) {
        _isReconnecting = false;
        notifyListeners();
      }

      // 1. Handshake ACK
      if (type == PacketType.connectAck.value) {
        if (data.length >= 7) {
          _controllerMode = ControllerMode.fromValue(data[5]);
          final nameLen = data[6];
          if (data.length >= 7 + nameLen) {
            _serverHostName = String.fromCharCodes(data.sublist(7, 7 + nameLen));
          }
        }
        if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
          _handshakeCompleter!.complete(true);
        }
      }

      // 2. Real RTT Heartbeat Echo
      else if (type == PacketType.heartbeatAck.value && data.length >= 14) {
        final byteData = ByteData.sublistView(data);
        final echoTimestamp = byteData.getInt64(5, Endian.little);
        final rtt = DateTime.now().millisecondsSinceEpoch - echoTimestamp;
        _currentRtt = rtt.clamp(0, 999);
        _controllerMode = ControllerMode.fromValue(data[13]);
        notifyListeners();
      }

      // 3. Controller Mode Switch ACK
      else if (type == PacketType.controllerModeAck.value && data.length >= 6) {
        _controllerMode = ControllerMode.fromValue(data[5]);
        notifyListeners();
      }

      // 4. Rumble Feedback
      else if (type == PacketType.rumbleFeedback.value && data.length >= 10) {
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
    if (largeMotor == 0 && smallMotor == 0) {
      _lastLargeMotor = 0;
      _lastSmallMotor = 0;
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDelta = now - _lastHapticTime;
    final largeDelta = (largeMotor - _lastLargeMotor).abs();
    final smallDelta = (smallMotor - _lastSmallMotor).abs();

    // Rate-limit haptics: enforce minimum 70ms interval unless there's a significant intensity jump (> 45)
    if (timeDelta < 70 && largeDelta < 45 && smallDelta < 45) {
      return;
    }

    _lastHapticTime = now;
    _lastLargeMotor = largeMotor;
    _lastSmallMotor = smallMotor;

    if (largeMotor > 160) {
      HapticFeedback.heavyImpact();
    } else if (largeMotor > 60 || smallMotor > 90) {
      HapticFeedback.mediumImpact();
    } else if (largeMotor > 15 || smallMotor > 30) {
      HapticFeedback.lightImpact();
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
    _watchdogTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _isReconnecting = false;
    _currentRtt = 0;
    if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
      _handshakeCompleter!.complete(false);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
