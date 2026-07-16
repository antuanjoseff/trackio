import 'dart:convert';
import 'package:web/web.dart' as web;

class GpxExporter {
  static void exportTrackGpx(String name, String content) {
    final bytes = utf8.encode(content);
    final base64String = base64.encode(bytes);
    final dataUrl =
        'data:application/gpx+xml;charset=utf-8;base64,$base64String';

    web.HTMLAnchorElement()
      ..href = dataUrl
      ..setAttribute('download', '$name.gpx')
      ..click();
  }
}
