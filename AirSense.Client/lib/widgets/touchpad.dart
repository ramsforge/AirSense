import 'package:flutter/material.dart';

class TouchpadArea extends StatefulWidget {
  final double width;
  final double height;
  final Color lightbarColor;
  final Function(bool active, int x, int y) onTouchpadChange;
  final Function(int buttonBit, bool isPressed) onSpecialButtonChange;

  const TouchpadArea({
    super.key,
    this.width = 240,
    this.height = 130,
    required this.lightbarColor,
    required this.onTouchpadChange,
    required this.onSpecialButtonChange,
  });

  @override
  State<TouchpadArea> createState() => _TouchpadAreaState();
}

class _TouchpadAreaState extends State<TouchpadArea> {
  Offset? _touchPosition;

  void _updateTouch(Offset localPos) {
    setState(() => _touchPosition = localPos);

    // Normalize coordinates: 0 to 1920, 0 to 1080 (DualSense resolution)
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
        // Top navigation buttons (Share, Lightbar indicator, Options)
        SizedBox(
          width: widget.width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Share button
              _SpecialSmallButton(
                label: 'SHARE',
                onStateChanged: (pressed) =>
                    widget.onSpecialButtonChange(1 << 14, pressed),
              ),

              // Lightbar glow strip
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 90,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.lightbarColor,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: widget.lightbarColor.withOpacity(0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),

              // Options button
              _SpecialSmallButton(
                label: 'OPTIONS',
                onStateChanged: (pressed) =>
                    widget.onSpecialButtonChange(1 << 15, pressed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Main Touchpad Surface
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _updateTouch(details.localPosition);
            // Clicking the touchpad triggers TouchpadClick
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
              color: const Color(0xFF1B1E26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.lightbarColor.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.lightbarColor.withOpacity(0.15),
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
                      color: Colors.white.withOpacity(0.15),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_touchPosition != null)
                  Positioned(
                    left: _touchPosition!.dx - 15,
                    top: _touchPosition!.dy - 15,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.lightbarColor.withOpacity(0.4),
                        border: Border.all(color: Colors.white70, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        // PS Button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => widget.onSpecialButtonChange(1 << 16, true),
          onTapUp: (_) => widget.onSpecialButtonChange(1 << 16, false),
          onTapCancel: () => widget.onSpecialButtonChange(1 << 16, false),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF222733),
              border: Border.all(color: const Color(0xFF353E4E), width: 1.5),
            ),
            child: const Center(
              child: Icon(
                Icons.sports_esports,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpecialSmallButton extends StatefulWidget {
  final String label;
  final ValueChanged<bool> onStateChanged;

  const _SpecialSmallButton({
    required this.label,
    required this.onStateChanged,
  });

  @override
  State<_SpecialSmallButton> createState() => _SpecialSmallButtonState();
}

class _SpecialSmallButtonState extends State<_SpecialSmallButton> {
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFF4C586F) : const Color(0xFF222733),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF353E4E), width: 1),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _pressed ? Colors.white : Colors.white60,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
