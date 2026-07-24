import 'package:flutter/material.dart';

class RangeAreaPainter extends CustomPainter {
  final double? startX; // en metres
  final double? endX; // en metres
  final double chartHeight; // alçada del gràfic en píxels
  final double maxDistance; // metres totals del track

  RangeAreaPainter({
    required this.startX,
    required this.endX,
    required this.chartHeight,
    required this.maxDistance,
  });

  double _toPixelX(double meters, double width) {
    if (maxDistance <= 0) return 0;
    return (meters / maxDistance) * width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (startX == null || endX == null) return;

    final double left = _toPixelX(startX!, size.width);
    final double right = _toPixelX(endX!, size.width);

    final Rect rect = Rect.fromLTRB(left, 0, right, chartHeight);

    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.orange.withOpacity(0.25),
          Colors.orange.withOpacity(0.45),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant RangeAreaPainter oldDelegate) {
    return startX != oldDelegate.startX ||
        endX != oldDelegate.endX ||
        maxDistance != oldDelegate.maxDistance ||
        chartHeight != oldDelegate.chartHeight;
  }
}
