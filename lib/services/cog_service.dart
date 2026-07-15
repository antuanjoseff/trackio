import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:trackio/models/cog_tile.dart';

class CogService {
  static final CogService _instance = CogService._internal();
  factory CogService() => _instance;
  CogService._internal();

  final List<CogTile> _tiles = [];
  final int _maxTiles = 4;

  Future<CogTile> _downloadTile(double lat, double lon) async {
    final uri = Uri.https(
      'cog-tiles-euaeg7eaavbqczgf.spaincentral-01.azurewebsites.net',
      '/api/getTileGrid',
      {'lat': lat.toString(), 'lon': lon.toString()},
    );

    final response = await http.get(uri);

    final bbox = response.headers['x-bbox']!
        .split(',')
        .map(double.parse)
        .toList();

    final width = int.parse(response.headers['x-width']!);
    final height = int.parse(response.headers['x-height']!);

    return CogTile(
      minLon: bbox[0],
      minLat: bbox[1],
      maxLon: bbox[2],
      maxLat: bbox[3],
      width: width,
      height: height,
      data: response.bodyBytes,
    );
  }

  Future<CogTile> _getTileFor(double lat, double lon) async {
    for (final t in _tiles) {
      if (t.contains(lat, lon)) {
        t.lastUsed = DateTime.now();
        return t;
      }
    }

    final newTile = await _downloadTile(lat, lon);
    _tiles.add(newTile);

    if (_tiles.length > _maxTiles) {
      _tiles.sort((a, b) => a.lastUsed.compareTo(b.lastUsed));
      _tiles.removeAt(0);
    }

    return newTile;
  }

  double _interpolate(CogTile tile, double lat, double lon) {
    final x =
        ((lon - tile.minLon) / (tile.maxLon - tile.minLon)) * (tile.width - 1);
    final y =
        ((tile.maxLat - lat) / (tile.maxLat - tile.minLat)) * (tile.height - 1);

    final x1 = x.floor().clamp(0, tile.width - 2);
    final y1 = y.floor().clamp(0, tile.height - 2);
    final x2 = x1 + 1;
    final y2 = y1 + 1;

    double getV(int r, int c) {
      final offset = (r * tile.width + c) * 4;
      return ByteData.sublistView(
        tile.data,
        offset,
        offset + 4,
      ).getFloat32(0, Endian.little);
    }

    final v11 = getV(y1, x1);
    final v21 = getV(y1, x2);
    final v12 = getV(y2, x1);
    final v22 = getV(y2, x2);

    final xFrac = x - x1;
    final yFrac = y - y1;

    final top = v11 + xFrac * (v21 - v11);
    final bottom = v12 + xFrac * (v22 - v12);

    final ele = top + yFrac * (bottom - top);
    return ele > 0 ? ele : 0.0;
  }

  Future<double> getElevation(double lat, double lon) async {
    final tile = await _getTileFor(lat, lon);
    return _interpolate(tile, lat, lon);
  }
}
