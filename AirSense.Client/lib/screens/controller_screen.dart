import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
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
  // Dual-Sensor Motion Telemetry (Accelerometer primary tilt + Gyroscope secondary)
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  bool _sensorsSupported = false;
  bool _motionSteerEnabled = false;
  bool _invertSteer = false;
  double _currentTilt = 0.0; // Normalized -1.0 (Full Left) to +1.0 (Full Right)
  double _calibratedZeroY = 0.0;
  double _lastRawY = 0.0;
  bool _leftStickTouched = false;

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

    _startSensors();
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

  void _startSensors() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _sensorsSupported = false;
      _motionSteerEnabled = false;
      return;
    }

    // 1. Primary Accelerometer Stream (Gravity vector for tilt-steering)
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (event) {
          if (!_sensorsSupported && mounted) {
            setState(() => _sensorsSupported = true);
          }
          _processAccelerometerTilt(event);
        },
        onError: (dynamic error) {
          debugPrint('Accelerometer stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Could not start accelerometer: $e');
    }

    // 2. Dual-Sensor Fallback: Gyroscope Stream (for DualSense rate gyros if present)
    try {
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (event) {
          if (!_sensorsSupported && mounted) {
            setState(() => _sensorsSupported = true);
          }
          widget.network.currentPacket.gyroPitch = event.x;
          widget.network.currentPacket.gyroYaw = event.y;
          widget.network.currentPacket.gyroRoll = event.z;
        },
        onError: (dynamic error) {
          debugPrint('Gyroscope stream error: $error');
          // Dual-sensor fallback: accelerometer continues handling tilt steering even if gyro is unavailable!
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Could not start gyroscope: $e');
    }
  }

  void _processAccelerometerTilt(AccelerometerEvent event) {
    _lastRawY = event.y;
    final deltaY = event.y - _calibratedZeroY;

    // In landscape mode:
    // event.y measures tilt toward the left or right bumper.
    // In standard landscape (landscapeLeft, top of phone on left):
    // Tilting left causes +Y gravity acceleration, so -deltaY maps to negative steer (Left).
    // If _invertSteer is true, flip the direction.
    final directedY = _invertSteer ? deltaY : -deltaY;

    // Normalize tilt angle between -1.0 (Full Left) and +1.0 (Full Right)
    // 6.5 m/s^2 corresponds to ~41.5 degrees of phone rotation for 100% steering lock
    final rawTilt = (directedY / 6.5).clamp(-1.0, 1.0);

    // Center deadzone: ~4.5 degrees (0.08 normalized) to eliminate micro-hand tremor
    const double deadzone = 0.08;
    double calculatedTilt = 0.0;
    if (rawTilt.abs() > deadzone) {
      final double normalized = (rawTilt.abs() - deadzone) / (1.0 - deadzone);
      // Non-linear power curve for stable cruising and responsive hairpin turns
      calculatedTilt = pow(normalized, 1.4) * rawTilt.sign;
    }

    // Only trigger rebuild if tilt changed meaningfully to optimize rendering
    if ((_currentTilt - calculatedTilt).abs() > 0.02) {
      if (mounted) {
        setState(() => _currentTilt = calculatedTilt);
      }
    } else {
      _currentTilt = calculatedTilt;
    }

    // Map directly to LeftStickX when tilt steering is enabled and thumb isn't overriding
    if (_motionSteerEnabled && !_leftStickTouched) {
      final steerValue = (_currentTilt * 32767).round().clamp(-32768, 32767);
      widget.network.currentPacket.leftStickX = steerValue;
    }
  }

  void _toggleMotionSteering() {
    if (!_sensorsSupported) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('No motion sensors available on this device.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1E2433),
        ),
      );
      return;
    }

    setState(() {
      _motionSteerEnabled = !_motionSteerEnabled;
      if (!_motionSteerEnabled && !_leftStickTouched) {
        widget.network.currentPacket.leftStickX = 0;
      } else if (_motionSteerEnabled) {
        // Auto-calibrate current resting angle as neutral 0.0 upon activation
        _calibratedZeroY = _lastRawY;
      }
    });

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(_motionSteerEnabled
            ? 'Tilt Steering: ENABLED (Calibrated to current resting angle)'
            : 'Tilt Steering: DISABLED (Standard thumbstick control)'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E2433),
      ),
    );
  }

  void _calibrateSteering() {
    setState(() {
      _calibratedZeroY = _lastRawY;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Steering wheel neutral angle calibrated.'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF1E2433),
      ),
    );
  }

  void _toggleInvertSteer() {
    setState(() {
      _invertSteer = !_invertSteer;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(_invertSteer ? 'Steering Inverted' : 'Steering Normal'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1E2433),
      ),
    );
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    _accelSub?.cancel();
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
                      height: 45,
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

                // 1. Top Status & Telemetry Bar
                Positioned(
                  top: 6,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Badge & Remote Mode Switcher
                      Row(
                        children: [
                          const Icon(Icons.sports_esports,
                              color: Color(0xFF00C8FF), size: 18),
                          const SizedBox(width: 7),
                          const Text(
                            'AirSense',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),

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
                                  horizontal: 9, vertical: 3.5),
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
                                      fontSize: 10,
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
                            horizontal: 12, vertical: 4),
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
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              width: 1,
                              height: 10,
                              color: Colors.white12,
                            ),

                            // Real Live RTT (ms)
                            const Icon(
                              Icons.speed,
                              size: 12,
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
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              width: 1,
                              height: 10,
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
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _batteryLevel != null
                                  ? '$_batteryLevel%'
                                  : 'N/A',
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quick Tilt Steering & Disconnect Actions
                      Row(
                        children: [
                          if (_motionSteerEnabled)
                            _SteeringMeterWidget(
                              tilt: _currentTilt,
                              isEnabled: _motionSteerEnabled,
                              onCalibrate: _calibrateSteering,
                              onInvert: _toggleInvertSteer,
                            ),
                          IconButton(
                            icon: Icon(
                              _motionSteerEnabled
                                  ? Icons.sports_motorsports
                                  : Icons.sports_motorsports_outlined,
                              color: _motionSteerEnabled
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white30,
                              size: 19,
                            ),
                            tooltip: _sensorsSupported
                                ? (_motionSteerEnabled
                                    ? 'Tilt Steering: ON (Tap to toggle, double-tap meter to invert)'
                                    : 'Tilt Steering: OFF (Tap to enable)')
                                : 'No motion sensors available on this device',
                            onPressed: _toggleMotionSteering,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.power_settings_new,
                              color: Colors.redAccent,
                              size: 17,
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

                // 2. Main Gamepad Body (Ergonomic Two-Tier Vertical Stacks & Flanks)
                Positioned.fill(
                  top: 46,
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT FLANK: Vertical L2 Pedal (top) on L1 Bumper (below)
                      Align(
                        alignment: Alignment.topCenter,
                        child: _VerticalFlankAssembly(
                          triggerLabel: 'L2',
                          bumperLabel: 'L1',
                          isLeft: true,
                          onTriggerChanged: (val) {
                            widget.network.currentPacket.leftTrigger = val;
                            _updateButton(1 << 10, val > 80);
                          },
                          onBumperChanged: (pressed) =>
                              _updateButton(1 << 8, pressed),
                        ),
                      ),

                      // LEFT WING (Two-Tier Vertical Stack: D-Pad Top, Stick Bottom)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Top Tier: De-condensed 8-Way D-Pad (150px)
                            DPad(
                              size: 150,
                              onButtonChange: _updateButton,
                            ),

                            // Bottom Tier: Elevated Left Stick + Holdable L3 + Steering Feedback
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_motionSteerEnabled)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF00E5FF)
                                            .withValues(alpha: 0.45),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.sports_motorsports,
                                          size: 11,
                                          color: Color(0xFF00E5FF),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _currentTilt.abs() < 0.05
                                              ? 'WHEEL: CENTER'
                                              : (_currentTilt < 0
                                                  ? '◄ ${(-_currentTilt * 100).round()}% LEFT'
                                                  : 'RIGHT ${(_currentTilt * 100).round()}% ►'),
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    VirtualJoystick(
                                      size: 112,
                                      label: 'LS',
                                      onChanged: (offset) {
                                        if (offset == Offset.zero) {
                                          _leftStickTouched = false;
                                          if (!_motionSteerEnabled) {
                                            widget.network.currentPacket
                                                .leftStickX = 0;
                                          }
                                        } else {
                                          _leftStickTouched = true;
                                          widget.network.currentPacket
                                                  .leftStickX =
                                              (offset.dx * 32767).round();
                                        }
                                        widget.network.currentPacket
                                                .leftStickY =
                                            (offset.dy * 32767).round();
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    _StickClickHoldButton(
                                      label: 'L3',
                                      onStateChanged: (pressed) =>
                                          _updateButton(1 << 12, pressed),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // CENTER COLUMN: Scaled Touchpad & Protected PS Button
                      Center(
                        child: TouchpadArea(
                          width: 184,
                          height: 98,
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

                      // RIGHT WING (Two-Tier Vertical Stack: Face Buttons Top, Stick Bottom)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Top Tier: Vector Action Buttons (145px) with Mode Adaptation
                            ActionButtons(
                              size: 145,
                              mode: currentMode,
                              onButtonChange: _updateButton,
                            ),

                            // Bottom Tier: Holdable R3 + Elevated Right Stick
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _StickClickHoldButton(
                                  label: 'R3',
                                  onStateChanged: (pressed) =>
                                      _updateButton(1 << 13, pressed),
                                ),
                                const SizedBox(width: 6),
                                VirtualJoystick(
                                  size: 112,
                                  label: 'RS',
                                  onChanged: (offset) {
                                    widget.network.currentPacket.rightStickX =
                                        (offset.dx * 32767).round();
                                    widget.network.currentPacket.rightStickY =
                                        (offset.dy * 32767).round();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // RIGHT FLANK: Vertical R2 Pedal (top) on R1 Bumper (below)
                      Align(
                        alignment: Alignment.topCenter,
                        child: _VerticalFlankAssembly(
                          triggerLabel: 'R2',
                          bumperLabel: 'R1',
                          isLeft: false,
                          onTriggerChanged: (val) {
                            widget.network.currentPacket.rightTrigger = val;
                            _updateButton(1 << 11, val > 80);
                          },
                          onBumperChanged: (pressed) =>
                              _updateButton(1 << 9, pressed),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFF0066FF) : const Color(0xFF1E2536),
            borderRadius: BorderRadius.circular(10),
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
              color: _pressed ? Colors.white : const Color(0xFFCBD5E1),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical flank shoulder assembly (Vertical Trigger Pedal above Vertical Bumper)
/// Engineered for ergonomic phone thumb/index finger access with:
/// - Inverted/corrected vertical progression: 100% full actuation at the top crest, 0% at bottom
/// - Extended length (118px) and widened profile (58px) for effortless reach
/// - Subtle tactile grip ridges and top actuation crest
class _VerticalFlankAssembly extends StatefulWidget {
  final String triggerLabel;
  final String bumperLabel;
  final bool isLeft;
  final ValueChanged<int> onTriggerChanged;
  final ValueChanged<bool> onBumperChanged;

  const _VerticalFlankAssembly({
    required this.triggerLabel,
    required this.bumperLabel,
    required this.isLeft,
    required this.onTriggerChanged,
    required this.onBumperChanged,
  });

  @override
  State<_VerticalFlankAssembly> createState() => _VerticalFlankAssemblyState();
}

class _VerticalFlankAssemblyState extends State<_VerticalFlankAssembly> {
  static const double flankWidth = 58.0;
  static const double triggerHeight = 118.0;
  static const double bumperHeight = 44.0;

  double _pullAmount = 0.0;
  bool _bumperPressed = false;
  Offset? _dragStart;
  bool _isModulating = false;

  /// Calculate trigger actuation: 100% (1.0) at the top crest, 0% (0.0) at the bottom
  double _calculatePull(double localY) {
    return (1.0 - (localY / triggerHeight)).clamp(0.0, 1.0);
  }

  void _onTriggerDown(PointerDownEvent e) {
    _dragStart = e.localPosition;
    _isModulating = false;
    final amount = _calculatePull(e.localPosition.dy);
    // Tapping the upper half (or quick tap) actuates at 100% immediately for reflex aim/fire.
    // Touching lower down initiates analog modulation directly at that position.
    final pull = amount >= 0.50 ? 1.0 : amount;
    setState(() => _pullAmount = pull);
    widget.onTriggerChanged((pull * 255).round());
  }

  void _onTriggerMove(PointerMoveEvent e) {
    if (_dragStart != null) {
      final deltaY = (e.localPosition.dy - _dragStart!.dy).abs();
      if (deltaY > 6) {
        _isModulating = true;
      }
    }
    if (_isModulating) {
      final amount = _calculatePull(e.localPosition.dy);
      setState(() => _pullAmount = amount);
      widget.onTriggerChanged((amount * 255).round());
    }
  }

  void _onTriggerRelease() {
    _dragStart = null;
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
    final isPulled = _pullAmount > 0.02;

    // Asymmetric organic curves matching left/right phone outer chassis
    final triggerRadius = widget.isLeft
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(12),
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(8),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(12),
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(8),
          );

    final bumperRadius = widget.isLeft
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(14),
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(10),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(14),
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(10),
          );

    return SizedBox(
      width: flankWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Extended Vertical Trigger Pedal (L2 / R2) - 100% Actuation at Top
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onTriggerDown,
            onPointerMove: _onTriggerMove,
            onPointerUp: (_) => _onTriggerRelease(),
            onPointerCancel: (_) => _onTriggerRelease(),
            child: AnimatedScale(
              scale: isPulled ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 40),
              child: Container(
                width: flankWidth,
                height: triggerHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPulled
                        ? [const Color(0xFF243B60), const Color(0xFF16253D)]
                        : [const Color(0xFF222838), const Color(0xFF141822)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: triggerRadius,
                  border: Border.all(
                    color: isPulled
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF334057),
                    width: isPulled ? 1.8 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPulled
                          ? const Color(0xFF00E5FF).withOpacity(0.35)
                          : Colors.black.withOpacity(0.4),
                      blurRadius: isPulled ? 8 : 5,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dynamic fill gauge rising from bottom up towards 100% at the top
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: triggerHeight * _pullAmount,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0066FF).withOpacity(0.3),
                              const Color(0xFF00E5FF).withOpacity(0.55),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: triggerRadius,
                        ),
                      ),
                    ),

                    // Top Actuation Crest (100% Pull Indicator)
                    Positioned(
                      top: 0,
                      left: 8,
                      right: 8,
                      height: 2.5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isPulled
                              ? const Color(0xFF00E5FF)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: isPulled
                              ? [
                                  BoxShadow(
                                    color:
                                        const Color(0xFF00E5FF).withOpacity(0.6),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),

                    // Content: Label, Tactile Grip Grooves, Live % Readout
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Trigger Label (L2 / R2)
                          Text(
                            widget.triggerLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),

                          // Tactile Grip Grooves (Like console triggers)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              3,
                              (i) => Container(
                                width: 22,
                                height: 2,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                      isPulled ? 0.35 : 0.12),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ),

                          // Percentage Readout (100% at top, 0% at bottom)
                          Text(
                            '${(_pullAmount * 100).round()}%',
                            style: TextStyle(
                              color: isPulled
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
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
          const SizedBox(height: 6),

          // 2. Vertical Bumper Button (L1 / R1) - Positioned Below Trigger
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _setBumper(true),
            onPointerUp: (_) => _setBumper(false),
            onPointerCancel: (_) => _setBumper(false),
            child: AnimatedScale(
              scale: _bumperPressed ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 40),
              child: Container(
                width: flankWidth,
                height: bumperHeight,
                decoration: BoxDecoration(
                  color: _bumperPressed
                      ? const Color(0xFF3B4760)
                      : const Color(0xFF1B202D),
                  borderRadius: bumperRadius,
                  border: Border.all(
                    color: _bumperPressed
                        ? Colors.white70
                        : const Color(0xFF2C374A),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
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

/// Compact Visual Wheel Angle Indicator (Leveling meter with live steering feedback)
class _SteeringMeterWidget extends StatelessWidget {
  final double tilt; // -1.0 to +1.0
  final bool isEnabled;
  final VoidCallback onCalibrate;
  final VoidCallback onInvert;

  const _SteeringMeterWidget({
    required this.tilt,
    required this.isEnabled,
    required this.onCalibrate,
    required this.onInvert,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) return const SizedBox.shrink();

    const meterWidth = 84.0;
    const meterHeight = 20.0;
    final clampedTilt = tilt.clamp(-1.0, 1.0);
    // Needle position along the meter width
    final indicatorX = (meterWidth / 2) + (clampedTilt * (meterWidth / 2 - 6));

    return GestureDetector(
      onTap: onCalibrate,
      onDoubleTap: onInvert,
      child: Tooltip(
        message:
            'Tilt Steering Active. Tap to Re-center / Calibrate, Double-tap to Invert.',
        child: Container(
          width: meterWidth,
          height: meterHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                blurRadius: 4,
              )
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center neutral tick mark
              Container(
                width: 1.5,
                height: 10,
                color: Colors.white24,
              ),

              // Left deflection bar from center
              if (clampedTilt < 0)
                Positioned(
                  right: meterWidth / 2,
                  width: (-clampedTilt * (meterWidth / 2 - 4)),
                  height: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(3),
                      ),
                    ),
                  ),
                )
              // Right deflection bar from center
              else if (clampedTilt > 0)
                Positioned(
                  left: meterWidth / 2,
                  width: (clampedTilt * (meterWidth / 2 - 4)),
                  height: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                    ),
                  ),
                ),

              // Dynamic steering needle / bubble
              Positioned(
                left: (indicatorX - 4).clamp(2.0, meterWidth - 10.0),
                top: 3,
                child: Container(
                  width: 8,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF00E5FF),
                        blurRadius: 4,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
