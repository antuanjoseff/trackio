import 'package:flutter_test/flutter_test.dart';
import 'package:trackio/core/utils/track_stats_calculator.dart';
import 'package:trackio/models/track_model.dart';

void main() {
  group('TrackStatsCalculator', () {
    test('applies smoothing and threshold to gain/loss', () {
      final points = [
        TrackPointModel(elevation: 100),
        TrackPointModel(elevation: 100),
        TrackPointModel(elevation: 100),
        TrackPointModel(elevation: 100),
        TrackPointModel(elevation: 100),
        TrackPointModel(elevation: 120),
        TrackPointModel(elevation: 20),
      ];

      final stats = TrackStatsCalculator.compute(points);

      expect(stats['gain'], closeTo(4.0, 1e-9));
      expect(stats['loss'], closeTo(16.0, 1e-9));
    });
  });
}
