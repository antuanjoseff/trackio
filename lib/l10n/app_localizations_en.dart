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

  @override
  String get noTracksLoaded => 'No tracks loaded';

  @override
  String get exportGpx => 'Export GPX';

  @override
  String get deleteTrack => 'Delete track';

  @override
  String get stop => 'Stop';

  @override
  String get stopMerge => 'Stop merge';

  @override
  String get selectRange => 'Select range';

  @override
  String get stopRange => 'Stop range';

  @override
  String get hideElevationProfile => 'Hide elevation profile';

  @override
  String get showElevationProfile => 'Show elevation profile';

  @override
  String get stopWaypoint => 'Stop waypoint';

  @override
  String get addWaypoint => 'Add waypoint';

  @override
  String get selectTrackToUseTools => 'Select a track from the list to use the tools.';

  @override
  String get importTracks => 'Import tracks';

  @override
  String get elevationProfile => 'Elevation profile';

  @override
  String get chooseColor => 'Choose a color';

  @override
  String get selectTrackToViewElevationProfile => 'Select a track to view the elevation profile';

  @override
  String get trackWithoutElevationData => 'This track has no elevation data';

  @override
  String get hideSpeed => 'Hide speed';

  @override
  String get showSpeed => 'Show speed';

  @override
  String get newTrackAddedFromSelectedSegment => 'New track added from selected segment';

  @override
  String get addTrack => 'ADD TRACK';

  @override
  String get segment => 'SEGMENT';

  @override
  String get route => 'ROUTE';

  @override
  String get waypointAddedToActiveTrack => 'Waypoint added to active track';

  @override
  String get waypointNamePrefix => 'WP';

  @override
  String get waypointCommentFromGrid => 'Added from the grid';
}
