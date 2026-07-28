import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
        endIdx == null)
      return;
    if (startIdx! >= endIdx! ||
        startIdx! >= spots.length ||
        endIdx! >= spots.length)
      return;

    final double topOffset = 0.0;
    final double bottomOffset = 22.0;
    final double usableChartHeight = chartHeight - topOffset - bottomOffset;
    final double xAxisY =
        chartHeight -
        bottomOffset; // El terra unificat on descansen les agulles

    // Constants de padding horitzontal de la gràfica
    const double paddingLeft = 12.0;
    const double paddingRight = 24.0;
    final double chartWidth = size.width - paddingLeft - paddingRight;

    if (chartWidth <= 0 || maxDistance <= 0) return;

    // 📐 1. CONSTRUCCIÓ DEL PATH RESSEGUINT ELS METRES REALS DELS SPOTS
    final Path path = Path();

    // El polígon neix a la base inferior de l'agulla verda (startX, Y del terra)
    path.moveTo(startX!, xAxisY);

    final double yRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);

    // Recorrem node per node el tram seleccionat del perfil utilitzant exactament els spots del gràfic de línies
    for (int i = startIdx!; i <= endIdx!; i++) {
      final FlSpot spot = spots[i];

      // 🌟 CLAVAT GEOMÈTRIC DE L'EIX X:
      // Calculem la posició basant-nos en els METRES REALS acumulats en aquest punt (spot.x)
      // i no en l'índex, replicant exactament la mateixa regla de tres interna que fa fl_chart
      final double pctX = spot.x / maxDistance;
      final double currentX = paddingLeft + (pctX * chartWidth);

      // Calculem l'alçada Y exacta per a l'altitud d'aquest spot (spot.y)
      final double relY = (spot.y - minY) / yRange;
      final double currentY =
          topOffset + (usableChartHeight * (1.0 - relY.clamp(0.0, 1.0)));

      // Unim els punts resseguint el perfil real de la muntanya
      path.lineTo(currentX, currentY);
    }

    // Un cop acabat el recorregut, baixem en línia recta de tornada cap al terra de l'agulla vermella (endX, Y del terra)
    path.lineTo(endX!, xAxisY);

    // Tanquem el polígon connectant l'últim punt amb la base del punt de partida
    path.close();

    // 🎨 2. APLICACIÓ DEL DEGRADAT INTERN DE CORTESIA
    final Rect boundingRect = Rect.fromLTRB(startX!, 0.0, endX!, xAxisY);
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          Colors.orange.withOpacity(0.12),
          Colors.orange.withOpacity(0.32),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(boundingRect);

    // Dibuixem la superfície a sobre del canvas de l'APK
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
