import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/widgets/track_stats_panel.dart';

void main() {
  testWidgets('shows segment stats while a range is being built', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(gpxEditorProvider.notifier);
    final track = TrackModel(
      id: 9,
      points: [
        TrackPointModel(latitude: 41.0, longitude: 2.0),
        TrackPointModel(latitude: 41.01, longitude: 2.01),
        TrackPointModel(latitude: 41.02, longitude: 2.02),
        TrackPointModel(latitude: 41.03, longitude: 2.03),
      ],
    );

    notifier.state = notifier.state.copyWith(
      tracks: [track],
      selectedTrackId: 9,
      activeTool: 'range_map',
      selectionStartIndex: 1,
      selectionEndIndex: null,
      isSelectingRange: false,
      snappedPointIndex: 3,
      snappedPoint: track.points[3],
    );

    final locale = const Locale('en');
    final localizations = await AppLocalizations.delegate.load(locale);

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TrackStatsPanel()),
        ),
      ),
    );

    expect(find.text(localizations.segment), findsOneWidget);
  });
}
