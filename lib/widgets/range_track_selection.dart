import 'package:flutter/material.dart';

class TrackRangeSelection extends StatelessWidget {
  final Color color;
  final double size;

  const TrackRangeSelection({super.key, required this.color, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final bool isPhone = MediaQuery.sizeOf(context).shortestSide < 600;

    // Espai total del widget ajustat a les proporcions
    final double widgetWidth = size * 2.5;
    final double widgetHeight = size * 1.6;

    // Definim la base exacta on descansen les icones i la línia
    final double lineThickness = size * 0.05;
    final double lineBottomPosition = size * 0.4;
    final double markerSizeFactor = isPhone ? 0.62 : 0.7;
    final double markerInsetFactor = isPhone ? 0.45 : 0.65;
    final double lineInsetFactor = isPhone ? 0.62 : 0.7;

    return SizedBox(
      width: widgetWidth,
      height: widgetHeight,
      child: Stack(
        children: [
          // 1. LÍNIA HORITZONTAL MÉS CURTA
          Positioned(
            left: size * lineInsetFactor,
            right: size * lineInsetFactor,
            bottom: lineBottomPosition,
            child: Container(
              height: lineThickness,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 2. ICONA ESQUERRA (Just a sobre de la línia)
          Positioned(
            left: size * markerInsetFactor,
            bottom:
                lineBottomPosition +
                lineThickness, // Altura exacta sobre el text de la línia
            child: Icon(
              Icons.location_on,
              size: size * markerSizeFactor,
              color: color,
            ),
          ),
          // 3. ICONA DRETA (Just a sobre de la línia)
          Positioned(
            right: size * markerInsetFactor,
            bottom:
                lineBottomPosition +
                lineThickness, // Altura exacta sobre el text de la línia
            child: Icon(
              Icons.location_on,
              size: size * markerSizeFactor,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
