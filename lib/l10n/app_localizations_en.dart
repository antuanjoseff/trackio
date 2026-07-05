// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Trackio';

  @override
  String get importGpx => 'Import GPX';

  @override
  String get toolSplit => 'Split track';

  @override
  String get toolMerge => 'Merge tracks';

  @override
  String get toolInverse => 'Reverse direction';

  @override
  String get confirmSplit => 'Split here';

  @override
  String get processingGpxFile => 'Processing GPX file...';

  @override
  String get selectSplitPoint => 'Select split point';

  @override
  String get confirmRangeStartPoint => 'Confirm start point';

  @override
  String get confirmRangeEndPoint => 'Confirm end point';

  @override
  String get selectNewRange => 'Select new range';

  @override
  String get confirmTracksMerge => 'Confirm track merge';
}
