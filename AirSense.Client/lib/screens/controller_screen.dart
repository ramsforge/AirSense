import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
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
  bool _gyroEnabled = true;

  // Telemetry simulation (live micro-jitter)
  Timer? _telemetryTimer;
  double _currentRtt = 2.4;

  @override
  void initState() {
    super.initState();
    // Force Landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _startGyro();

    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) {
        setState(() {
          _currentRtt = 1.8 + (DateTime.now().millisecond % 14) / 10.0;
        });
      }
    });
  }

  void _startGyro() {
    _gyroSub = gyroscopeEventStream().listen((event) {
      if (!_gyroEnabled) return;
      widget.network.currentPacket.gyroPitch = event.x;
      widget.network.currentPacket.gyroYaw = event.y;
      widget.network.currentPacket.gyroRoll = event.z;
    });
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _gyroSub?.cancel();
    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
                      // Brand Badge
                      const Row(
                        children: [
                          Icon(Icons.sports_esports,
                              color: Color(0xFF00C8FF), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'AirSense',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      // Expanded Telemetry Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161A24).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF2D374A).withOpacity(0.8),
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
                            // Pulsing green LAN dot
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF10B981),
                                    blurRadius: 6,
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'LAN (120 Hz)',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
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

                            // RTT Latency
                            const Text(
                              'RTT: ',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10.5,
                              ),
                            ),
                            Text(
                              '${_currentRtt.toStringAsFixed(1)} ms',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
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

                            // Battery Percentage
                            const Icon(Icons.battery_full,
                                color: Color(0xFF10B981), size: 14),
                            const SizedBox(width: 3),
                            const Text(
                              '94%',
                              style: TextStyle(
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
                            tooltip: 'Toggle Motion Gyro',
                            onPressed: () {
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
                      // LEFT WING: Stacked Shoulder (L2/L1) + Cluster (D-Pad & Elevated Left Stick)
                      SizedBox(
                        width: 270,
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

                            // Cluster: D-Pad & Elevated Left Stick
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                DPad(
                                  size: 122,
                                  onButtonChange: _updateButton,
                                ),
                                // Elevated Left Stick along natural thumb arc
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: VirtualJoystick(
                                    size: 114,
                                    label: 'L3',
                                    onChanged: (offset) {
                                      widget.network.currentPacket.leftStickX =
                                          (offset.dx * 32767).round();
                                      widget.network.currentPacket.leftStickY =
                                          (offset.dy * 32767).round();
                                    },
                                    onStickClick: () {
                                      _updateButton(1 << 12, true);
                                      Future.delayed(
                                          const Duration(milliseconds: 100), () {
                                        _updateButton(1 << 12, false);
                                      });
                                    },
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

                      // RIGHT WING: Stacked Shoulder (R2/R1) + Cluster (Elevated Right Stick & Face Buttons)
                      SizedBox(
                        width: 270,
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

                            // Cluster: Elevated Right Stick & Face Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Elevated Right Stick along natural thumb arc
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: VirtualJoystick(
                                    size: 114,
                                    label: 'R3',
                                    onChanged: (offset) {
                                      widget.network.currentPacket.rightStickX =
                                          (offset.dx * 32767).round();
                                      widget.network.currentPacket.rightStickY =
                                          (offset.dy * 32767).round();
                                    },
                                    onStickClick: () {
                                      _updateButton(1 << 13, true);
                                      Future.delayed(
                                          const Duration(milliseconds: 100), () {
                                        _updateButton(1 << 13, false);
                                      });
                                    },
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

/// Vertically stacked trigger & bumper assembly (Trigger pedal on top, Bumper below)
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

  void _updateTrigger(double deltaY) {
    final amount = (deltaY / 44.0).clamp(0.0, 1.0);
    setState(() => _pullAmount = amount);
    widget.onTriggerChanged((amount * 255).round());
  }

  void _releaseTrigger() {
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
          // 1. Large Trigger Pedal (L2 / R2) - Positioned on Top
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              setState(() => _pullAmount = 1.0);
              widget.onTriggerChanged(255);
            },
            onPointerMove: (e) => _updateTrigger(e.localPosition.dy),
            onPointerUp: (_) => _releaseTrigger(),
            onPointerCancel: (_) => _releaseTrigger(),
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

          // 2. Bumper Bar (L1 / R1) - Positioned Below Trigger
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
                      color:
                          _bumperPressed ? Colors.white : const Color(0xFF94A3B8),
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
