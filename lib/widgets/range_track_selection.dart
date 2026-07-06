import 'package:flutter/material.dart';

Widget TrackRangeSelection({required Color color, double size = 18}) {
  return SizedBox(
    width: size * 2,
    height: size * 2,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: size * 0.3,
          child: Container(
            height: size * 0.2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          left: -1,
          bottom: size * 0.4,
          child: Icon(Icons.location_on, size: size, color: color),
        ),
        Positioned(
          right: -1,
          bottom: size * 0.4,
          child: Icon(Icons.location_on, size: size, color: color),
        ),
      ],
    ),
  );
}
