import 'dart:typed_data';

class CogTile {
  final double minLon, minLat, maxLon, maxLat;
  final int width, height;
  Uint8List data;
  DateTime lastUsed;

  CogTile({
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
    required this.width,
    required this.height,
    required this.data,
  }) : lastUsed = DateTime.now();

  bool contains(double lat, double lon) {
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }
}
