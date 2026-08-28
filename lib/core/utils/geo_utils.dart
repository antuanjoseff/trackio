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
    final List<double> validElevations = [];
    final List<double> validDistances = [];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (i > 0) {
        final prev = points[i - 1];
        if (p.latitude != null &&
            p.longitude != null &&
            prev.latitude != null &&
            prev.longitude != null) {
          distance += distanceBetween(
            prev.latitude!,
            prev.longitude!,
            p.latitude!,
            p.longitude!,
          );
        }
      }

      if (p.elevation != null) {
        validElevations.add(p.elevation!);
        validDistances.add(distance);
      }
    }

    double gain = 0.0;
    if (validElevations.length >= 2) {
      final smoothed = _smoothElevations(
        validElevations,
        distances: validDistances,
        windowMeters: 80.0,
      );

      double lastValid = smoothed.first;
      for (int i = 1; i < smoothed.length; i++) {
        final double diff = smoothed[i] - lastValid;
        if (diff.abs() >= 4.0) {
          if (diff > 0) {
            gain += diff;
          }
          lastValid = smoothed[i];
        }
      }
    }

    return (distance, gain);
  }

  static List<double> _smoothElevations(
    List<double> elevations, {
    List<double>? distances,
    double windowMeters = 80.0,
    int windowPoints = 15,
  }) {
    final int n = elevations.length;
    if (n < 2) return List<double>.from(elevations);

    if (distances != null && distances.length == n && windowMeters > 0) {
      final List<double> smoothed = List<double>.filled(n, 0.0);
      final double halfWindow = windowMeters / 2.0;
      int start = 0;
      int end = 0;

      for (int i = 0; i < n; i++) {
        final double d = distances[i];
        while (start < n && distances[start] < d - halfWindow) {
          start++;
        }
        while (end < n && distances[end] <= d + halfWindow) {
          end++;
        }

        final int count = end - start;
        if (count <= 0) {
          smoothed[i] = elevations[i];
        } else {
          double sum = 0.0;
          for (int j = start; j < end; j++) {
            sum += elevations[j];
          }
          smoothed[i] = sum / count;
        }
      }
      return smoothed;
    }

    final List<double> smoothed = List<double>.filled(n, 0.0);
    final int r = (windowPoints < 1 ? 1 : windowPoints) ~/ 2;
    for (int i = 0; i < n; i++) {
      final int start = (i - r) < 0 ? 0 : (i - r);
      final int end = (i + r + 1) > n ? n : (i + r + 1);
      double sum = 0.0;
      int count = 0;
      for (int j = start; j < end; j++) {
        sum += elevations[j];
        count++;
      }
      smoothed[i] = sum / count;
    }

    return smoothed;
  }
}
