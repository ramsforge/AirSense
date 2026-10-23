import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final double size;
  final Function(int buttonBit, bool isPressed) onButtonChange;

  const ActionButtons({
    super.key,
    this.size = 130,
    required this.onButtonChange,
  });

  @override
  Widget build(BuildContext context) {
    const btnSize = 42.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Triangle (Top) - Green Outline
          Positioned(
            top: 0,
            child: _HarmonizedFaceButton(
              size: btnSize,
              symbol: '△',
              symbolColor: const Color(0xFF00FF85),
              onStateChanged: (pressed) => onButtonChange(1 << 3, pressed),
            ),
          ),

          // Circle (Right) - Red Outline (NOT a solid dot!)
          Positioned(
            right: 0,
            child: _HarmonizedFaceButton(
              size: btnSize,
              symbol: '○',
              symbolColor: const Color(0xFFFF3366),
              onStateChanged: (pressed) => onButtonChange(1 << 1, pressed),
            ),
          ),

          // Cross (Bottom) - Blue Outline
          Positioned(
            bottom: 0,
            child: _HarmonizedFaceButton(
              size: btnSize,
              symbol: '✕',
              symbolColor: const Color(0xFF3399FF),
              onStateChanged: (pressed) => onButtonChange(1 << 0, pressed),
            ),
          ),

          // Square (Left) - Pink Outline
          Positioned(
            left: 0,
            child: _HarmonizedFaceButton(
              size: btnSize,
              symbol: '□',
              symbolColor: const Color(0xFFFF66CC),
              onStateChanged: (pressed) => onButtonChange(1 << 2, pressed),
            ),
          ),
        ],
      ),
    );
  }
}

class _HarmonizedFaceButton extends StatefulWidget {
  final double size;
  final String symbol;
  final Color symbolColor;
  final ValueChanged<bool> onStateChanged;

  const _HarmonizedFaceButton({
    required this.size,
    required this.symbol,
    required this.symbolColor,
    required this.onStateChanged,
  });

  @override
  State<_HarmonizedFaceButton> createState() => _HarmonizedFaceButtonState();
}

class _HarmonizedFaceButtonState extends State<_HarmonizedFaceButton> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) {
      setState(() => _isPressed = pressed);
      widget.onStateChanged(pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isPressed ? const Color(0xFF2B354A) : const Color(0xFF1E2433),
            border: Border.all(
              color: _isPressed
                  ? widget.symbolColor
                  : widget.symbolColor.withOpacity(0.35),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? widget.symbolColor.withOpacity(0.4)
                    : Colors.black.withOpacity(0.5),
                blurRadius: _isPressed ? 14 : 6,
                spreadRadius: _isPressed ? 1 : 0,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: Text(
              widget.symbol,
              style: TextStyle(
                color: widget.symbolColor,
                fontSize: 21,
                fontWeight: FontWeight.w400,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
