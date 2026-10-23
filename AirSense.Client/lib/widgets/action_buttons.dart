import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final double size;
  final Function(int buttonBit, bool isPressed) onButtonChange;

  const ActionButtons({
    super.key,
    this.size = 150,
    required this.onButtonChange,
  });

  @override
  Widget build(BuildContext context) {
    const btnSize = 44.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Triangle (Top) - Green
          Positioned(
            top: 0,
            child: _GamepadButton(
              size: btnSize,
              symbol: '▲',
              symbolColor: const Color(0xFF00FF85),
              onStateChanged: (pressed) => onButtonChange(1 << 3, pressed),
            ),
          ),
          // Circle (Right) - Red
          Positioned(
            right: 0,
            child: _GamepadButton(
              size: btnSize,
              symbol: '●',
              symbolColor: const Color(0xFFFF3366),
              onStateChanged: (pressed) => onButtonChange(1 << 1, pressed),
            ),
          ),
          // Cross (Bottom) - Blue
          Positioned(
            bottom: 0,
            child: _GamepadButton(
              size: btnSize,
              symbol: '✕',
              symbolColor: const Color(0xFF3399FF),
              onStateChanged: (pressed) => onButtonChange(1 << 0, pressed),
            ),
          ),
          // Square (Left) - Pink
          Positioned(
            left: 0,
            child: _GamepadButton(
              size: btnSize,
              symbol: '■',
              symbolColor: const Color(0xFFFF66CC),
              onStateChanged: (pressed) => onButtonChange(1 << 2, pressed),
            ),
          ),
        ],
      ),
    );
  }
}

class _GamepadButton extends StatefulWidget {
  final double size;
  final String symbol;
  final Color symbolColor;
  final ValueChanged<bool> onStateChanged;

  const _GamepadButton({
    required this.size,
    required this.symbol,
    required this.symbolColor,
    required this.onStateChanged,
  });

  @override
  State<_GamepadButton> createState() => _GamepadButtonState();
}

class _GamepadButtonState extends State<_GamepadButton> {
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
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed
              ? widget.symbolColor.withOpacity(0.35)
              : const Color(0xFF222733),
          border: Border.all(
            color: _isPressed ? widget.symbolColor : const Color(0xFF3A4456),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isPressed
                  ? widget.symbolColor.withOpacity(0.4)
                  : Colors.black.withOpacity(0.5),
              blurRadius: _isPressed ? 12 : 6,
              offset: const Offset(1, 2),
            )
          ],
        ),
        child: Center(
          child: Text(
            widget.symbol,
            style: TextStyle(
              color: widget.symbolColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
