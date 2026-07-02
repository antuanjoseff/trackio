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
}
