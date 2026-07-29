import 'package:flutter/material.dart';

class SelectionPainter extends CustomPainter {
  final double? needleX; // en píxels reals de pantalla
  final double? startX; // en píxels reals de pantalla
  final double? endX; // en píxels reals de pantalla
  final double chartHeight; // alçada total del giny en píxels
  final double maxDistance; // metres totals del track

  final int? snappedIdx;
  final int? startPointsIndex;
  final int? endPointsIndex;
  final List<double> altitudes; // La llista d'altituds comprimida del gràfic
  final double minY;
  final double maxY;

  static const double bottomReserved = 0.0;

  SelectionPainter({
    required this.needleX,
    required this.startX,
    required this.endX,
    required this.chartHeight,
    required this.maxDistance,
    required this.snappedIdx,
    required this.startPointsIndex,
    required this.endPointsIndex,
    required this.altitudes,
    required this.minY,
    required this.maxY,
  });

  void _paintNeedleLineAndDot(Canvas canvas, double x, int index, Color color) {
    if (altitudes.isEmpty) return;

    final double topOffset = 0.0;
    final double bottomOffset =
        22.0; // El padding-bottom real de 22px configurat al fl_chart

    final double usableChartHeight =
        chartHeight - bottomReserved - topOffset - bottomOffset;
    final double xAxisY = chartHeight - bottomReserved - bottomOffset;

    // 🏆 LA FÓRMULA DE SINCRO GEOMÈTRICA COMPLETA PER A LA WEB:
    // El fl_chart utilitza de forma interna un padding-left de 12.0 i un padding-right de 24.0.
    // L'amplada real útil de la muntanya lila neix al píxel 12 i mor exactament a (width - 24).
    const double paddingLeft = 12.0;
    const double paddingRight = 24.0;
    final double chartWidth = _currentWidth - paddingLeft - paddingRight;

    // Calculem la posició horitzontal (X) del píxel actual de l'agulla dins de la zona útil de dibuix
    final double adjustedX = (x - paddingLeft).clamp(
      0.0,
      chartWidth > 0 ? chartWidth : 1.0,
    );

    // Trobem el percentatge real geomètric (de 0.0 a 1.0) on està caient la línia vertical a la Web
    final double percent = chartWidth > 0 ? (adjustedX / chartWidth) : 0.0;

    // Mapegem aquest percentatge de píxels directament sobre la llista d'altituds que utilitza el gràfic.
    // Això garanteix sincronització visual mil·limètrica: el cercle llegirà el mateix node Y del fl_chart.
    final int safeChartIndex = (percent * (altitudes.length - 1)).round().clamp(
      0,
      altitudes.length - 1,
    );
    final double realAltitude = altitudes[safeChartIndex];

    final double yRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    final double rel = (realAltitude - minY) / yRange;

    // Calculem el punt dy vertical invertit de Flutter (0 a dalt, usableChartHeight a baix)
    final double dy =
        topOffset + (usableChartHeight * (1.0 - rel.clamp(0.0, 1.0)));

    // 1. La línia vertical neix al terra real de la quadrícula (xAxisY) i puja fins a tocar el relleu (dy)
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(x, xAxisY), Offset(x, dy), linePaint);

    // 2. Cercle interior del color de l'agulla (verd, vermell o blau) clavat exactament a la carena lila
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(x, dy), 5.0, dotPaint);

    // 3. Anell exterior blanc pur per donar un contrast excel·lent sobre la carena
    final dotBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(x, dy), 5.0, dotBorder);
  }

  double _currentWidth = 500.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (altitudes.isEmpty) return;
    _currentWidth =
        size.width; // Capturem l'amplada real en viu del frame del navegador

    // 🟢 1. AGULLA ESQUERRA (Verda d'inici de rang)
    if (startX != null && startPointsIndex != null) {
      _paintNeedleLineAndDot(canvas, startX!, startPointsIndex!, Colors.green);
    }

    // 🔴 2. AGULLA DRETA (Vermella de final de rang)
    if (endX != null && endPointsIndex != null) {
      _paintNeedleLineAndDot(canvas, endX!, endPointsIndex!, Colors.red);
    }

    // 🔵 3. AGULLA CENTRAL (Dit Blau d'exploració o Hover del ratolí)
    if (needleX != null && snappedIdx != null) {
      _paintNeedleLineAndDot(canvas, needleX!, snappedIdx!, Colors.blue);
    }
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return needleX != oldDelegate.needleX ||
        startX != oldDelegate.startX ||
        endX != oldDelegate.endX ||
        snappedIdx != oldDelegate.snappedIdx ||
        startPointsIndex != oldDelegate.startPointsIndex ||
        endPointsIndex != oldDelegate.endPointsIndex ||
        maxDistance != oldDelegate.maxDistance ||
        chartHeight != oldDelegate.chartHeight ||
        minY != oldDelegate.minY ||
        maxY != oldDelegate.maxY;
  }
}
