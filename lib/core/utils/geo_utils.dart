import 'dart:math' as math;
import 'package:trackio/models/track_model.dart';

class GeoCalculations {
  /// 📐 Calcula la distància de Haversine entre dues coordenades en metres
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000; // Radi de la Terra en metres
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180;

  /// 📊 Retorna la distància total (metres) i el desnivell positiu (metres) d'un llistat de punts
  static (double totalDistance, double positiveElevation) getStats(
    List<TrackPointModel> points,
  ) {
    if (points.length < 2) return (0.0, 0.0);

    double distance = 0.0;
    double gain = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      if (p1.latitude != null &&
          p1.longitude != null &&
          p2.latitude != null &&
          p2.longitude != null) {
        distance += distanceBetween(
          p1.latitude!,
          p1.longitude!,
          p2.latitude!,
          p2.longitude!,
        );

        if (p1.elevation != null && p2.elevation != null) {
          final double diff = p2.elevation! - p1.elevation!;
          if (diff > 0) gain += diff; // Només sumem els trams de pujada
        }
      }
    }
    return (distance, gain);
  }
}
