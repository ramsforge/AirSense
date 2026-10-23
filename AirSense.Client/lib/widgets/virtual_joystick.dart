import 'dart:math';
import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final double size;
  final String label;
  final ValueChanged<Offset> onChanged; // Returns normalized (-1.0 to 1.0)
  final VoidCallback? onStickClick;    // L3 / R3

  const VirtualJoystick({
    super.key,
    this.size = 120,
    required this.label,
    required this.onChanged,
    this.onStickClick,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _springController;
  late Animation<Offset> _springAnimation;

  final double _deadzone = 0.06;   // 6% inner deadzone
  final double _powerCurve = 1.45; // Progressive sensitivity curve

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _springAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_springController);

    _springController.addListener(() {
      if (!_isDragging && mounted) {
        setState(() {
          _dragOffset = _springAnimation.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _springController.stop();
    _isDragging = true;
    _updatePosition(event.localPosition);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isDragging) {
      _updatePosition(event.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _release();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _release();
  }

  void _release() {
    _isDragging = false;

    // Damped spring return animation only when released
    _springAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.easeOutBack,
    ));

    _springController.forward(from: 0.0);
    widget.onChanged(Offset.zero);
  }

  void _updatePosition(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;
    final maxRadius = max(1.0, (widget.size / 2) - 16);

    final distance = delta.distance;
    if (distance == 0.0) {
      setState(() {
        _dragOffset = Offset.zero;
      });
      widget.onChanged(Offset.zero);
      return;
    }

    // Strict circular radial vector clamping (r <= maxRadius)
    final angle = atan2(delta.dy, delta.dx);
    final clampedDistance = min(distance, maxRadius);

    final clampedOffset = Offset(
      cos(angle) * clampedDistance,
      sin(angle) * clampedDistance,
    );

    setState(() {
      _dragOffset = clampedOffset;
    });

    // Deadzone and exponential power curve calculation
    final normDistance = (clampedDistance / maxRadius).clamp(0.0, 1.0);
    if (normDistance <= _deadzone) {
      widget.onChanged(Offset.zero);
    } else {
      // Remap from 0.0 -> 1.0 outside deadzone
      final remapped = ((normDistance - _deadzone) / (1.0 - _deadzone)).clamp(0.0, 1.0);
      // Apply power curve for precise crosshair micro-aiming
      final curved = pow(remapped, _powerCurve).toDouble();

      final outputX = (cos(angle) * curved).clamp(-1.0, 1.0);
      final outputY = (-sin(angle) * curved).clamp(-1.0, 1.0); // Up is positive
      widget.onChanged(Offset(outputX, outputY));
    }
  }

  @override
  Widget build(BuildContext context) {
    const knobRadius = 28.0;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          onDoubleTap: widget.onStickClick,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF1E2433), Color(0xFF10141D)],
              ),
              border: Border.all(color: const Color(0xFF2D3748), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center deadzone reference ring
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1.5,
                    ),
                  ),
                ),

                // Thumb Knob with decoupled translation
                Transform.translate(
                  offset: _dragOffset,
                  child: Container(
                    width: knobRadius * 2,
                    height: knobRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF3B475D), Color(0xFF1C2230)],
                        center: Alignment(-0.25, -0.25),
                      ),
                      border: Border.all(
                        color: const Color(0xFF4A5568),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 10,
                          offset: const Offset(2, 4),
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
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
        ),
      ),
    );
  }
}
