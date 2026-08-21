import 'package:flutter_test/flutter_test.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';

void main() {
  TrackPointModel pt(double lat, double lon, double ele, DateTime ts) =>
      TrackPointModel(
        latitude: lat,
        longitude: lon,
        elevation: ele,
        timestamp: ts,
      );

  test('resample per distància conserva recorregut i interpola', () {
    final t0 = DateTime(2024, 1, 1, 10);
    final track = TrackModel(
      id: 1,
      name: 't',
      points: [
        pt(0, 0, 100, t0),
        pt(0, 0.001, 120, t0.add(const Duration(seconds: 60))),
        pt(0, 0.002, 140, t0.add(const Duration(seconds: 120))),
      ],
    );

    final notifier = GpxEditor();
    notifier.debugSetTracks([track]);

    // Interval petit → més nodes
    final err = notifier.resampleTrackPoints(1, 50, byTime: false);
    expect(err, isNull);
    final pts = notifier.state.tracks.first.points;
    expect(pts.length, greaterThan(3));
    // Extrems conservats
    expect(pts.first.latitude, 0);
    expect(pts.last.latitude, 0);
    expect(pts.last.longitude, 0.002);
    // Elevacions dins del rang interpolat
    for (final p in pts) {
      expect(p.elevation, inInclusiveRange(100, 140));
    }
  });

  test('resample per temps distribueix timestamps uniformement', () {
    final t0 = DateTime(2024, 1, 1, 10);
    final track = TrackModel(
      id: 2,
      name: 't',
      points: [
        pt(0, 0, 100, t0),
        pt(0, 0.001, 120, t0.add(const Duration(seconds: 100))),
        pt(0, 0.002, 140, t0.add(const Duration(seconds: 200))),
      ],
    );

    final notifier = GpxEditor();
    notifier.debugSetTracks([track]);

    final err = notifier.resampleTrackPoints(2, 10, byTime: true); // cada 10 s
    expect(err, isNull);
    final pts = notifier.state.tracks.first.points;
    // 200 s / 10 s = 20 intervals + extrems ≈ 21
    expect(pts.length, greaterThanOrEqualTo(20));
    // Separació uniforme de 10 s entre nodes consecutius (excepte el darrer tram)
    final d = pts[1].timestamp!.difference(pts[0].timestamp!).inSeconds;
    expect(d, 10);
  });

  test('resample per temps sense timestamps retorna error', () {
    final track = TrackModel(
      id: 3,
      name: 't',
      points: [
        TrackPointModel(latitude: 0, longitude: 0),
        TrackPointModel(latitude: 0, longitude: 0.001),
      ],
    );

    final notifier = GpxEditor();
    notifier.debugSetTracks([track]);

    expect(notifier.resampleTrackPoints(3, 10, byTime: true), 'no-timestamps');
    expect(notifier.resampleTrackPoints(3, 50, byTime: false), isNull);
  });
}
