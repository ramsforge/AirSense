import 'package:flutter/material.dart';
import '../models/packet.dart';

enum FaceButtonShape { triangle, circle, cross, square, letter }

class ActionButtons extends StatelessWidget {
  final double size;
  final ControllerMode mode;
  final Function(int buttonBit, bool isPressed) onButtonChange;

  const ActionButtons({
    super.key,
    this.size = 145,
    this.mode = ControllerMode.dualSensePS5,
    required this.onButtonChange,
  });

  @override
  Widget build(BuildContext context) {
    const btnSize = 44.0;
    final isXbox = mode == ControllerMode.xbox360;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // NORTH / TOP (Triangle on PS5 / Y on Xbox)
          Positioned(
            top: 0,
            child: _VectorFaceButton(
              size: btnSize,
              shape: isXbox ? FaceButtonShape.letter : FaceButtonShape.triangle,
              letter: 'Y',
              accentColor: isXbox
                  ? const Color(0xFFFFC700) // Xbox Yellow
                  : const Color(0xFF00FF85), // PS Green
              onStateChanged: (pressed) => onButtonChange(1 << 3, pressed),
            ),
          ),

          // EAST / RIGHT (Circle on PS5 / B on Xbox)
          Positioned(
            right: 0,
            child: _VectorFaceButton(
              size: btnSize,
              shape: isXbox ? FaceButtonShape.letter : FaceButtonShape.circle,
              letter: 'B',
              accentColor: isXbox
                  ? const Color(0xFFE81123) // Xbox Red
                  : const Color(0xFFFF3366), // PS Red
              onStateChanged: (pressed) => onButtonChange(1 << 1, pressed),
            ),
          ),

          // SOUTH / BOTTOM (Cross on PS5 / A on Xbox)
          Positioned(
            bottom: 0,
            child: _VectorFaceButton(
              size: btnSize,
              shape: isXbox ? FaceButtonShape.letter : FaceButtonShape.cross,
              letter: 'A',
              accentColor: isXbox
                  ? const Color(0xFF107C10) // Xbox Green
                  : const Color(0xFF38BDF8), // PS Blue
              onStateChanged: (pressed) => onButtonChange(1 << 0, pressed),
            ),
          ),

          // WEST / LEFT (Square on PS5 / X on Xbox)
          Positioned(
            left: 0,
            child: _VectorFaceButton(
              size: btnSize,
              shape: isXbox ? FaceButtonShape.letter : FaceButtonShape.square,
              letter: 'X',
              accentColor: isXbox
                  ? const Color(0xFF0078D7) // Xbox Blue
                  : const Color(0xFFFF66CC), // PS Pink
              onStateChanged: (pressed) => onButtonChange(1 << 2, pressed),
            ),
          ),
        ],
      ),
    );
  }
}

class _VectorFaceButton extends StatefulWidget {
  final double size;
  final FaceButtonShape shape;
  final String? letter;
  final Color accentColor;
  final ValueChanged<bool> onStateChanged;

  const _VectorFaceButton({
    required this.size,
    required this.shape,
    this.letter,
    required this.accentColor,
    required this.onStateChanged,
  });

  @override
  State<_VectorFaceButton> createState() => _VectorFaceButtonState();
}

class _VectorFaceButtonState extends State<_VectorFaceButton> {
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
            gradient: RadialGradient(
              colors: _isPressed
                  ? [const Color(0xFF333E56), const Color(0xFF1E2638)]
                  : [const Color(0xFF222B3D), const Color(0xFF141924)],
              center: const Alignment(-0.2, -0.2),
            ),
            border: Border.all(
              color: _isPressed
                  ? widget.accentColor
                  : widget.accentColor.withOpacity(0.4),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? widget.accentColor.withOpacity(0.5)
                    : Colors.black.withOpacity(0.5),
                blurRadius: _isPressed ? 14 : 6,
                spreadRadius: _isPressed ? 1 : 0,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: widget.shape == FaceButtonShape.letter
                ? Text(
                    widget.letter ?? '',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      height: 1.0,
                    ),
                  )
                : CustomPaint(
                    size: Size(widget.size * 0.55, widget.size * 0.55),
                    painter: _VectorShapePainter(
                      shape: widget.shape,
                      color: widget.accentColor,
                      strokeWidth: 2.8,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _VectorShapePainter extends CustomPainter {
  final FaceButtonShape shape;
  final Color color;
  final double strokeWidth;

  const _VectorShapePainter({
    required this.shape,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (shape) {
      case FaceButtonShape.triangle:
        const r = 9.0;
        final path = Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + 7.79, cy + 4.5)
          ..lineTo(cx - 7.79, cy + 4.5)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case FaceButtonShape.circle:
        canvas.drawCircle(Offset(cx, cy), 7.8, paint);
        break;

      case FaceButtonShape.cross:
        const d = 6.5;
        canvas.drawLine(Offset(cx - d, cy - d), Offset(cx + d, cy + d), paint);
        canvas.drawLine(Offset(cx - d, cy + d), Offset(cx + d, cy - d), paint);
        break;

      case FaceButtonShape.square:
        const s = 13.5;
        final rect =
            Rect.fromCenter(center: Offset(cx, cy), width: s, height: s);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2.5)), paint);
        break;

      case FaceButtonShape.letter:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _VectorShapePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
