import 'dart:convert';
import 'package:web/web.dart' as web;

class GpxExporter {
  /// 📤 Exportació a la Web (paràmetres unificats amb nom)
  static Future<void> exportTrackGpx({
    required String name,
    required String content,
    required String shareSubject,
  }) async {
    final bytes = utf8.encode(content);
    final base64String = base64.encode(bytes);
    final dataUrl =
        'data:application/gpx+xml;charset=utf-8;base64,$base64String';

    web.HTMLAnchorElement()
      ..href = dataUrl
      ..setAttribute('download', '$name.gpx')
      ..click();
  }

  /// 📥 Descarrega a la Web (A la web descarregar i exportar sol ser el mateix procés)
  static Future<void> downloadTrackGpx({
    required String name,
    required String content,
    required String dialogTitle,
  }) async {
    // Reutilitzem la lògica d'exportar perquè a la web el comportament és idèntic (baixa el fitxer)
    await exportTrackGpx(name: name, content: content, shareSubject: '');
  }
}
