import 'package:trackio/models/track_model.dart';
import 'package:xml/xml.dart';

class GpxParser {
  /// Parseja el contingut d'un fitxer GPX en text a un objecte 'TrackModel' d'Isar.
  /// Suporta la línia de ruta (<trkpt>) i els punts d'interès/fites (<wpt>).
  static TrackModel parse(String gpxString, String fileName) {
    // 1. Carreguem el document XML de forma estructurada
    final document = XmlDocument.parse(gpxString);

    final List<TrackPointModel> routePoints = [];
    final List<WaypointModel> trackWaypoints = [];

    // 2. EXTRACCIÓ DE LA LÍNIA DEL TRACK (<trkpt>)
    // Busquem tots els elements de punt de track dins del fitxer
    final trkPoints = document.findAllElements('trkpt');
    for (final element in trkPoints) {
      final latAttr = element.getAttribute('lat');
      final lonAttr = element.getAttribute('lon');

      if (latAttr != null && lonAttr != null) {
        final double lat = double.parse(latAttr);
        final double lon = double.parse(lonAttr);

        // Busquem l'etiqueta opcional d'altitud <ele>
        final eleElement = element.findElements('ele').firstOrNull;
        final double? elevation = eleElement != null
            ? double.parse(eleElement.innerText)
            : null;

        // Busquem l'etiqueta opcional de temps <time>
        final timeElement = element.findElements('time').firstOrNull;
        final DateTime? timestamp = timeElement != null
            ? DateTime.parse(timeElement.innerText)
            : null;

        routePoints.add(
          TrackPointModel(
            latitude: lat,
            longitude: lon,
            elevation: elevation,
            timestamp: timestamp,
          ),
        );
      }
    }

    // 3. EXTRACCIÓ DE FITES I WAYPOINTS (<wpt>)
    // Busquem punts d'interès independents que acompanyin el track
    final wptElements = document.findAllElements('wpt');
    for (final element in wptElements) {
      final latAttr = element.getAttribute('lat');
      final lonAttr = element.getAttribute('lon');

      if (latAttr != null && lonAttr != null) {
        final double lat = double.parse(latAttr);
        final double lon = double.parse(lonAttr);

        // Nom del waypoint (ex: <name>Font del Grill</name>)
        final nameElement = element.findElements('name').firstOrNull;
        final String? name = nameElement?.innerText;

        // Comentari o descripció (ex: <desc>Aigua potable</desc>)
        final descElement =
            element.findElements('desc').firstOrNull ??
            element.findElements('cmt').firstOrNull;
        final String? comment = descElement?.innerText;

        // Altitud opcional del waypoint
        final eleElement = element.findElements('ele').firstOrNull;
        final double? elevation = eleElement != null
            ? double.parse(eleElement.innerText)
            : null;

        trackWaypoints.add(
          WaypointModel(
            latitude: lat,
            longitude: lon,
            elevation: elevation,
            name: name,
            comment: comment,
          ),
        );
      }
    }

    // 4. RETORNEM EL TRACK FORMATAT COM A CAPA INDEPENDENT
    // Si el fitxer GPX conté un nom intern (<name>), el fem servir; si no, usem el nom del fitxer
    final gpxNameElement = document.findAllElements('name').firstOrNull;
    final String trackName =
        (gpxNameElement != null && gpxNameElement.innerText.trim().isNotEmpty)
        ? gpxNameElement.innerText.trim()
        : fileName.replaceAll('.gpx', '');

    return TrackModel(
      name: trackName,
      isVisible: true,
      hexColor:
          _generateRandomColor(), // Li assignem un color automàtic per distingir-lo
      points: routePoints,
      waypoints: trackWaypoints,
    );
  }

  /// Utilitat interna per assignar colors diferents a cada track en importar-los en massa
  static String _generateRandomColor() {
    final colors = [
      '#007AFF', // Blau
      '#34C759', // Verd
      '#FF9500', // Taronja
      '#FF3B30', // Vermell
      '#AF52DE', // LILA
      '#5AC8FA', // Cian
    ];
    return colors[DateTime.now().microsecondsSinceEpoch % colors.length];
  }
}
