import 'package:flutter/material.dart';

class TrackioIcons {
  static Widget reverseDirection({required Color color, double size = 16}) {
    return Icon(Icons.sync_alt_rounded, color: color, size: size);
  }

  static Widget cutGpx({required Color color, double size = 16}) {
    return Icon(Icons.content_cut_rounded, color: color, size: size * 0.75);
  }

  static Widget joinGpx({required Color color, double size = 18}) {
    return Icon(Icons.add_link_rounded, color: color, size: size);
  }

  static Widget selectAndExtract({required Color color, double size = 18}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.check_box_outline_blank_rounded,
          color: color.withAlpha(102),
          size: size,
        ),
        Icon(Icons.insights_rounded, color: color, size: size * 0.75),
      ],
    );
  }

  static Widget addWaypoint({required Color color, double size = 18}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.location_on_outlined,
          color: color,
          size: size,
        ), // 🌟 REPARAT: Ara és una coma, no un punt i coma
        Positioned(
          // 🌟 REPARAT: S'ha afegit el parèntesi obert que faltava
          top: size * 0.15,
          child: Icon(Icons.add, color: color, size: size * 0.45),
        ),
      ],
    );
  }
}
