import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ca'),
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Trackio'**
  String get appTitle;

  /// No description provided for @importGpx.
  ///
  /// In en, this message translates to:
  /// **'Import GPX'**
  String get importGpx;

  /// No description provided for @toolSplit.
  ///
  /// In en, this message translates to:
  /// **'Split track'**
  String get toolSplit;

  /// No description provided for @toolMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge tracks'**
  String get toolMerge;

  /// No description provided for @toolInverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse direction'**
  String get toolInverse;

  /// No description provided for @confirmSplit.
  ///
  /// In en, this message translates to:
  /// **'Split here'**
  String get confirmSplit;

  /// No description provided for @processingGpxFile.
  ///
  /// In en, this message translates to:
  /// **'Processing GPX file...'**
  String get processingGpxFile;

  /// No description provided for @selectSplitPoint.
  ///
  /// In en, this message translates to:
  /// **'Select split point'**
  String get selectSplitPoint;

  /// No description provided for @confirmRangeStartPoint.
  ///
  /// In en, this message translates to:
  /// **'Confirm start point'**
  String get confirmRangeStartPoint;

  /// No description provided for @confirmRangeEndPoint.
  ///
  /// In en, this message translates to:
  /// **'Confirm end point'**
  String get confirmRangeEndPoint;

  /// No description provided for @selectNewRange.
  ///
  /// In en, this message translates to:
  /// **'Select new range'**
  String get selectNewRange;

  /// No description provided for @confirmTracksMerge.
  ///
  /// In en, this message translates to:
  /// **'Confirm track merge'**
  String get confirmTracksMerge;

  /// No description provided for @noTracksLoaded.
  ///
  /// In en, this message translates to:
  /// **'No tracks loaded'**
  String get noTracksLoaded;

  /// No description provided for @exportGpx.
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get exportGpx;

  /// No description provided for @deleteTrack.
  ///
  /// In en, this message translates to:
  /// **'Delete track'**
  String get deleteTrack;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stopMerge.
  ///
  /// In en, this message translates to:
  /// **'Stop merge'**
  String get stopMerge;

  /// No description provided for @selectRange.
  ///
  /// In en, this message translates to:
  /// **'Select range'**
  String get selectRange;

  /// No description provided for @stopRange.
  ///
  /// In en, this message translates to:
  /// **'Stop range'**
  String get stopRange;

  /// No description provided for @hideElevationProfile.
  ///
  /// In en, this message translates to:
  /// **'Hide elevation profile'**
  String get hideElevationProfile;

  /// No description provided for @showElevationProfile.
  ///
  /// In en, this message translates to:
  /// **'Show elevation profile'**
  String get showElevationProfile;

  /// No description provided for @stopWaypoint.
  ///
  /// In en, this message translates to:
  /// **'Stop waypoint'**
  String get stopWaypoint;

  /// No description provided for @addWaypoint.
  ///
  /// In en, this message translates to:
  /// **'Add waypoint'**
  String get addWaypoint;

  /// No description provided for @selectTrackToUseTools.
  ///
  /// In en, this message translates to:
  /// **'Select a track from the list to use the tools.'**
  String get selectTrackToUseTools;

  /// No description provided for @importTracks.
  ///
  /// In en, this message translates to:
  /// **'Import tracks'**
  String get importTracks;

  /// No description provided for @elevationProfile.
  ///
  /// In en, this message translates to:
  /// **'Elevation profile'**
  String get elevationProfile;

  /// No description provided for @chooseColor.
  ///
  /// In en, this message translates to:
  /// **'Choose a color'**
  String get chooseColor;

  /// No description provided for @selectTrackToViewElevationProfile.
  ///
  /// In en, this message translates to:
  /// **'Select a track to view the elevation profile'**
  String get selectTrackToViewElevationProfile;

  /// No description provided for @trackWithoutElevationData.
  ///
  /// In en, this message translates to:
  /// **'This track has no elevation data'**
  String get trackWithoutElevationData;

  /// No description provided for @hideSpeed.
  ///
  /// In en, this message translates to:
  /// **'Hide speed'**
  String get hideSpeed;

  /// No description provided for @showSpeed.
  ///
  /// In en, this message translates to:
  /// **'Show speed'**
  String get showSpeed;

  /// No description provided for @newTrackAddedFromSelectedSegment.
  ///
  /// In en, this message translates to:
  /// **'New track added from selected segment'**
  String get newTrackAddedFromSelectedSegment;

  /// No description provided for @addTrack.
  ///
  /// In en, this message translates to:
  /// **'ADD TRACK'**
  String get addTrack;

  /// No description provided for @segment.
  ///
  /// In en, this message translates to:
  /// **'SEGMENT'**
  String get segment;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'ROUTE'**
  String get route;

  /// No description provided for @waypointAddedToActiveTrack.
  ///
  /// In en, this message translates to:
  /// **'Waypoint added to active track'**
  String get waypointAddedToActiveTrack;

  /// No description provided for @waypointNamePrefix.
  ///
  /// In en, this message translates to:
  /// **'WP'**
  String get waypointNamePrefix;

  /// No description provided for @waypointCommentFromGrid.
  ///
  /// In en, this message translates to:
  /// **'Added from the grid'**
  String get waypointCommentFromGrid;

  /// No description provided for @toolDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw route'**
  String get toolDraw;

  /// No description provided for @selectDrawPoint.
  ///
  /// In en, this message translates to:
  /// **'Fix point on map'**
  String get selectDrawPoint;

  /// No description provided for @confirmDrawSave.
  ///
  /// In en, this message translates to:
  /// **'Confirm and save route'**
  String get confirmDrawSave;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo last point'**
  String get undo;

  /// No description provided for @drawnRouteDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Drawn Route'**
  String get drawnRouteDefaultName;

  /// No description provided for @routeSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Route saved successfully'**
  String get routeSavedSuccess;

  /// No description provided for @visible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get visible;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @shareGpx.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareGpx;

  /// No description provided for @downloadGpx.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadGpx;

  /// No description provided for @saveGpxDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save GPX file'**
  String get saveGpxDialogTitle;

  /// No description provided for @shareGpxSubject.
  ///
  /// In en, this message translates to:
  /// **'Export GPX route'**
  String get shareGpxSubject;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ca', 'en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca': return AppLocalizationsCa();
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
