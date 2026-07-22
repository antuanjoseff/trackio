import 'package:flutter/material.dart';

class TrackioLargeIcon extends StatelessWidget {
  final Widget child;
  final double scale;

  const TrackioLargeIcon({
    super.key,
    required this.child,
    this.scale = 1.35, // Ajusta aquest valor per fer-les més o menys grans
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(scale: scale, child: child);
  }
}
