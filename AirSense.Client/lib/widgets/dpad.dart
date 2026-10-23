import 'package:flutter/material.dart';

class DPad extends StatelessWidget {
  final double size;
  final Function(int buttonBit, bool isPressed) onButtonChange;

  const DPad({
    super.key,
    this.size = 150,
    required this.onButtonChange,
  });

  @override
  Widget build(BuildContext context) {
    const btnWidth = 44.0;
    const btnLength = 48.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center base
          Container(
            width: btnWidth,
            height: btnWidth,
            decoration: const BoxDecoration(
              color: Color(0xFF1E222B),
              shape: BoxShape.circle,
            ),
          ),
          // Up
          Positioned(
            top: 0,
            child: _DPadKey(
              width: btnWidth,
              height: btnLength,
              icon: Icons.keyboard_arrow_up,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              onStateChanged: (pressed) => onButtonChange(1 << 4, pressed),
            ),
          ),
          // Down
          Positioned(
            bottom: 0,
            child: _DPadKey(
              width: btnWidth,
              height: btnLength,
              icon: Icons.keyboard_arrow_down,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              onStateChanged: (pressed) => onButtonChange(1 << 5, pressed),
            ),
          ),
          // Left
          Positioned(
            left: 0,
            child: _DPadKey(
              width: btnLength,
              height: btnWidth,
              icon: Icons.keyboard_arrow_left,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              onStateChanged: (pressed) => onButtonChange(1 << 6, pressed),
            ),
          ),
          // Right
          Positioned(
            right: 0,
            child: _DPadKey(
              width: btnLength,
              height: btnWidth,
              icon: Icons.keyboard_arrow_right,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              onStateChanged: (pressed) => onButtonChange(1 << 7, pressed),
            ),
          ),
        ],
      ),
    );
  }
}

class _DPadKey extends StatefulWidget {
  final double width;
  final double height;
  final IconData icon;
  final BorderRadius borderRadius;
  final ValueChanged<bool> onStateChanged;

  const _DPadKey({
    required this.width,
    required this.height,
    required this.icon,
    required this.borderRadius,
    required this.onStateChanged,
  });

  @override
  State<_DPadKey> createState() => _DPadKeyState();
}

class _DPadKeyState extends State<_DPadKey> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) {
      setState(() => _isPressed = pressed);
      widget.onStateChanged(pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: _isPressed ? const Color(0xFF4C586F) : const Color(0xFF222733),
          border: Border.all(
            color: _isPressed ? Colors.white60 : const Color(0xFF353E4E),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(1, 2),
            )
          ],
        ),
        child: Center(
          child: Icon(
            widget.icon,
            color: _isPressed ? Colors.white : Colors.white60,
            size: 24,
          ),
        ),
      ),
    );
  }
}
