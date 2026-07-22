import 'package:flutter/material.dart';

class TrackRangeSelection extends StatelessWidget {
  final Color color;
  final double size;

  const TrackRangeSelection({super.key, required this.color, this.size = 18});

  @override
  Widget build(BuildContext context) {
    // Espai total del widget ajustat a les proporcions
    final double widgetWidth = size * 2.5;
    final double widgetHeight = size * 1.6;

    // Definim la base exacta on descansen les icones i la línia
    final double lineThickness = size * 0.15;
    final double lineBottomPosition = size * 0.2;

    return SizedBox(
      width: widgetWidth,
      height: widgetHeight,
      child: Stack(
        children: [
          // 1. LÍNIA HORITZONTAL MÉS CURTA
          Positioned(
            left: size * 0.7, // Molt més curta per l'esquerra
            right: size * 0.7, // Molt més curta per la dreta
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
            left: size * 0.1,
            bottom:
                lineBottomPosition +
                lineThickness, // Altura exacta sobre el text de la línia
            child: Icon(Icons.location_on, size: size, color: color),
          ),
          // 3. ICONA DRETA (Just a sobre de la línia)
          Positioned(
            right: size * 0.1,
            bottom:
                lineBottomPosition +
                lineThickness, // Altura exacta sobre el text de la línia
            child: Icon(Icons.location_on, size: size, color: color),
          ),
        ],
      ),
    );
  }
}
