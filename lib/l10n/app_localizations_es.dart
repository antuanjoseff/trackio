// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Trackio';

  @override
  String get importGpx => 'Importar GPX';

  @override
  String get toolSplit => 'Recortar track';

  @override
  String get toolMerge => 'Unir tracks';

  @override
  String get toolInverse => 'Invertir dirección';

  @override
  String get confirmSplit => 'Cortar aquí';

  @override
  String get processingGpxFile => 'Procesando archivo GPX...';

  @override
  String get selectSplitPoint => 'Seleccionar punto de corte';

  @override
  String get confirmRangeStartPoint => 'Confirmar punto inicial';

  @override
  String get confirmRangeEndPoint => 'Confirmar punto final';

  @override
  String get selectNewRange => 'Seleccionar nuevo tramo';

  @override
  String get confirmTracksMerge => 'Confirmar unión de tracks';

  @override
  String get noTracksLoaded => 'No hay tracks cargados';

  @override
  String get exportGpx => 'Exportar GPX';

  @override
  String get deleteTrack => 'Eliminar track';

  @override
  String get stop => 'Detener';

  @override
  String get stopMerge => 'Detener unión';

  @override
  String get selectRange => 'Seleccionar tramo';

  @override
  String get stopRange => 'Detener tramo';

  @override
  String get hideElevationProfile => 'Ocultar perfil de altitud';

  @override
  String get showElevationProfile => 'Mostrar perfil de altitud';

  @override
  String get stopWaypoint => 'Detener waypoint';

  @override
  String get addWaypoint => 'Añadir waypoint';

  @override
  String get selectTrackToUseTools => 'Selecciona un track de la lista para usar las herramientas.';

  @override
  String get importTracks => 'Importar tracks';

  @override
  String get elevationProfile => 'Perfil de altitud';

  @override
  String get chooseColor => 'Elige un color';

  @override
  String get selectTrackToViewElevationProfile => 'Selecciona un track para ver el perfil de altitud';

  @override
  String get trackWithoutElevationData => 'Este track no contiene datos de altitud';

  @override
  String get hideSpeed => 'Ocultar velocidad';

  @override
  String get showSpeed => 'Mostrar velocidad';

  @override
  String get newTrackAddedFromSelectedSegment => 'Nuevo track añadido correctamente del tramo seleccionado';

  @override
  String get addTrack => 'AÑADIR TRACK';

  @override
  String get segment => 'TRAMO';

  @override
  String get route => 'RUTA';

  @override
  String get waypointAddedToActiveTrack => 'Waypoint añadido correctamente al track activo';

  @override
  String get waypointNamePrefix => 'WP';

  @override
  String get waypointCommentFromGrid => 'Añadido desde la retícula';

  @override
  String get toolDraw => 'Dibujar ruta';

  @override
  String get toolEditGeometry => 'Editar geometría';

  @override
  String get addNode => 'Añadir nodo';

  @override
  String get deleteNode => 'Borrar nodo';

  @override
  String get moveNode => 'Mover nodo';

  @override
  String get selectMoveNode => 'Seleccionar nodo a mover';

  @override
  String get confirmMoveNode => 'Fijar nueva posición';

  @override
  String get confirmAddNode => 'Añadir nodo aquí';

  @override
  String get undoGeometryEdit => 'Deshacer cambio';

  @override
  String get selectDrawPoint => 'Fijar punto en el mapa';

  @override
  String get confirmDrawSave => 'Confirmar y guardar ruta';

  @override
  String get cancel => 'Cancelar';

  @override
  String get undo => 'Deshacer último punto';

  @override
  String get drawnRouteDefaultName => 'Ruta Dibujada';

  @override
  String get routeSavedSuccess => 'Ruta guardada con éxito';

  @override
  String get visible => 'Visible';

  @override
  String get hidden => 'Oculto';

  @override
  String get color => 'Color';

  @override
  String get shareGpx => 'Compartir';

  @override
  String get downloadGpx => 'Descargar';

  @override
  String get saveGpxDialogTitle => 'Guardar archivo GPX';

  @override
  String get shareGpxSubject => 'Exportar ruta GPX';

  @override
  String get pressBackAgainToExit => 'Pulsa atrás otra vez para salir';

  @override
  String get waypointInfoElevation => 'Altura';

  @override
  String get waypointInfoElapsedTime => 'Tiempo acumulado';

  @override
  String get waypointInfoDistanceFromStart => 'Distancia desde el inicio';

  @override
  String get editWaypointName => 'Editar nombre';

  @override
  String get deleteWaypoint => 'Eliminar waypoint';

  @override
  String get confirmDeleteWaypointTitle => 'Eliminar waypoint';

  @override
  String get confirmDeleteWaypointMessage => '¿Seguro que quieres eliminar este waypoint?';

  @override
  String get more => 'más';

  @override
  String get less => 'menos';

  @override
  String get editTimestamps => 'Editar timestamps';

  @override
  String get nodeCount => 'Número de nodos';

  @override
  String get properties => 'Propiedades';

  @override
  String get firstTimestamp => 'Primer timestamp';

  @override
  String get lastTimestamp => 'Último timestamp';

  @override
  String get apply => 'Aplicar';

  @override
  String get noTimestamps => 'Este track no contiene timestamps';

  @override
  String get renameTrack => 'Cambiar nombre';

  @override
  String get trackName => 'Nombre del track';

  @override
  String get save => 'Guardar';

  @override
  String get resampleMode => 'Modalidad';

  @override
  String get resampleByTime => 'Por tiempo';

  @override
  String get resampleByDistance => 'Por distancia';

  @override
  String get secondsAbbr => 's';

  @override
  String get metersAbbr => 'm';

  @override
  String resultingNodes(int count) {
    return 'Nodos resultantes: $count';
  }

  @override
  String get invalidInterval => 'Introduce un valor válido';

  @override
  String get trackNeedsTimestamps => 'El track no tiene timestamps';

  @override
  String get trackNeedsPoints => 'El track necesita al menos 2 puntos';

  @override
  String get totalDistance => 'Distancia total';

  @override
  String get nodesCount => 'Número de nodos';

  @override
  String get metersPerNode => 'Media metros por nodo';

  @override
  String get trackDuration => 'Duración del track';

  @override
  String get noData => '—';
}
