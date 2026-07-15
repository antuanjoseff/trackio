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
}
