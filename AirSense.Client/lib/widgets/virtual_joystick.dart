import 'dart:math';
import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final double size;
  final String label;
  final ValueChanged<Offset> onChanged; // Returns normalized (-1.0 to 1.0)
  final VoidCallback? onStickClick;    // L3 / R3

  const VirtualJoystick({
    super.key,
    this.size = 140,
    required this.label,
    required this.onChanged,
    this.onStickClick,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _dragPosition = Offset.zero;

  void _updatePosition(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;
    final maxRadius = widget.size / 2 - 20;

    final distance = delta.distance;
    Offset clamped;

    if (distance > maxRadius) {
      clamped = Offset.fromDirection(delta.direction, maxRadius);
    } else {
      clamped = delta;
    }

    setState(() {
      _dragPosition = clamped;
    });

    // Deadzone (5%)
    final normalizedX = clamped.dx / maxRadius;
    final normalizedY = -clamped.dy / maxRadius; // Up positive

    final double deadzone = 0.05;
    final double finalX = normalizedX.abs() < deadzone ? 0.0 : normalizedX;
    final double finalY = normalizedY.abs() < deadzone ? 0.0 : normalizedY;

    widget.onChanged(Offset(finalX, finalY));
  }

  void _reset() {
    setState(() {
      _dragPosition = Offset.zero;
    });
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final knobRadius = 30.0;
    final center = Offset(widget.size / 2, widget.size / 2);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onStickClick,
      onPanStart: (details) => _updatePosition(details.localPosition),
      onPanUpdate: (details) => _updatePosition(details.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E222B).withOpacity(0.85),
          border: Border.all(color: const Color(0xFF2C3240), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center ring indicator
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
            ),
            // Thumb knob
            Positioned(
              left: center.dx + _dragPosition.dx - knobRadius,
              top: center.dy + _dragPosition.dy - knobRadius,
              child: Container(
                width: knobRadius * 2,
                height: knobRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF3A4454), Color(0xFF1E222A)],
                    center: Alignment(-0.2, -0.2),
                  ),
                  border: Border.all(color: const Color(0xFF4C586F), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
