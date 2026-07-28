import 'package:flutter/material.dart';

class SelectionPainter extends CustomPainter {
  // 🔒 REPARACIÓ CRÍTICA: Ara reben directament els píxels reals (X) calculats des de la vista
  final double? needleX; // en píxels reals de pantalla
  final double? startX; // en píxels reals de pantalla
  final double? endX; // en píxels reals de pantalla
  final double chartHeight; // alçada total del giny en píxels
  final double maxDistance; // metres totals del track

  final int? snappedIdx;
  final int? startPointsIndex;
  final int? endPointsIndex;
  final List<double> altitudes;
  final double minY;
  final double maxY;

  // 🌟 CONSTANT DE SENDA: El marge inferior que guarda fl_chart per als títols de l'eix X
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

  // 🧠 LÒGICA DE SENDA REPARADA: Clava l'agulla i el cercle blanc exactament sobre el perfil real del track
  void _paintNeedleLineAndDot(Canvas canvas, double x, int index, Color color) {
    if (index < 0 || index >= altitudes.length) return;

    // Ajustem l'alçada útil del gràfic restant el desfasament transparent dels títols
    final double usableChartHeight = chartHeight - bottomReserved;
    final double xAxisY = usableChartHeight; // El terra real de la muntanya

    final double yRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    final double rel = (altitudes[index] - minY) / yRange;
    final double dy = usableChartHeight * (1.0 - rel.clamp(0.0, 1.0));

    // 1. La línia vertical neix al terra real de la muntanya (xAxisY) i puja crystallinity fins a la corba (dy)
    final linePaint = Paint()
      ..color = color
          .withValues(alpha: 0.6) // Translúcid homogeni de seguretat
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(x, xAxisY), Offset(x, dy), linePaint);

    // 2. Dibuixem el cercle interior de color sòlid exactament a sobre de la línia de muntanya
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(x, dy), 5.0, dotPaint);

    // 3. Dibuixem l'anell exterior blanc de Senda per sobre per garantir el contrast estètic
    final dotBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(x, dy), 5.0, dotBorder);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (altitudes.isEmpty) return;

    // 🟢 1. AGULLA ESQUERRA (Verda d'inici de rang fix o arrossegat)
    if (startX != null && startPointsIndex != null) {
      _paintNeedleLineAndDot(canvas, startX!, startPointsIndex!, Colors.green);
    }

    // 🔴 2. AGULLA DRETA (Vermella de final de rang fix o arrossegat)
    if (endX != null && endPointsIndex != null) {
      _paintNeedleLineAndDot(canvas, endX!, endPointsIndex!, Colors.red);
    }

    // 🔵 3. AGULLA CENTRAL (Dit Blau d'exploració mòbil)
    // Es pinta l'última per assegurar que el handle es visualitza sempre al capdamunt per sobre del rang
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
