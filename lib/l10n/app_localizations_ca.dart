// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appTitle => 'Trackio';

  @override
  String get importGpx => 'Importar GPX';

  @override
  String get toolSplit => 'Retallar track';

  @override
  String get toolMerge => 'Unir tracks';

  @override
  String get toolInverse => 'Invertir direcció';

  @override
  String get confirmSplit => 'Tallar aquí';

  @override
  String get processingGpxFile => 'Processant arxiu GPX...';

  @override
  String get selectSplitPoint => 'Seleccionar punt de tall';

  @override
  String get confirmRangeStartPoint => 'Confirmar punt inicial';

  @override
  String get confirmRangeEndPoint => 'Confirmar punt final';

  @override
  String get selectNewRange => 'Seleccionar nou tram';

  @override
  String get confirmTracksMerge => 'Confirmar unió de tracks';
}
