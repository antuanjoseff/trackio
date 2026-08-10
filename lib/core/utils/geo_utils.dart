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

    final List<double> smoothedElevations = _smoothElevations(
      points
          .where((p) => p.elevation != null)
          .map((p) => p.elevation!)
          .toList(),
    );

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
      }
    }

    if (smoothedElevations.length >= 2) {
      double lastValid = smoothedElevations.first;
      for (int i = 1; i < smoothedElevations.length; i++) {
        final double diff = smoothedElevations[i] - lastValid;
        if (diff.abs() < 3.5) {
          continue;
        }
        if (diff > 0) {
          gain += diff;
        }
        lastValid = smoothedElevations[i];
      }
    }

    return (distance, gain);
  }

  static List<double> _smoothElevations(
    List<double> elevations, {
    int windowSize = 5,
  }) {
    if (elevations.length < 2) {
      return List<double>.from(elevations);
    }

    final List<double> smoothed = <double>[];
    for (int i = 0; i < elevations.length; i++) {
      final int start = i - windowSize + 1;
      final int safeStart = start < 0 ? 0 : start;
      final int end = i + 1;
      double sum = 0.0;
      for (int j = safeStart; j < end; j++) {
        sum += elevations[j];
      }
      smoothed.add(sum / (end - safeStart));
    }

    return smoothed;
  }
}
