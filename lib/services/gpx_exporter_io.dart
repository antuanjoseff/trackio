import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class GpxExporter {
  /// 📤 Comparteix el fitxer GPX amb la nova API unificada de SharePlus
  static Future<void> exportTrackGpx({
    required String name,
    required String content,
    required String shareSubject, // 👈 Text traduït per a l'assumpte
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name.gpx');
    await file.writeAsString(content);

    // 🏆 Nova API moderna: SharePlus.instance.share passant ShareParams
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: shareSubject),
    );
  }

  /// 📥 Descarrega el fitxer a la carpeta demanant el títol del diàleg traduït
  static Future<void> downloadTrackGpx({
    required String name,
    required String content,
    required String dialogTitle, // 👈 Text traduït per al diàleg
  }) async {
    try {
      final Uint8List fileBytes = Uint8List.fromList(utf8.encode(content));

      // FilePicker modern (versió 11+) ja utilitza mètode estàtic sense .platform
      String? outputFile = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: '$name.gpx',
        type: FileType.any,
        bytes: fileBytes,
      );

      if (outputFile == null) return;

      print("Fitxer guardat correctament a: $outputFile");
    } catch (e) {
      print("Error desant el fitxer localment: $e");
    }
  }
}
