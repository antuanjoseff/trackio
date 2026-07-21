import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GpxExporter {
  static Future<void> exportTrackGpx(String name, String content) async {
    final directory = await getTemporaryDirectory();

    final file = File('${directory.path}/$name.gpx');

    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: '$name.gpx'),
    );
  }
}
