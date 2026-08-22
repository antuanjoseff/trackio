import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:trackio/core/theme/app_colors.dart';

class RangeAreaPainter extends CustomPainter {
  final double? startX; // Píxels reals d'inici de l'agulla verda (X)
  final double? endX; // Píxels reals de final de l'agulla vermella (X)
  final double chartHeight;
  final double maxDistance; // Metres totals del track (maxX)
  final List<FlSpot>
  spots; // 🌟 REPARACIÓ: Reben directament els mateixos spots que fl_chart
  final double minY;
  final double maxY;
  final int? startIdx; // Índex real on comença el rang filtrat
  final int? endIdx; // Índex real on acaba el rang filtrat

  RangeAreaPainter({
    required this.startX,
    required this.endX,
    required this.chartHeight,
    required this.maxDistance,
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.startIdx,
    required this.endIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 🔒 PROTECCIÓ: Si falten descriptors crítics o el rang és invàlid, sortim en net
    if (startX == null ||
        endX == null ||
        spots.isEmpty ||
        startIdx == null ||
        endIdx == null) {
      return;
    }

    if (startIdx! >= endIdx! ||
        startIdx! >= spots.length ||
        endIdx! >= spots.length) {
      return;
    }

    const double topOffset = 0.0;
    const double bottomOffset = 22.0;

    final double xAxisY = chartHeight - bottomOffset;
    final double usableChartHeight = xAxisY - topOffset;

    const double paddingLeft = 12.0;
    const double paddingRight = 24.0;
    final double chartWidth = size.width - paddingLeft - paddingRight;

    if (chartWidth <= 0 || maxDistance <= 0) return;

    final Path path = Path();

    final double yRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);

    bool firstPoint = true;

    // Recorrem exactament el tram seleccionat
    for (int i = startIdx!; i <= endIdx!; i++) {
      final FlSpot spot = spots[i];

      final double pctX = spot.x / maxDistance;
      final double currentX = paddingLeft + (pctX * chartWidth);

      final double relY = (spot.y - minY) / yRange;
      final double currentY =
          topOffset + (usableChartHeight * (1.0 - relY.clamp(0.0, 1.0)));

      if (firstPoint) {
        // Baixem primer fins a la base i després pugem al perfil
        path.moveTo(currentX, xAxisY);
        path.lineTo(currentX, currentY);
        firstPoint = false;
      } else {
        path.lineTo(currentX, currentY);
      }
    }

    // Tornem al terra al final del tram
    path.lineTo(endX!, xAxisY);

    // Tanquem fins al punt inicial
    path.close();

    // 🎨 Degradat de la superfície seleccionada
    final Rect boundingRect = Rect.fromLTRB(startX!, 0.0, endX!, xAxisY);

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          AppColors.starTrekGold.withAlpha(70),
          AppColors.starTrekGold.withAlpha(230),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(boundingRect);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RangeAreaPainter oldDelegate) {
    return startX != oldDelegate.startX ||
        endX != oldDelegate.endX ||
        maxDistance != oldDelegate.maxDistance ||
        chartHeight != oldDelegate.chartHeight ||
        minY != oldDelegate.minY ||
        maxY != oldDelegate.maxY ||
        startIdx != oldDelegate.startIdx ||
        endIdx != oldDelegate.endIdx ||
        spots.length != oldDelegate.spots.length;
  }
}
