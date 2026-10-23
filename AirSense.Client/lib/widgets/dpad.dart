import 'dart:math';
import 'package:flutter/material.dart';

class DPad extends StatefulWidget {
  final double size;
  final Function(int buttonBit, bool isPressed) onButtonChange;

  const DPad({
    super.key,
    this.size = 130,
    required this.onButtonChange,
  });

  @override
  State<DPad> createState() => _DPadState();
}

class _DPadState extends State<DPad> {
  bool _upPressed = false;
  bool _downPressed = false;
  bool _leftPressed = false;
  bool _rightPressed = false;

  static const int _upBit = 1 << 4;
  static const int _downBit = 1 << 5;
  static const int _leftBit = 1 << 6;
  static const int _rightBit = 1 << 7;

  void _handlePointer(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;
    final distance = delta.distance;

    bool up = false;
    bool down = false;
    bool left = false;
    bool right = false;

    // Minimum radial threshold before activating directions (14px deadzone)
    if (distance >= 14) {
      final rad = atan2(delta.dy, delta.dx);
      final deg = rad * (180.0 / pi); // -180 to 180

      // 8-way directional sectors (45 degrees each)
      if (deg >= -22.5 && deg < 22.5) {
        // East (Right)
        right = true;
      } else if (deg >= 22.5 && deg < 67.5) {
        // Southeast (Down + Right)
        down = true;
        right = true;
      } else if (deg >= 67.5 && deg < 112.5) {
        // South (Down)
        down = true;
      } else if (deg >= 112.5 && deg < 157.5) {
        // Southwest (Down + Left)
        down = true;
        left = true;
      } else if (deg >= 157.5 || deg < -157.5) {
        // West (Left)
        left = true;
      } else if (deg >= -157.5 && deg < -112.5) {
        // Northwest (Up + Left)
        up = true;
        left = true;
      } else if (deg >= -112.5 && deg < -67.5) {
        // North (Up)
        up = true;
      } else if (deg >= -67.5 && deg < -22.5) {
        // Northeast (Up + Right)
        up = true;
        right = true;
      }
    }

    _applyStates(up: up, down: down, left: left, right: right);
  }

  void _releaseAll() {
    _applyStates(up: false, down: false, left: false, right: false);
  }

  void _applyStates({
    required bool up,
    required bool down,
    required bool left,
    required bool right,
  }) {
    if (up != _upPressed) {
      _upPressed = up;
      widget.onButtonChange(_upBit, up);
    }
    if (down != _downPressed) {
      _downPressed = down;
      widget.onButtonChange(_downBit, down);
    }
    if (left != _leftPressed) {
      _leftPressed = left;
      widget.onButtonChange(_leftBit, left);
    }
    if (right != _rightPressed) {
      _rightPressed = right;
      widget.onButtonChange(_rightBit, right);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const armWidth = 44.0;
    const armLength = 48.0;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _handlePointer(e.localPosition),
        onPointerMove: (e) => _handlePointer(e.localPosition),
        onPointerUp: (_) => _releaseAll(),
        onPointerCancel: (_) => _releaseAll(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center Intersection Hub
            Container(
              width: armWidth,
              height: armWidth,
              decoration: BoxDecoration(
                color: const Color(0xFF161A24),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF283244), width: 1.5),
              ),
            ),

            // UP Arm
            Positioned(
              top: 0,
              child: _DPadWingVisual(
                width: armWidth,
                height: armLength,
                icon: Icons.keyboard_arrow_up,
                isPressed: _upPressed,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(9)),
              ),
            ),

            // DOWN Arm
            Positioned(
              bottom: 0,
              child: _DPadWingVisual(
                width: armWidth,
                height: armLength,
                icon: Icons.keyboard_arrow_down,
                isPressed: _downPressed,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(9)),
              ),
            ),

            // LEFT Arm
            Positioned(
              left: 0,
              child: _DPadWingVisual(
                width: armLength,
                height: armWidth,
                icon: Icons.keyboard_arrow_left,
                isPressed: _leftPressed,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(9)),
              ),
            ),

            // RIGHT Arm
            Positioned(
              right: 0,
              child: _DPadWingVisual(
                width: armLength,
                height: armWidth,
                icon: Icons.keyboard_arrow_right,
                isPressed: _rightPressed,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(9)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DPadWingVisual extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final bool isPressed;
  final BorderRadius borderRadius;

  const _DPadWingVisual({
    required this.width,
    required this.height,
    required this.icon,
    required this.isPressed,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isPressed ? const Color(0xFF2C394F) : const Color(0xFF1A202D),
        borderRadius: borderRadius,
        border: Border.all(
          color: isPressed ? const Color(0xFF00C8FF) : const Color(0xFF2C384D),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPressed
                ? const Color(0xFF00C8FF).withOpacity(0.4)
                : Colors.black.withOpacity(0.4),
            blurRadius: isPressed ? 8 : 4,
          )
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          color: isPressed ? const Color(0xFF00C8FF) : const Color(0xFFCBD5E1),
          size: 26,
        ),
      ),
    );
  }
}
