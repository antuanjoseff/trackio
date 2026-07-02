import 'dart:math'; // Afegit per a la generació de colors aleatoris real
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
    final trkPoints = document.findAllElements('trkpt');
    for (final element in trkPoints) {
      final latAttr = element.getAttribute('lat');
      final lonAttr = element.getAttribute('lon');

      if (latAttr != null && lonAttr != null) {
        final double? lat = double.tryParse(latAttr);
        final double? lon = double.tryParse(lonAttr);

        // Si les coordenades base no són vàlides, saltem el punt
        if (lat == null || lon == null) continue;

        // Busquem l'etiqueta opcional d'altitud <ele> amb tryParse segur
        final eleElement = element.findElements('ele').firstOrNull;
        final double? elevation = eleElement != null
            ? double.tryParse(eleElement.innerText)
            : null;

        // Busquem l'etiqueta opcional de temps <time>
        final timeElement = element.findElements('time').firstOrNull;
        final DateTime? timestamp = timeElement != null
            ? DateTime.tryParse(timeElement.innerText)
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
    final wptElements = document.findAllElements('wpt');
    for (final element in wptElements) {
      final latAttr = element.getAttribute('lat');
      final lonAttr = element.getAttribute('lon');

      if (latAttr != null && lonAttr != null) {
        final double? lat = double.tryParse(latAttr);
        final double? lon = double.tryParse(lonAttr);

        if (lat == null || lon == null) continue;

        // Nom del waypoint
        final nameElement = element.findElements('name').firstOrNull;
        final String? name = nameElement?.innerText;

        // Comentari o descripció
        final descElement =
            element.findElements('desc').firstOrNull ??
            element.findElements('cmt').firstOrNull;
        final String? comment = descElement?.innerText;

        // Altitud opcional del waypoint
        final eleElement = element.findElements('ele').firstOrNull;
        final double? elevation = eleElement != null
            ? double.tryParse(eleElement.innerText)
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
    // Busquem el nom específic de la ruta (<trk> -> <name>) per evitar duplicats amb fites
    final trkNameElement = document
        .findAllElements('trk')
        .firstOrNull
        ?.findElements('name')
        .firstOrNull;

    // Si no existeix, busquem un <name> global que estigui directament sota l'arrel <gpx>
    final gpxNameElement =
        trkNameElement ?? document.rootElement.findElements('name').firstOrNull;

    final String trackName =
        (gpxNameElement != null && gpxNameElement.innerText.trim().isNotEmpty)
        ? gpxNameElement.innerText.trim()
        : fileName.replaceAll('.gpx', '');

    return TrackModel(
      name: trackName,
      isVisible: true,
      hexColor: _generateRandomColor(),
      points: routePoints,
      waypoints: trackWaypoints,
    );
  }

  /// Utilitat interna millorada amb Random per evitar colors idèntics en execucions en paral·lel
  static String _generateRandomColor() {
    final colors = [
      '#007AFF', // Blau
      '#34C759', // Verd
      '#FF9500', // Taronja
      '#FF3B30', // Vermell
      '#AF52DE', // Lila
      '#5AC8FA', // Cian
    ];
    final random = Random();
    return colors[random.nextInt(colors.length)];
  }
}
