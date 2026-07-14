// track_elevation_service.dart
import 'dart:async';
import 'cog_service.dart';

class TrackElevationService {
  Timer? _timer;
  (double lat, double lon)? _pending;

  void requestPoint({
    required double lat,
    required double lon,
    required void Function(double lat, double lon, double ele) onResult,
  }) {
    _pending = (lat, lon);

    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 40), () async {
      final p = _pending;
      if (p == null) return;

      final ele = await CogService().getElevation(p.$1, p.$2);
      onResult(p.$1, p.$2, ele);
    });
  }
}
