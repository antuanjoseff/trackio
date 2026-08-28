import 'package:trackio/models/track_model.dart';
import 'package:latlong2/latlong.dart' as geo;

/// 🏎️ MOTOR MATEMÁTICO EN MEMORIA PARA LAS MÉTRICAS DEL TRACK O TRAMO
class TrackStatsCalculator {
  static const double elevationWindowMeters = 80.0;
  static const int elevationWindowPoints = 15;
  static const double elevationThreshold = 4.0;

  static Map<String, dynamic> compute(List<TrackPointModel> points) {
    if (points.isEmpty) return _emptyResult();

    double totalDistance = 0.0;
    double maxAlt = -double.infinity;
    double minAlt = double.infinity;

    const geo.Distance distanceCalculator = geo.Distance();
    final int len = points.length;

    final List<double> validElevations = [];
    final List<double> validDistances = [];

    // 1. Cálculo de Distancia acumulada y Cotas extremas
    for (int i = 0; i < len; i++) {
      final p = points[i];
      if (p.latitude == null || p.longitude == null) continue;

      // Comparar con el punto anterior para distancia
      if (i > 0) {
        final prev = points[i - 1];
        if (prev.latitude != null && prev.longitude != null) {
          totalDistance += distanceCalculator.as(
            geo.LengthUnit.Meter,
            geo.LatLng(prev.latitude!, prev.longitude!),
            geo.LatLng(p.latitude!, p.longitude!),
          );
        }
      }

      // Evaluar cota máxima y mínima
      if (p.elevation != null) {
        final ele = p.elevation!;
        if (ele > maxAlt) maxAlt = ele;
        if (ele < minAlt) minAlt = ele;
        validElevations.add(ele);
        validDistances.add(totalDistance);
      }
    }

    final (gain, loss) = _computeGainAndLoss(validElevations, validDistances);

    // Corrección por si el track no tuviera datos de altitud válidos
    if (minAlt == double.infinity) minAlt = 0.0;
    if (maxAlt == -double.infinity) maxAlt = 0.0;

    // 2. Tiempos, Velocidad media y Ritmo medio (Si el GPX incluye timestamps)
    Duration totalTime = Duration.zero;
    double avgSpeed = 0.0;
    double paceMinPerKm = 0.0;

    // Buscamos de forma segura el primer y último punto que tengan hora registrada
    final firstWithTime = points.firstWhere(
      (p) => p.timestamp != null,
      orElse: () => TrackPointModel(),
    );
    final lastWithTime = points.lastWhere(
      (p) => p.timestamp != null,
      orElse: () => TrackPointModel(),
    );

    if (firstWithTime.timestamp != null && lastWithTime.timestamp != null) {
      totalTime = lastWithTime.timestamp!.difference(firstWithTime.timestamp!);

      if (totalTime.inSeconds > 0 && totalDistance > 0) {
        // Velocidad media en km/h
        avgSpeed = (totalDistance / 1000) / (totalTime.inSeconds / 3600);
        // Ritmo medio en minutos por kilómetro
        paceMinPerKm = (totalTime.inSeconds / 60) / (totalDistance / 1000);
      }
    }

    return {
      'distance': totalDistance,
      'time': totalTime,
      'speed': avgSpeed,
      'pace': paceMinPerKm,
      'gain': gain,
      'loss': loss,
      'maxAlt': maxAlt,
      'minAlt': minAlt,
    };
  }

  static (double gain, double loss) _computeGainAndLoss(
    List<double> elevations,
    List<double> distances, {
    double windowMeters = elevationWindowMeters,
    double threshold = elevationThreshold,
  }) {
    if (elevations.length < 2) {
      return (0.0, 0.0);
    }

    final smoothed = _smoothElevations(
      elevations,
      distances: distances,
      windowMeters: windowMeters,
    );

    double gain = 0.0;
    double loss = 0.0;
    double lastValid = smoothed.first;

    for (int i = 1; i < smoothed.length; i++) {
      final double diff = smoothed[i] - lastValid;
      if (diff.abs() >= threshold) {
        if (diff > 0) {
          gain += diff;
        } else {
          loss += diff.abs();
        }
        lastValid = smoothed[i];
      }
    }

    return (gain, loss);
  }

  static List<double> _smoothElevations(
    List<double> elevations, {
    List<double>? distances,
    double windowMeters = elevationWindowMeters,
    int windowPoints = elevationWindowPoints,
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

    // Fallback por ventana de puntos simétrica
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

  static Map<String, dynamic> _emptyResult() {
    return {
      'distance': 0.0,
      'time': Duration.zero,
      'speed': 0.0,
      'pace': 0.0,
      'gain': 0.0,
      'loss': 0.0,
      'maxAlt': 0.0,
      'minAlt': 0.0,
    };
  }
}
