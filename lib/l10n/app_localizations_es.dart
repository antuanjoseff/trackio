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
}
