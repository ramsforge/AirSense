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
          backgroundColor: const Color(0xFF0F1117),
          body: SafeArea(
            child: Stack(
              children: [
                // Subtle Ambient Lightbar Glow Background
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 300,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            lightColor.withOpacity(0.25),
                            Colors.transparent,
                          ],
                          radius: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Trigger Bar (L1, L2, Gyro Toggle, Disconnect, R1, R2)
                Positioned(
                  top: 10,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Triggers (L2, L1)
                      Row(
                        children: [
                          _TriggerButton(
                            label: 'L2',
                            onTriggerChanged: (val) {
                              widget.network.currentPacket.leftTrigger = val;
                              _updateButton(1 << 10, val > 200);
                            },
                          ),
                          const SizedBox(width: 8),
                          _BumperButton(
                            label: 'L1',
                            onStateChanged: (pressed) =>
                                _updateButton(1 << 8, pressed),
                          ),
                        ],
                      ),

                      // Center utility buttons (Gyro toggle, Disconnect)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _gyroEnabled
                                  ? Icons.screen_rotation
                                  : Icons.screen_rotation_outlined,
                              color: _gyroEnabled ? lightColor : Colors.white30,
                              size: 20,
                            ),
                            tooltip: 'Toggle Gyro Motion',
                            onPressed: () {
                              setState(() => _gyroEnabled = !_gyroEnabled);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.power_settings_new,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            tooltip: 'Disconnect',
                            onPressed: () {
                              widget.network.disconnect();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),

                      // Right Triggers (R1, R2)
                      Row(
                        children: [
                          _BumperButton(
                            label: 'R1',
                            onStateChanged: (pressed) =>
                                _updateButton(1 << 9, pressed),
                          ),
                          const SizedBox(width: 8),
                          _TriggerButton(
                            label: 'R2',
                            onTriggerChanged: (val) {
                              widget.network.currentPacket.rightTrigger = val;
                              _updateButton(1 << 11, val > 200);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Gameplay Controls Area
                Positioned.fill(
                  top: 60,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Column: D-Pad & Left Stick
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            DPad(
                              size: 130,
                              onButtonChange: _updateButton,
                            ),
                            VirtualJoystick(
                              size: 120,
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
                          ],
                        ),

                        // Center: Touchpad Area
                        TouchpadArea(
                          width: 220,
                          height: 120,
                          lightbarColor: lightColor,
                          onTouchpadChange: (active, x, y) {
                            widget.network.currentPacket.touchpadActive =
                                active ? 1 : 0;
                            widget.network.currentPacket.touchpadX = x;
                            widget.network.currentPacket.touchpadY = y;
                          },
                          onSpecialButtonChange: _updateButton,
                        ),

                        // Right Column: Action Buttons & Right Stick
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ActionButtons(
                              size: 130,
                              onButtonChange: _updateButton,
                            ),
                            VirtualJoystick(
                              size: 120,
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
                          ],
                        ),
                      ],
                    ),
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

class _BumperButton extends StatefulWidget {
  final String label;
  final ValueChanged<bool> onStateChanged;

  const _BumperButton({required this.label, required this.onStateChanged});

  @override
  State<_BumperButton> createState() => _BumperButtonState();
}

class _BumperButtonState extends State<_BumperButton> {
  bool _pressed = false;

  void _set(bool val) {
    if (_pressed != val) {
      setState(() => _pressed = val);
      widget.onStateChanged(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: Container(
        width: 65,
        height: 38,
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFF4C586F) : const Color(0xFF222733),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _pressed ? Colors.white70 : const Color(0xFF353E4E),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _TriggerButton extends StatefulWidget {
  final String label;
  final ValueChanged<int> onTriggerChanged; // 0 to 255

  const _TriggerButton({
    required this.label,
    required this.onTriggerChanged,
  });

  @override
  State<_TriggerButton> createState() => _TriggerButtonState();
}

class _TriggerButtonState extends State<_TriggerButton> {
  double _pullAmount = 0.0; // 0.0 to 1.0

  void _update(double deltaY) {
    final amount = (deltaY / 40.0).clamp(0.0, 1.0);
    setState(() => _pullAmount = amount);
    widget.onTriggerChanged((amount * 255).round());
  }

  void _release() {
    setState(() => _pullAmount = 0.0);
    widget.onTriggerChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    final isPulled = _pullAmount > 0.05;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pullAmount = 1.0);
        widget.onTriggerChanged(255);
      },
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onVerticalDragUpdate: (d) => _update(d.localPosition.dy),
      onVerticalDragEnd: (_) => _release(),
      child: Container(
        width: 65,
        height: 38,
        decoration: BoxDecoration(
          color: isPulled ? const Color(0xFF354B70) : const Color(0xFF1B1E26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPulled ? const Color(0xFF3399FF) : const Color(0xFF2E3747),
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fill level
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 38 * _pullAmount,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3399FF).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
