import 'dart:async';
import 'package:flutter/material.dart';

class TouchpadArea extends StatefulWidget {
  final double width;
  final double height;
  final Color lightbarColor;
  final Function(bool active, int x, int y) onTouchpadChange;
  final Function(int buttonBit, bool isPressed) onSpecialButtonChange;

  const TouchpadArea({
    super.key,
    this.width = 200,
    this.height = 100,
    required this.lightbarColor,
    required this.onTouchpadChange,
    required this.onSpecialButtonChange,
  });

  @override
  State<TouchpadArea> createState() => _TouchpadAreaState();
}

class _TouchpadAreaState extends State<TouchpadArea>
    with SingleTickerProviderStateMixin {
  Offset? _touchPosition;

  // Safe hold-to-activate PS button timer
  late AnimationController _psHoldController;
  bool _isHoldingPS = false;

  @override
  void initState() {
    super.initState();
    _psHoldController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // 1.2s required hold
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _triggerPSButton();
        }
      });
  }

  @override
  void dispose() {
    _psHoldController.dispose();
    super.dispose();
  }

  void _triggerPSButton() {
    widget.onSpecialButtonChange(1 << 16, true);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('✓ PlayStation Home Activated'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF10B981),
      ),
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      widget.onSpecialButtonChange(1 << 16, false);
    });
  }

  void _startPSHold() {
    setState(() => _isHoldingPS = true);
    _psHoldController.forward(from: 0.0);
  }

  void _cancelPSHold() {
    if (_isHoldingPS) {
      setState(() => _isHoldingPS = false);
      _psHoldController.reset();
    }
  }

  void _updateTouch(Offset localPos) {
    setState(() => _touchPosition = localPos);

    final clampedX = (localPos.dx / widget.width).clamp(0.0, 1.0);
    final clampedY = (localPos.dy / widget.height).clamp(0.0, 1.0);

    final x = (clampedX * 1920).round();
    final y = (clampedY * 1080).round();

    widget.onTouchpadChange(true, x, y);
  }

  void _releaseTouch() {
    setState(() => _touchPosition = null);
    widget.onTouchpadChange(false, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top utility bar (Share, Glow strip, Options)
        SizedBox(
          width: widget.width,
          child: Row(
            children: [
              _UtilityPillButton(
                label: 'SHARE',
                onStateChanged: (pressed) =>
                    widget.onSpecialButtonChange(1 << 14, pressed),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 5,
                    decoration: BoxDecoration(
                      color: widget.lightbarColor,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: widget.lightbarColor.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _UtilityPillButton(
                label: 'OPTIONS',
                onStateChanged: (pressed) =>
                    widget.onSpecialButtonChange(1 << 15, pressed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Proportional Scaled Touchpad Surface
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _updateTouch(details.localPosition);
            widget.onSpecialButtonChange(1 << 17, true);
          },
          onTapUp: (_) {
            _releaseTouch();
            widget.onSpecialButtonChange(1 << 17, false);
          },
          onTapCancel: () {
            _releaseTouch();
            widget.onSpecialButtonChange(1 << 17, false);
          },
          onPanStart: (details) => _updateTouch(details.localPosition),
          onPanUpdate: (details) => _updateTouch(details.localPosition),
          onPanEnd: (_) => _releaseTouch(),
          onPanCancel: _releaseTouch,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF131722),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.lightbarColor.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    'TOUCHPAD',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.18),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (_touchPosition != null)
                  Positioned(
                    left: _touchPosition!.dx - 12,
                    top: _touchPosition!.dy - 12,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.lightbarColor.withOpacity(0.35),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Protected Hold-To-Activate PS / Power Button
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _startPSHold(),
          onPointerUp: (_) => _cancelPSHold(),
          onPointerCancel: (_) => _cancelPSHold(),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _psHoldController,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          value: _psHoldController.value,
                          strokeWidth: 2.5,
                          backgroundColor: const Color(0xFF283042),
                          color: const Color(0xFF00C8FF),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isHoldingPS
                              ? const Color(0xFF2E384D)
                              : const Color(0xFF1C2230),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.sports_esports,
                            color: Color(0xFFCBD5E1),
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 3),
              Text(
                _isHoldingPS ? 'HOLDING...' : 'HOLD 1.2s FOR PS',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: _isHoldingPS
                      ? const Color(0xFF00C8FF)
                      : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UtilityPillButton extends StatefulWidget {
  final String label;
  final ValueChanged<bool> onStateChanged;

  const _UtilityPillButton({
    required this.label,
    required this.onStateChanged,
  });

  @override
  State<_UtilityPillButton> createState() => _UtilityPillButtonState();
}

class _UtilityPillButtonState extends State<_UtilityPillButton> {
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
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFF3B4760) : const Color(0xFF1C2230),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2D374A), width: 1),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _pressed ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
