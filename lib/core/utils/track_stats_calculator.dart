import 'package:trackio/models/track_model.dart';
import 'package:latlong2/latlong.dart' as geo;

/// 🏎️ MOTOR MATEMÁTICO EN MEMORIA PARA LAS MÉTRICAS DEL TRACK O TRAMO
class TrackStatsCalculator {
  static Map<String, dynamic> compute(List<TrackPointModel> points) {
    if (points.isEmpty) return _emptyResult();

    double totalDistance = 0.0;
    double gain = 0.0;
    double loss = 0.0;
    double maxAlt = -double.infinity;
    double minAlt = double.infinity;

    const geo.Distance distanceCalculator = geo.Distance();
    final int len = points.length;
    final List<double> smoothedElevations = _smoothElevations(
      points
          .where((p) => p.elevation != null)
          .map((p) => p.elevation!)
          .toList(),
    );

    // 1. Cálculo de Distancia acumulada, Desniveles y Cotas extremas
    for (int i = 0; i < len; i++) {
      final p = points[i];
      if (p.latitude == null || p.longitude == null) continue;

      // Evaluar cota máxima y mínima
      if (p.elevation != null) {
        if (p.elevation! > maxAlt) maxAlt = p.elevation!;
        if (p.elevation! < minAlt) minAlt = p.elevation!;
      }

      // Comparar con el punto anterior para distancia y desniveles
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
        } else {
          loss += diff.abs();
        }
        lastValid = smoothedElevations[i];
      }
    }

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
