import 'dart:async';
import 'dart:io' show Platform;
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/packet.dart';
import '../services/network_service.dart';
import '../widgets/action_buttons.dart';
import '../widgets/dpad.dart';
import '../widgets/touchpad.dart';
import '../widgets/virtual_joystick.dart';

class ControllerScreen extends StatefulWidget {
  final NetworkService network;

  const ControllerScreen({super.key, required this.network});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  bool _gyroSupported = false;
  bool _gyroEnabled = false;

  // Real device battery telemetry
  final Battery _battery = Battery();
  Timer? _batteryTimer;
  int? _batteryLevel;

  @override
  void initState() {
    super.initState();
    // Force Landscape orientation on mobile devices
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    _startGyro();
    _initBattery();

    _batteryTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _updateBattery();
    });
  }

  Future<void> _initBattery() async {
    await _updateBattery();
  }

  Future<void> _updateBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() => _batteryLevel = level);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _batteryLevel = null);
      }
    }
  }

  void _startGyro() {
    // Gyroscope is only supported on physical mobile devices
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _gyroSupported = false;
      _gyroEnabled = false;
      return;
    }

    _gyroSupported = true;
    _gyroEnabled = true;

    try {
      _gyroSub = gyroscopeEventStream().listen(
        (event) {
          if (!_gyroEnabled) return;
          widget.network.currentPacket.gyroPitch = event.x;
          widget.network.currentPacket.gyroYaw = event.y;
          widget.network.currentPacket.gyroRoll = event.z;
        },
        onError: (dynamic error) {
          debugPrint('Gyroscope stream error: $error');
          if (mounted) {
            setState(() {
              _gyroEnabled = false;
              _gyroSupported = false;
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Could not start gyroscope: $e');
      _gyroSupported = false;
      _gyroEnabled = false;
    }
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    _gyroSub?.cancel();
    // Restore orientation
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _updateButton(int bit, bool isPressed) {
    if (isPressed) {
      widget.network.currentPacket.buttons |= bit;
    } else {
      widget.network.currentPacket.buttons &= ~bit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.network,
      builder: (context, _) {
        final lightColor = widget.network.lightbarColor;
        final currentMode = widget.network.controllerMode;
        final isReconnecting = widget.network.isReconnecting;
        final rttMs = widget.network.currentRtt;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0C11),
          body: SafeArea(
            child: Stack(
              children: [
                // Top Ambient Lightbar Glow
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 400,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            lightColor.withOpacity(0.35),
                            Colors.transparent,
                          ],
                          radius: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Status & Telemetry Bar
                Positioned(
                  top: 8,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Badge & Remote Mode Switcher
                      Row(
                        children: [
                          const Icon(Icons.sports_esports,
                              color: Color(0xFF00C8FF), size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'AirSense',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Mode Switch Toggle Pill
                          GestureDetector(
                            onTap: () {
                              final targetMode =
                                  currentMode == ControllerMode.dualSensePS5
                                      ? ControllerMode.xbox360
                                      : ControllerMode.dualSensePS5;
                              widget.network.setControllerMode(targetMode);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: currentMode == ControllerMode.xbox360
                                    ? const Color(0xFF107C10).withOpacity(0.25)
                                    : const Color(0xFF003791).withOpacity(0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: currentMode == ControllerMode.xbox360
                                      ? const Color(0xFF107C10)
                                      : const Color(0xFF0070D1),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currentMode.displayName,
                                    style: TextStyle(
                                      color:
                                          currentMode == ControllerMode.xbox360
                                              ? const Color(0xFF4ADE80)
                                              : const Color(0xFF60A5FA),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.swap_horiz,
                                      color: Color(0xFF94A3B8), size: 13),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Real Telemetry Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161A24).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isReconnecting
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF2D374A).withOpacity(0.8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status Pulse Indicator
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isReconnecting
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isReconnecting
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF10B981))
                                        .withOpacity(0.6),
                                    blurRadius: 5,
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isReconnecting ? 'RECONNECTING' : 'LAN 120Hz',
                              style: TextStyle(
                                color: isReconnecting
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF94A3B8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              width: 1,
                              height: 11,
                              color: Colors.white12,
                            ),

                            // Real Live RTT (ms)
                            const Icon(
                              Icons.speed,
                              size: 13,
                              color: Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$rttMs ms',
                              style: TextStyle(
                                color: rttMs < 15
                                    ? const Color(0xFF38BDF8)
                                    : (rttMs < 50
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFEF4444)),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              width: 1,
                              height: 11,
                              color: Colors.white12,
                            ),

                            // Real Battery Telemetry
                            Icon(
                              _batteryLevel == null
                                  ? Icons.battery_unknown
                                  : (_batteryLevel! < 20
                                      ? Icons.battery_alert
                                      : Icons.battery_full),
                              color: _batteryLevel == null
                                  ? const Color(0xFF64748B)
                                  : (_batteryLevel! < 20
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981)),
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _batteryLevel != null
                                  ? '$_batteryLevel%'
                                  : 'N/A',
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quick Gyro & Disconnect Actions
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _gyroEnabled
                                  ? Icons.screen_rotation
                                  : Icons.screen_rotation_outlined,
                              color: _gyroEnabled ? lightColor : Colors.white30,
                              size: 18,
                            ),
                            tooltip: _gyroSupported
                                ? (_gyroEnabled
                                    ? 'Disable Motion Gyro'
                                    : 'Enable Motion Gyro')
                                : 'Motion gyro not supported on this platform/device',
                            onPressed: () {
                              if (!_gyroSupported) {
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Motion gyro is only supported on physical mobile devices.'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Color(0xFF1E2433),
                                  ),
                                );
                                return;
                              }
                              setState(() => _gyroEnabled = !_gyroEnabled);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.power_settings_new,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            tooltip: 'Disconnect',
                            onPressed: () {
                              widget.network.disconnect();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Gamepad Body (Ergonomic Wing Layout)
                Positioned.fill(
                  top: 54,
                  bottom: 8,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT WING: Stacked Shoulder (L2/L1) + Cluster (D-Pad & Elevated Left Stick + L3)
                      SizedBox(
                        width: 275,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Stacked Triggers (L2 Pedal on top of L1 Bumper)
                            _StackedShoulderAssembly(
                              triggerLabel: 'L2',
                              bumperLabel: 'L1',
                              onTriggerChanged: (val) {
                                widget.network.currentPacket.leftTrigger = val;
                                _updateButton(1 << 10, val > 200);
                              },
                              onBumperChanged: (pressed) =>
                                  _updateButton(1 << 8, pressed),
                            ),

                            // Cluster: D-Pad & Elevated Left Stick with Dedicated Holdable L3
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                DPad(
                                  size: 122,
                                  onButtonChange: _updateButton,
                                ),
                                // Elevated Left Stick + Holdable L3
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Dedicated Holdable L3 Button
                                      _StickClickHoldButton(
                                        label: 'L3',
                                        onStateChanged: (pressed) =>
                                            _updateButton(1 << 12, pressed),
                                      ),
                                      const SizedBox(height: 6),
                                      VirtualJoystick(
                                        size: 114,
                                        label: 'LS',
                                        onChanged: (offset) {
                                          widget.network.currentPacket
                                                  .leftStickX =
                                              (offset.dx * 32767).round();
                                          widget.network.currentPacket
                                                  .leftStickY =
                                              (offset.dy * 32767).round();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // CENTER COLUMN: Scaled Touchpad & Protected PS Button
                      Center(
                        child: TouchpadArea(
                          width: 200,
                          height: 105,
                          lightbarColor: lightColor,
                          onTouchpadChange: (active, x, y) {
                            widget.network.currentPacket.touchpadActive =
                                active ? 1 : 0;
                            widget.network.currentPacket.touchpadX = x;
                            widget.network.currentPacket.touchpadY = y;
                          },
                          onSpecialButtonChange: _updateButton,
                        ),
                      ),

                      // RIGHT WING: Stacked Shoulder (R2/R1) + Cluster (Elevated Right Stick + R3 & Face Buttons)
                      SizedBox(
                        width: 275,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Stacked Triggers (R2 Pedal on top of R1 Bumper)
                            _StackedShoulderAssembly(
                              triggerLabel: 'R2',
                              bumperLabel: 'R1',
                              onTriggerChanged: (val) {
                                widget.network.currentPacket.rightTrigger = val;
                                _updateButton(1 << 11, val > 200);
                              },
                              onBumperChanged: (pressed) =>
                                  _updateButton(1 << 9, pressed),
                            ),

                            // Cluster: Elevated Right Stick + Holdable R3 & Face Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Elevated Right Stick + Holdable R3
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Dedicated Holdable R3 Button
                                      _StickClickHoldButton(
                                        label: 'R3',
                                        onStateChanged: (pressed) =>
                                            _updateButton(1 << 13, pressed),
                                      ),
                                      const SizedBox(height: 6),
                                      VirtualJoystick(
                                        size: 114,
                                        label: 'RS',
                                        onChanged: (offset) {
                                          widget.network.currentPacket
                                                  .rightStickX =
                                              (offset.dx * 32767).round();
                                          widget.network.currentPacket
                                                  .rightStickY =
                                              (offset.dy * 32767).round();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                ActionButtons(
                                  size: 122,
                                  onButtonChange: _updateButton,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dedicated, holdable stick click button (L3 / R3)
class _StickClickHoldButton extends StatefulWidget {
  final String label;
  final ValueChanged<bool> onStateChanged;

  const _StickClickHoldButton({
    required this.label,
    required this.onStateChanged,
  });

  @override
  State<_StickClickHoldButton> createState() => _StickClickHoldButtonState();
}

class _StickClickHoldButtonState extends State<_StickClickHoldButton> {
  bool _pressed = false;

  void _set(bool val) {
    if (_pressed != val) {
      setState(() => _pressed = val);
      widget.onStateChanged(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFF0066FF) : const Color(0xFF1E2536),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _pressed ? const Color(0xFF38BDF8) : const Color(0xFF334155),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _pressed
                    ? const Color(0xFF0066FF).withOpacity(0.5)
                    : Colors.black.withOpacity(0.4),
                blurRadius: _pressed ? 8 : 4,
              )
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _pressed ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertically stacked trigger & bumper assembly with jitter-free analog/digital handling
class _StackedShoulderAssembly extends StatefulWidget {
  final String triggerLabel;
  final String bumperLabel;
  final ValueChanged<int> onTriggerChanged;
  final ValueChanged<bool> onBumperChanged;

  const _StackedShoulderAssembly({
    required this.triggerLabel,
    required this.bumperLabel,
    required this.onTriggerChanged,
    required this.onBumperChanged,
  });

  @override
  State<_StackedShoulderAssembly> createState() =>
      _StackedShoulderAssemblyState();
}

class _StackedShoulderAssemblyState extends State<_StackedShoulderAssembly> {
  double _pullAmount = 0.0;
  bool _bumperPressed = false;
  double? _dragStartX;
  bool _isModulating = false;

  void _onTriggerDown(PointerDownEvent e) {
    _dragStartX = e.localPosition.dx;
    _isModulating = false;
    // Tap actuation defaults immediately to 100% full pull (255)
    setState(() => _pullAmount = 1.0);
    widget.onTriggerChanged(255);
  }

  void _onTriggerMove(PointerMoveEvent e) {
    if (_dragStartX != null) {
      final delta = (e.localPosition.dx - _dragStartX!).abs();
      // Only switch to analog modulation if intentional horizontal drag > 12px
      if (delta > 12) {
        _isModulating = true;
      }
    }
    if (_isModulating) {
      final amount = (e.localPosition.dx / 120.0).clamp(0.0, 1.0);
      setState(() => _pullAmount = amount);
      widget.onTriggerChanged((amount * 255).round());
    }
  }

  void _onTriggerRelease() {
    _dragStartX = null;
    _isModulating = false;
    setState(() => _pullAmount = 0.0);
    widget.onTriggerChanged(0);
  }

  void _setBumper(bool val) {
    if (_bumperPressed != val) {
      setState(() => _bumperPressed = val);
      widget.onBumperChanged(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPulled = _pullAmount > 0.05;

    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Large Trigger Pedal (L2 / R2)
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onTriggerDown,
            onPointerMove: _onTriggerMove,
            onPointerUp: (_) => _onTriggerRelease(),
            onPointerCancel: (_) => _onTriggerRelease(),
            child: AnimatedScale(
              scale: isPulled ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 60),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPulled
                        ? [const Color(0xFF243B60), const Color(0xFF16253D)]
                        : [const Color(0xFF242C3C), const Color(0xFF161B24)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isPulled
                        ? const Color(0xFF00C8FF)
                        : const Color(0xFF354259),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Analog pull level gauge
                    Positioned(
                      left: 0,
                      bottom: 0,
                      top: 0,
                      width: 120 * _pullAmount,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0066FF).withOpacity(0.35),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.triggerLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${(_pullAmount * 100).round()}%',
                            style: TextStyle(
                              color: isPulled
                                  ? const Color(0xFF00C8FF)
                                  : const Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),

          // 2. Bumper Bar (L1 / R1)
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _setBumper(true),
            onPointerUp: (_) => _setBumper(false),
            onPointerCancel: (_) => _setBumper(false),
            child: AnimatedScale(
              scale: _bumperPressed ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 60),
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: _bumperPressed
                      ? const Color(0xFF3B4760)
                      : const Color(0xFF1C2230),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _bumperPressed
                        ? Colors.white70
                        : const Color(0xFF2D374A),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.bumperLabel,
                    style: TextStyle(
                      color: _bumperPressed
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
