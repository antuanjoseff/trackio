import 'package:flutter/material.dart';
import 'package:trackio/core/theme/app_colors.dart';

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

  // 🌟 APLICACIÓ DE LA TEVA SOLUCIÓ: Variable per emmagatzemar el total de punts reals del track
  final int totalTrackPoints;

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
    required this.totalTrackPoints, // 🌟 Afegit com a paràmetre obligatori
  });

  void _paintNeedleLineAndDot(Canvas canvas, double x, int index, Color color) {
    if (altitudes.isEmpty || totalTrackPoints <= 0) return;

    final double topOffset = 0.0;
    final double bottomOffset =
        22.0; // El padding-bottom real de 22px configurat al fl_chart

    final double usableChartHeight =
        chartHeight - bottomReserved - topOffset - bottomOffset;
    final double xAxisY =
        chartHeight - bottomReserved - bottomOffset; // El terra real

    // 🌟 LA CLAU DE SINCRO AMB EL RATOLÍ:
    // El paràmetre 'index' que ens arriba ara ja és l'índex corregit i filtrat de la muntanya.
    // El forcem a encaixar de forma segura dins de la llista d'altituds.
    final int safeChartIndex = index.clamp(0, altitudes.length - 1);
    final double realAltitude = altitudes[safeChartIndex];

    final double yRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    final double rel = (realAltitude - minY) / yRange;

    // Calculem la coordenada vertical 'dy' que intersecta en la carena lila [INDEX]
    final double dy =
        topOffset + (usableChartHeight * (1.0 - rel.clamp(0.0, 1.0)));

    // 1. 🌟 LA LÍNIA VERTICAL: Es pinta EXACTAMENT a la 'x' real del ratolí de pantalla,
    // neix a la base (xAxisY) i puja fins a tocar la línia de la muntanya (dy) [INDEX].
    final linePaint = Paint()
      ..color = color
          .withValues(alpha: 0.6) // Translúcid homogeni de seguretat [INDEX]
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(x, xAxisY), Offset(x, dy), linePaint);

    // 2. 🌟 EL CERCLE BLAU: Es clava a la mateixa 'x' del ratolí, just a la intersecció 'dy' [INDEX]
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(x, dy), 5.0, dotPaint);

    // 3. L'ANELL EXTERIOR BLANC: Enquadrat a la mateixa posició de contrast [INDEX]
    final dotBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(x, dy), 5.0, dotBorder);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (altitudes.isEmpty) return;

    // 🟢 1. AGULLA ESQUERRA (Verda d'inici de rang)
    if (startX != null && startPointsIndex != null) {
      _paintNeedleLineAndDot(
        canvas,
        startX!,
        startPointsIndex!,
        AppColors.starTrekGold,
      );
    }

    // 🔴 2. AGULLA DRETA (Vermella de final de rang)
    if (endX != null && endPointsIndex != null) {
      _paintNeedleLineAndDot(
        canvas,
        endX!,
        endPointsIndex!,
        AppColors.starTrekRed,
      );
    }

    // 🔵 3. AGULLA CENTRAL (Dit Blau d'exploració o Hover del ratolí)
    if (needleX != null && snappedIdx != null) {
      _paintNeedleLineAndDot(
        canvas,
        needleX!,
        snappedIdx!,
        AppColors.starTrekGold,
      );
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
        maxY != oldDelegate.maxY ||
        totalTrackPoints !=
            oldDelegate.totalTrackPoints; // 🌟 Afegit al control de repintat
  }
}
