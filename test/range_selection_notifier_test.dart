import 'package:flutter_test/flutter_test.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';

void main() {
  group('GpxEditor range selection', () {
    test('dragging a map handle updates the chart range indexes', () {
      final notifier = GpxEditor();
      final track = TrackModel(
        id: 7,
        points: [
          TrackPointModel(latitude: 41.0, longitude: 2.0),
          TrackPointModel(latitude: 41.01, longitude: 2.01),
          TrackPointModel(latitude: 41.02, longitude: 2.02),
          TrackPointModel(latitude: 41.03, longitude: 2.03),
        ],
      );

      notifier.state = notifier.state.copyWith(
        tracks: [track],
        selectedTrackId: 7,
        activeTool: 'range_map',
        selectionStartIndex: 1,
        selectionEndIndex: 3,
        chartRangeStartIndex: 1,
        chartRangeEndIndex: 3,
        isSelectingRange: false,
      );

      notifier.updateRangeSelectionHandleFromMap(
        41.0,
        2.0,
        15.0,
        isStartHandle: true,
      );

      final state = notifier.state;
      expect(state.selectionStartIndex, 0);
      expect(state.chartRangeStartIndex, 0);
      expect(state.selectionEndIndex, 3);
      expect(state.chartRangeEndIndex, 3);
    });

    test('a new map click resets a fixed range and starts a new selection', () {
      final notifier = GpxEditor();
      final track = TrackModel(
        id: 8,
        points: [
          TrackPointModel(latitude: 41.0, longitude: 2.0),
          TrackPointModel(latitude: 41.01, longitude: 2.01),
          TrackPointModel(latitude: 41.02, longitude: 2.02),
          TrackPointModel(latitude: 41.03, longitude: 2.03),
        ],
      );

      notifier.state = notifier.state.copyWith(
        tracks: [track],
        selectedTrackId: 8,
        activeTool: 'range_map',
        selectionStartIndex: 1,
        selectionEndIndex: 3,
        chartRangeStartIndex: 1,
        chartRangeEndIndex: 3,
        isSelectingRange: false,
      );

      notifier.handleRangeMapSelectionTap(41.02, 2.02, 15.0);

      final state = notifier.state;
      expect(state.selectionStartIndex, 2);
      expect(state.selectionEndIndex, null);
      expect(state.chartRangeStartIndex, 2);
      expect(state.chartRangeEndIndex, null);
      expect(state.isSelectingRange, true);
    });

    test('live map reticle updates both map and chart range indexes', () {
      final notifier = GpxEditor();
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
        selectionStartIndex: null,
        selectionEndIndex: null,
        chartRangeStartIndex: null,
        chartRangeEndIndex: null,
        isSelectingRange: true,
      );

      notifier.updateRangeSelectionLiveFromReticle(41.02, 2.02, 15.0);

      final state = notifier.state;
      expect(state.selectionStartIndex, 2);
      expect(state.selectionEndIndex, null);
      expect(state.chartRangeStartIndex, 2);
      expect(state.chartRangeEndIndex, null);
    });

    test('dragging start handle past end clamps start and keeps end fixed', () {
      final notifier = GpxEditor();
      final track = TrackModel(
        id: 10,
        points: [
          TrackPointModel(latitude: 41.0, longitude: 2.0),
          TrackPointModel(latitude: 41.01, longitude: 2.01),
          TrackPointModel(latitude: 41.02, longitude: 2.02),
          TrackPointModel(latitude: 41.03, longitude: 2.03),
        ],
      );

      notifier.state = notifier.state.copyWith(
        tracks: [track],
        selectedTrackId: 10,
        activeTool: 'range_map',
        selectionStartIndex: 1,
        selectionEndIndex: 2,
        chartRangeStartIndex: 1,
        chartRangeEndIndex: 2,
        isSelectingRange: false,
      );

      // Arrossegar el START més enllà de l'END no ha de moure l'END.
      notifier.updateRangeSelectionHandleFromMap(
        41.03,
        2.03,
        15.0,
        isStartHandle: true,
      );

      final state = notifier.state;
      expect(state.selectionStartIndex, 2);
      expect(state.chartRangeStartIndex, 2);
      expect(state.selectionEndIndex, 2);
      expect(state.chartRangeEndIndex, 2);
    });

    test(
      'dragging end handle before start clamps end and keeps start fixed',
      () {
        final notifier = GpxEditor();
        final track = TrackModel(
          id: 11,
          points: [
            TrackPointModel(latitude: 41.0, longitude: 2.0),
            TrackPointModel(latitude: 41.01, longitude: 2.01),
            TrackPointModel(latitude: 41.02, longitude: 2.02),
            TrackPointModel(latitude: 41.03, longitude: 2.03),
          ],
        );

        notifier.state = notifier.state.copyWith(
          tracks: [track],
          selectedTrackId: 11,
          activeTool: 'range_map',
          selectionStartIndex: 1,
          selectionEndIndex: 3,
          chartRangeStartIndex: 1,
          chartRangeEndIndex: 3,
          isSelectingRange: false,
        );

        // Arrossegar l'END per sota del START no ha de moure el START.
        notifier.updateRangeSelectionHandleFromMap(
          41.0,
          2.0,
          15.0,
          isStartHandle: false,
        );

        final state = notifier.state;
        expect(state.selectionStartIndex, 1);
        expect(state.chartRangeStartIndex, 1);
        expect(state.selectionEndIndex, 1);
        expect(state.chartRangeEndIndex, 1);
      },
    );
  });
}
