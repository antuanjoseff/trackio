import 'package:flutter/material.dart';

class MapFullScreenReticle extends StatelessWidget {
  final Color color;

  const MapFullScreenReticle({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _FullScreenReticlePainter(color: color),
      ),
    );
  }
}

class _FullScreenReticlePainter extends CustomPainter {
  final Color color;
  static const double _squareSize = 5.0;

  const _FullScreenReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    final squarePaint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: _squareSize, height: _squareSize),
      squarePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FullScreenReticlePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
