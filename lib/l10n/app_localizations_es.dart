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
}
