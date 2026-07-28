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

  void _paintNeedleLineAndDot(Canvas canvas, double x, int index, Color color) {
    if (index < 0 || index >= altitudes.length) return;

    // 🌟 REPARACIÓN GEOMÉTRICA SIMÉTRICA:
    // Sincronizamos exactamente los mismos desfases de píxeles que usa fl_chart
    final double topOffset = 0.0;
    final double bottomOffset = 22.0;

    // L'alçada útil real disminueix restant els dos coixins (superior i inferior)
    final double usableChartHeight =
        chartHeight - bottomReserved - topOffset - bottomOffset;

    // El terra real on mor la gràfica (abans de la franja buida dels tooltips)
    final double xAxisY = chartHeight - bottomReserved - bottomOffset;

    final double yRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    final double rel = (altitudes[index] - minY) / yRange;

    // El punt vertical (dy) ara suma el desplaçament superior de seguretat
    final double dy =
        topOffset + (usableChartHeight * (1.0 - rel.clamp(0.0, 1.0)));

    // 1. La línia vertical neix al terra real de la muntanya (xAxisY) i puja fins a la corba (dy)
    // Deixant la franja inferior buida per als nous rètols
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(x, xAxisY), Offset(x, dy), linePaint);

    // 2. Dibuixem el cercle interior de color exacte a sobre de la corba de nivell
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(x, dy), 5.0, dotPaint);

    // 3. Dibuixem l'anell exterior blanc de contrast
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
