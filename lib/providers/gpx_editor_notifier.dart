// 🌟 EL NOU PROVIDER TRADICIONAL (KeepAlive per defecte, no es reinicia mai sol)
import 'dart:async'; // Necessari per al StreamSubscription del sensor
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/services/track_elevation_service.dart';
import 'dart:math' as math;

enum _GeometryEditActionType { add, delete, move }

class _GeometryUndoEntry {
  final _GeometryEditActionType action;
  final int trackId;
  final int index;
  final TrackPointModel? beforePoint;
  final TrackPointModel? afterPoint;

  const _GeometryUndoEntry({
    required this.action,
    required this.trackId,
    required this.index,
    this.beforePoint,
    this.afterPoint,
  });
}

final gpxEditorProvider = StateNotifierProvider<GpxEditor, GpxEditorState>((
  ref,
) {
  return GpxEditor();
});

// Cambiem la definició de la classe perquè hereti de StateNotifier en comptes de _$GpxEditor
class GpxEditor extends StateNotifier<GpxEditorState> {
  // 🌟 REPARAT: Eliminem l'antiga instància d'EnvironmentSensors i canviem el tipat a int
  StreamSubscription<int>? _lightSubscription;
  final List<_GeometryUndoEntry> _geometryUndoStack = [];
  int? _moveOriginTrackId;
  int? _moveOriginIndex;
  TrackPointModel? _moveOriginPoint;

  static const int _maxGeometryUndoEntries = 100;

  // El constructor clàssic inicialitza l'estat i activa el sensor modern
  GpxEditor() : super(GpxEditorState.initial());

  // 🌟 OBLIGATORI PER A LA BATERIA: Tanquem el canal de dades en destruir el Notifier
  @override
  void dispose() {
    _lightSubscription?.cancel();
    super.dispose();
  }

  TrackPointModel _clonePoint(TrackPointModel point) {
    return TrackPointModel(
      latitude: point.latitude,
      longitude: point.longitude,
      elevation: point.elevation,
      timestamp: point.timestamp,
    );
  }

  bool _samePoint(TrackPointModel a, TrackPointModel b) {
    return a.latitude == b.latitude &&
        a.longitude == b.longitude &&
        a.elevation == b.elevation &&
        a.timestamp == b.timestamp;
  }

  void _refreshGeometryUndoAvailability() {
    state = state.copyWith(geometryCanUndo: _geometryUndoStack.isNotEmpty);
  }

  void _pushGeometryUndo(_GeometryUndoEntry entry) {
    _geometryUndoStack.add(entry);
    if (_geometryUndoStack.length > _maxGeometryUndoEntries) {
      _geometryUndoStack.removeAt(0);
    }
    _refreshGeometryUndoAvailability();
  }

  void _clearGeometryUndoHistory() {
    if (_geometryUndoStack.isEmpty && !state.geometryCanUndo) return;
    _geometryUndoStack.clear();
    _refreshGeometryUndoAvailability();
  }

  /// Selecciona el track en el estado global.
  void selectTrack(int? trackId) {
    _moveOriginTrackId = null;
    _moveOriginIndex = null;
    _moveOriginPoint = null;
    _clearGeometryUndoHistory();

    state = state.copyWith(
      selectedTrackId: trackId,
      snappedPoint: null,
      snappedPointIndex: null,
      geometryMoveNodeIndex: null,
      selectionStartIndex: null,
      selectionEndIndex: -1,
      isSelectingRange: false,
      forceHideReticle: false,
      isMapIdle: false,
      chartSelectionMode: 'simple',
    );
  }

  void setActiveTool(String tool) {
    final bool isGeometryTool = tool == 'edit_geometry';
    if (!isGeometryTool) {
      _moveOriginTrackId = null;
      _moveOriginIndex = null;
      _moveOriginPoint = null;
    }

    state = state.copyWith(
      activeTool: tool,
      snappedPoint: null,
      snappedPointIndex: null,
      geometryInsertIndex: null,
      geometryMoveNodeIndex: null,
      geometryEditMode: null,
      // Si obrim qualsevol altra eina, netegem el rang estàtic de la memòria
      selectionStartIndex: null,
      selectionEndIndex: -1,
      chartRangeStartIndex: null,
      chartRangeEndIndex: null,
      isSelectingRange: false,
      forceHideReticle: false,
      isMapIdle: false,
      chartSelectionMode: 'simple',
    );
  }

  void setMapIdle(bool isIdle) {
    state = state.copyWith(isMapIdle: isIdle);
  }

  void updateSnappedPoint(TrackPointModel? point, int? index) {
    state = state.copyWith(snappedPoint: point, snappedPointIndex: index);
  }

  void setGeometryEditMode(String mode) {
    if (state.activeTool != 'edit_geometry') return;
    if (!['add', 'delete', 'move'].contains(mode)) return;

    final String? nextMode = state.geometryEditMode == mode ? null : mode;

    state = state.copyWith(
      geometryEditMode: nextMode,
      snappedPoint: null,
      snappedPointIndex: null,
      geometryInsertIndex: null,
      geometryMoveNodeIndex: null,
      isMapIdle: false,
    );
  }

  void calculateAddNodeSnap(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.activeTool != 'edit_geometry' ||
        state.geometryEditMode != 'add') {
      return;
    }
    if (state.selectedTrackId == null || state.tracks.isEmpty) {
      return;
    }

    final track = state.tracks.firstWhere((t) => t.id == state.selectedTrackId);
    if (track.points.length < 2) {
      state = state.copyWith(
        snappedPoint: null,
        snappedPointIndex: null,
        geometryInsertIndex: null,
      );
      return;
    }

    final double cosLatRaw = math.cos(centerLat * math.pi / 180);
    final double cosLat = cosLatRaw.abs() < 0.000001 ? 0.000001 : cosLatRaw;

    double bestDistance = double.infinity;
    int bestSegmentStart = -1;
    double bestT = 0.0;
    double bestProjX = 0.0;
    double bestProjY = 0.0;
    TrackPointModel? leftPoint;
    TrackPointModel? rightPoint;

    for (int i = 0; i < track.points.length - 1; i++) {
      final p1 = track.points[i];
      final p2 = track.points[i + 1];

      if (p1.latitude == null ||
          p1.longitude == null ||
          p2.latitude == null ||
          p2.longitude == null) {
        continue;
      }

      final double ax = (p1.longitude! - centerLng) * 111320 * cosLat;
      final double ay = (p1.latitude! - centerLat) * 111320;
      final double bx = (p2.longitude! - centerLng) * 111320 * cosLat;
      final double by = (p2.latitude! - centerLat) * 111320;

      final double abx = bx - ax;
      final double aby = by - ay;
      final double len2 = abx * abx + aby * aby;
      if (len2 <= 0.0) continue;

      final double t = ((-ax * abx) + (-ay * aby)) / len2;
      final double clampedT = t.clamp(0.0, 1.0);

      final double projX = ax + (abx * clampedT);
      final double projY = ay + (aby * clampedT);

      final double d2 = (projX * projX) + (projY * projY);
      if (d2 < bestDistance) {
        bestDistance = d2;
        bestSegmentStart = i;
        bestT = clampedT;
        bestProjX = projX;
        bestProjY = projY;
        leftPoint = p1;
        rightPoint = p2;
      }
    }

    final double maxDistance = currentZoom < 12
        ? 120.0
        : (currentZoom < 15 ? 60.0 : 25.0);

    if (bestSegmentStart < 0 || bestDistance > maxDistance * maxDistance) {
      state = state.copyWith(
        snappedPoint: null,
        snappedPointIndex: null,
        geometryInsertIndex: null,
      );
      return;
    }

    final double snappedLat = centerLat + (bestProjY / 111320);
    final double snappedLng = centerLng + (bestProjX / (111320 * cosLat));

    double? snappedElevation;
    final double? e1 = leftPoint?.elevation;
    final double? e2 = rightPoint?.elevation;
    if (e1 != null && e2 != null) {
      snappedElevation = e1 + ((e2 - e1) * bestT);
    } else {
      snappedElevation = e1 ?? e2;
    }

    state = state.copyWith(
      snappedPoint: TrackPointModel(
        latitude: snappedLat,
        longitude: snappedLng,
        elevation: snappedElevation,
        timestamp: DateTime.now(),
      ),
      snappedPointIndex: bestSegmentStart,
      geometryInsertIndex: bestSegmentStart + 1,
    );
  }

  void addNodeAtCurrentSnap() {
    if (state.activeTool != 'edit_geometry' ||
        state.geometryEditMode != 'add') {
      return;
    }
    if (state.selectedTrackId == null ||
        state.snappedPoint == null ||
        state.geometryInsertIndex == null) {
      return;
    }

    final trackIndex = state.tracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    if (trackIndex == -1) return;

    final targetTrack = state.tracks[trackIndex];
    final int insertIndex = state.geometryInsertIndex!;
    if (insertIndex <= 0 || insertIndex >= targetTrack.points.length) return;

    final List<TrackPointModel> updatedPoints = List<TrackPointModel>.from(
      targetTrack.points,
    );

    final TrackPointModel previousPoint = updatedPoints[insertIndex - 1];
    final TrackPointModel nextPoint = updatedPoints[insertIndex];

    double? averagedElevation;
    if (previousPoint.elevation != null && nextPoint.elevation != null) {
      averagedElevation =
          (previousPoint.elevation! + nextPoint.elevation!) / 2.0;
    } else {
      averagedElevation = previousPoint.elevation ?? nextPoint.elevation;
    }

    DateTime? averagedTimestamp;
    if (previousPoint.timestamp != null && nextPoint.timestamp != null) {
      final int averagedMillis =
          ((previousPoint.timestamp!.millisecondsSinceEpoch +
                      nextPoint.timestamp!.millisecondsSinceEpoch) /
                  2)
              .round();
      averagedTimestamp = DateTime.fromMillisecondsSinceEpoch(averagedMillis);
    } else {
      averagedTimestamp = previousPoint.timestamp ?? nextPoint.timestamp;
    }

    updatedPoints.insert(
      insertIndex,
      TrackPointModel(
        latitude: state.snappedPoint!.latitude,
        longitude: state.snappedPoint!.longitude,
        elevation: averagedElevation,
        timestamp: averagedTimestamp,
      ),
    );

    _pushGeometryUndo(
      _GeometryUndoEntry(
        action: _GeometryEditActionType.add,
        trackId: targetTrack.id,
        index: insertIndex,
        afterPoint: _clonePoint(updatedPoints[insertIndex]),
      ),
    );

    final List<TrackModel> updatedTracks = List<TrackModel>.from(state.tracks);
    updatedTracks[trackIndex] = targetTrack.copyWith(points: updatedPoints);

    state = state.copyWith(
      tracks: updatedTracks,
      snappedPoint: null,
      snappedPointIndex: null,
      geometryInsertIndex: null,
      isMapIdle: false,
    );
  }

  void calculateDeleteNodeSnap(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.activeTool != 'edit_geometry' ||
        state.geometryEditMode != 'delete') {
      return;
    }
    if (state.selectedTrackId == null || state.tracks.isEmpty) {
      return;
    }

    final track = state.tracks.firstWhere((t) => t.id == state.selectedTrackId);
    if (track.points.length <= 2) {
      state = state.copyWith(
        snappedPoint: null,
        snappedPointIndex: null,
        geometryInsertIndex: null,
      );
      return;
    }

    double bestDistance = double.infinity;
    int bestIndex = -1;

    for (int i = 0; i < track.points.length; i++) {
      final p = track.points[i];
      if (p.latitude == null || p.longitude == null) continue;

      final lat = (p.latitude! - centerLat) * 111320;
      final lng =
          (p.longitude! - centerLng) *
          111320 *
          math.cos(centerLat * math.pi / 180);

      final distance = lat * lat + lng * lng;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    final double maxDistance = currentZoom < 12
        ? 120.0
        : (currentZoom < 15 ? 60.0 : 25.0);

    if (bestIndex >= 0 && bestDistance < maxDistance * maxDistance) {
      state = state.copyWith(
        snappedPoint: track.points[bestIndex],
        snappedPointIndex: bestIndex,
        geometryInsertIndex: null,
      );
    } else {
      state = state.copyWith(
        snappedPoint: null,
        snappedPointIndex: null,
        geometryInsertIndex: null,
      );
    }
  }

  void deleteNodeAtCurrentSnap() {
    if (state.activeTool != 'edit_geometry' ||
        state.geometryEditMode != 'delete') {
      return;
    }
    if (state.selectedTrackId == null || state.snappedPointIndex == null) {
      return;
    }

    final trackIndex = state.tracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    if (trackIndex == -1) return;

    final targetTrack = state.tracks[trackIndex];
    if (targetTrack.points.length <= 2) return;

    final int deleteIndex = state.snappedPointIndex!;
    if (deleteIndex < 0 || deleteIndex >= targetTrack.points.length) return;

    final TrackPointModel deletedPoint = _clonePoint(
      targetTrack.points[deleteIndex],
    );

    final List<TrackPointModel> updatedPoints = List<TrackPointModel>.from(
      targetTrack.points,
    )..removeAt(deleteIndex);

    _pushGeometryUndo(
      _GeometryUndoEntry(
        action: _GeometryEditActionType.delete,
        trackId: targetTrack.id,
        index: deleteIndex,
        beforePoint: deletedPoint,
      ),
    );

    final List<TrackModel> updatedTracks = List<TrackModel>.from(state.tracks);
    updatedTracks[trackIndex] = targetTrack.copyWith(points: updatedPoints);

    state = state.copyWith(
      tracks: updatedTracks,
      snappedPoint: null,
      snappedPointIndex: null,
      geometryInsertIndex: null,
      isMapIdle: false,
    );
  }

  void calculateMoveNodeSnap(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.activeTool != 'edit_geometry' ||
        state.geometryEditMode != 'move') {
      return;
    }
    if (state.selectedTrackId == null || state.tracks.isEmpty) {
      return;
    }

    final track = state.tracks.firstWhere((t) => t.id == state.selectedTrackId);
    if (track.points.isEmpty) {
      state = state.copyWith(
        snappedPoint: null,
        snappedPointIndex: null,
        geometryInsertIndex: null,
      );
      return;
    }

    if (state.geometryMoveNodeIndex != null) {
      final int selectedIndex = state.geometryMoveNodeIndex!;
      if (selectedIndex < 0 || selectedIndex >= track.points.length) {
        state = state.copyWith(
          geometryMoveNodeIndex: null,
          snappedPoint: null,
          snappedPointIndex: null,
        );
        return;
      }

      state = state.copyWith(
        snappedPoint: track.points[selectedIndex],
        snappedPointIndex: selectedIndex,
        geometryInsertIndex: null,
      );
      return;
    }

    double bestDistance = double.infinity;
    int bestIndex = -1;

    for (int i = 0; i < track.points.length; i++) {
      final p = track.points[i];
      if (p.latitude == null || p.longitude == null) continue;

      final lat = (p.latitude! - centerLat) * 111320;
      final lng =
          (p.longitude! - centerLng) *
          111320 *
          math.cos(centerLat * math.pi / 180);

      final distance = lat * lat + lng * lng;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    final double maxDistance = currentZoom < 12
        ? 120.0
        : (currentZoom < 15 ? 60.0 : 25.0);

    if (bestIndex >= 0 && bestDistance < maxDistance * maxDistance) {
      state = state.copyWith(
        snappedPoint: track.points[bestIndex],
        snappedPointIndex: bestIndex,
        geometryInsertIndex: null,
      );
    } else {
      state = state.copyWith(
        snappedPoint: null,
        snappedPointIndex: null,
        geometryInsertIndex: null,
      );
    }
  }

  void selectMoveNodeFromCurrentSnap() {
    if (state.activeTool != 'edit_geometry' ||
        state.geometryEditMode != 'move') {
      return;
    }
    if (state.selectedTrackId == null || state.snappedPointIndex == null) {
      return;
    }

    final trackIndex = state.tracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    if (trackIndex == -1) return;

    final int selectedIndex = state.snappedPointIndex!;
    final targetTrack = state.tracks[trackIndex];
    if (selectedIndex < 0 || selectedIndex >= targetTrack.points.length) return;

    _moveOriginTrackId = targetTrack.id;
    _moveOriginIndex = selectedIndex;
    _moveOriginPoint = _clonePoint(targetTrack.points[selectedIndex]);

    state = state.copyWith(
      geometryMoveNodeIndex: state.snappedPointIndex,
      isMapIdle: false,
    );
  }

  void moveSelectedNodeTo(double latitude, double longitude) {
    if (state.activeTool != 'edit_geometry' ||
        state.geometryEditMode != 'move') {
      return;
    }
    if (state.selectedTrackId == null || state.geometryMoveNodeIndex == null) {
      return;
    }

    final trackIndex = state.tracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    if (trackIndex == -1) return;

    final targetTrack = state.tracks[trackIndex];
    final int moveIndex = state.geometryMoveNodeIndex!;
    if (moveIndex < 0 || moveIndex >= targetTrack.points.length) return;

    final oldPoint = targetTrack.points[moveIndex];
    final movedPoint = TrackPointModel(
      latitude: latitude,
      longitude: longitude,
      elevation: oldPoint.elevation,
      timestamp: oldPoint.timestamp,
    );

    final List<TrackPointModel> updatedPoints = List<TrackPointModel>.from(
      targetTrack.points,
    );
    updatedPoints[moveIndex] = movedPoint;

    final List<TrackModel> updatedTracks = List<TrackModel>.from(state.tracks);
    updatedTracks[trackIndex] = targetTrack.copyWith(points: updatedPoints);

    state = state.copyWith(
      tracks: updatedTracks,
      snappedPoint: movedPoint,
      snappedPointIndex: moveIndex,
      geometryInsertIndex: null,
    );
  }

  void confirmMoveNodePosition() {
    if (state.activeTool != 'edit_geometry' ||
        state.geometryEditMode != 'move') {
      return;
    }

    final int? originTrackId = _moveOriginTrackId;
    final int? originIndex = _moveOriginIndex;
    final TrackPointModel? originPoint = _moveOriginPoint;

    if (originTrackId != null && originIndex != null && originPoint != null) {
      final int trackIndex = state.tracks.indexWhere(
        (t) => t.id == originTrackId,
      );
      if (trackIndex != -1) {
        final track = state.tracks[trackIndex];
        if (originIndex >= 0 && originIndex < track.points.length) {
          final TrackPointModel currentPoint = track.points[originIndex];
          if (!_samePoint(originPoint, currentPoint)) {
            _pushGeometryUndo(
              _GeometryUndoEntry(
                action: _GeometryEditActionType.move,
                trackId: originTrackId,
                index: originIndex,
                beforePoint: _clonePoint(originPoint),
                afterPoint: _clonePoint(currentPoint),
              ),
            );
          }
        }
      }
    }

    _moveOriginTrackId = null;
    _moveOriginIndex = null;
    _moveOriginPoint = null;

    state = state.copyWith(
      geometryMoveNodeIndex: null,
      snappedPoint: null,
      snappedPointIndex: null,
      isMapIdle: false,
    );
  }

  void undoLastGeometryEdit() {
    if (_geometryUndoStack.isEmpty) return;

    final _GeometryUndoEntry action = _geometryUndoStack.removeLast();
    final int trackIndex = state.tracks.indexWhere(
      (t) => t.id == action.trackId,
    );
    if (trackIndex == -1) {
      _refreshGeometryUndoAvailability();
      return;
    }

    final targetTrack = state.tracks[trackIndex];
    final List<TrackPointModel> updatedPoints = List<TrackPointModel>.from(
      targetTrack.points,
    );

    TrackPointModel? nextSnappedPoint;
    int? nextSnappedPointIndex;

    switch (action.action) {
      case _GeometryEditActionType.add:
        if (action.index < 0 || action.index >= updatedPoints.length) {
          _refreshGeometryUndoAvailability();
          return;
        }
        updatedPoints.removeAt(action.index);
        break;
      case _GeometryEditActionType.delete:
        if (action.beforePoint == null) {
          _refreshGeometryUndoAvailability();
          return;
        }
        if (action.index < 0 || action.index > updatedPoints.length) {
          _refreshGeometryUndoAvailability();
          return;
        }
        final restored = _clonePoint(action.beforePoint!);
        updatedPoints.insert(action.index, restored);
        nextSnappedPoint = restored;
        nextSnappedPointIndex = action.index;
        break;
      case _GeometryEditActionType.move:
        if (action.beforePoint == null) {
          _refreshGeometryUndoAvailability();
          return;
        }
        if (action.index < 0 || action.index >= updatedPoints.length) {
          _refreshGeometryUndoAvailability();
          return;
        }
        final restored = _clonePoint(action.beforePoint!);
        updatedPoints[action.index] = restored;
        nextSnappedPoint = restored;
        nextSnappedPointIndex = action.index;
        break;
    }

    final List<TrackModel> updatedTracks = List<TrackModel>.from(state.tracks);
    updatedTracks[trackIndex] = targetTrack.copyWith(points: updatedPoints);

    state = state.copyWith(
      tracks: updatedTracks,
      snappedPoint: nextSnappedPoint,
      snappedPointIndex: nextSnappedPointIndex,
      geometryInsertIndex: null,
      geometryMoveNodeIndex: null,
      isMapIdle: true,
    );

    _refreshGeometryUndoAvailability();
  }

  void toggleElevationChart() {
    final bool nextShowChart = !state.showElevationChart;

    // netegem immediatament l'agulla blava i el cercle de l'estat en el mateix frame
    if (!nextShowChart) {
      state = state.copyWith(
        showElevationChart: nextShowChart,
        snappedPointIndex: null,
        snappedPoint: null,
      );
    } else {
      state = state.copyWith(showElevationChart: nextShowChart);
    }
  }

  void toggleTrackVisibility(int trackId) {
    state = state.copyWith(
      tracks: state.tracks
          .map((t) => t.id == trackId ? t.copyWith(isVisible: !t.isVisible) : t)
          .toList(),
    );
  }

  void updateTrackColor(int trackId, String hexColor) {
    state = state.copyWith(
      tracks: state.tracks
          .map((t) => t.id == trackId ? t.copyWith(hexColor: hexColor) : t)
          .toList(),
    );
  }

  void reorderTracks(int oldIndex, int newIndex) {
    final list = List<TrackModel>.from(state.tracks);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(tracks: list);
  }

  // Mantenim el teu mètode original de tota la vida intacte:
  void addImportedTracks(List<TrackModel> newTracks) {
    _clearGeometryUndoHistory();

    final List<TrackModel> fixed = [];
    int baseTimestamp = DateTime.now().microsecondsSinceEpoch;

    for (int i = 0; i < newTracks.length; i++) {
      final track = newTracks[i];
      track.id = baseTimestamp + i;
      fixed.add(track);
    }

    state = state.copyWith(
      tracks: [...state.tracks, ...fixed],
      selectedTrackId: fixed.first.id,
      showSidebar: true,
    );
  }

  /// 🌟 NOU: Alterna la visibilitat del panell lateral esquerre
  void toggleSidebar() {
    state = state.copyWith(showSidebar: !state.showSidebar);
  }

  void calculateSnapping(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.tracks.isEmpty || state.selectedTrackId == null) {
      return;
    }

    final bool isSplitMode = state.activeTool == 'split';
    final bool isRangeMapMode = state.activeTool == 'range_map';
    final bool isMergeMode = state.activeTool == 'merge';

    if (!isSplitMode && !isRangeMapMode && !isMergeMode) {
      return;
    }

    // ---------------------------------------------------------
    // MERGE MODE
    // ---------------------------------------------------------
    if (isMergeMode) {
      double minDistance = double.infinity;
      int? closestTrackId;
      List<TrackPointModel>? closestPoints;

      for (final track in state.tracks) {
        if (track.id == state.selectedTrackId) continue;

        for (final p in track.points) {
          if (p.latitude == null || p.longitude == null) continue;

          final lat = (p.latitude! - centerLat) * 111320;
          final lng =
              (p.longitude! - centerLng) *
              111320 *
              math.cos(centerLat * math.pi / 180);

          final d = lat * lat + lng * lng;

          if (d < minDistance) {
            minDistance = d;
            closestTrackId = track.id;
            closestPoints = track.points;
          }
        }
      }

      const threshold = 50.0;

      if (closestTrackId != null &&
          closestPoints != null &&
          minDistance < threshold * threshold) {
        final trackA = state.tracks.firstWhere(
          (t) => t.id == state.selectedTrackId,
        );

        state = state.copyWith(
          previewTrackId: closestTrackId,
          previewPoints: [...trackA.points, ...closestPoints],
        );
      } else {
        state = state.copyWith(previewTrackId: null, previewPoints: null);
      }

      return;
    }

    // ---------------------------------------------------------
    // SPLIT / RANGE_MAP MODE
    // ---------------------------------------------------------
    final track = state.tracks.firstWhere((t) => t.id == state.selectedTrackId);

    if (track.points.isEmpty) {
      return;
    }

    double bestDistance = double.infinity;
    int bestIndex = -1;

    for (int i = 0; i < track.points.length; i++) {
      final p = track.points[i];

      if (p.latitude == null || p.longitude == null) continue;

      final lat = (p.latitude! - centerLat) * 111320;
      final lng =
          (p.longitude! - centerLng) *
          111320 *
          math.cos(centerLat * math.pi / 180);

      final distance = lat * lat + lng * lng;

      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    double maxDistance;

    if (currentZoom < 12) {
      maxDistance = 120;
    } else if (currentZoom < 15) {
      maxDistance = 60;
    } else {
      maxDistance = 25;
    }

    if (bestIndex >= 0 && bestDistance < maxDistance * maxDistance) {
      state = state.copyWith(
        snappedPoint: track.points[bestIndex],
        snappedPointIndex: bestIndex,
      );
    } else {
      state = state.copyWith(snappedPoint: null, snappedPointIndex: null);
    }
  }

  /// 🤝 CONFIRMACIÓ FINAL DEL MERGE (Executada en prémer el botó flotant)
  void executeTracksMerge() {
    if (state.selectedTrackId == null ||
        state.previewTrackId == null ||
        state.previewPoints == null)
      return;

    final trackA = state.tracks.firstWhere(
      (t) => t.id == state.selectedTrackId,
    );
    final trackB = state.tracks.firstWhere((t) => t.id == state.previewTrackId);

    final int newTrackId = DateTime.now().microsecondsSinceEpoch;
    final String cleanNameA = trackA.name.replaceAll(RegExp(r'_part\d+'), '');
    final String cleanNameB = trackB.name.replaceAll(RegExp(r'_part\d+'), '');

    final mergedTrack = TrackModel(
      id: newTrackId,
      name: "${cleanNameA}_merge_${cleanNameB}",
      hexColor: trackA.hexColor,
      points: List<TrackPointModel>.from(state.previewPoints!),
      waypoints: [...trackA.waypoints, ...trackB.waypoints],
    );

    // 🌟 REPARADO: No borramos trackA ni trackB.
    // Mapeamos la lista actual para ocultar los dos tracks originales en el mapa.
    final List<TrackModel> updatedList = state.tracks.map((t) {
      if (t.id == trackA.id || t.id == trackB.id) {
        return t.copyWith(isVisible: false); // Los apagamos visualmente
      }
      return t;
    }).toList();

    // Añadimos el nuevo track combinado al final de la lista
    updatedList.add(mergedTrack);

    state = state.copyWith(
      tracks: updatedList,
      selectedTrackId: newTrackId, // Hacemos foco automático en el nuevo
      previewTrackId: null,
      previewPoints: null,
      activeTool: 'none',
    );
  }

  // =========================================================================
  // ✂️ LÒGICA D'ACCIONS: SPLIT I INVERSIÓ NETEJA (DINS DEL FITXER CENTRAL)
  // =========================================================================
  void executeTrackSplit() {
    if (state.selectedTrackId == null || state.snappedPointIndex == null)
      return;

    final int cutIndex = state.snappedPointIndex!;
    final List<TrackModel> updatedTracks = List.from(state.tracks);

    final trackIndex = updatedTracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    if (trackIndex == -1) return;

    final originalTrack = updatedTracks[trackIndex];
    if (cutIndex <= 0 || cutIndex >= originalTrack.points.length - 1) return;

    final pointsPart1 = originalTrack.points.sublist(0, cutIndex + 1);
    final pointsPart2 = originalTrack.points.sublist(cutIndex);
    final String baseName = originalTrack.name.replaceAll(
      RegExp(r'_part\d+'),
      '',
    );

    final trackPart1 = TrackModel(
      id: DateTime.now().microsecondsSinceEpoch,
      name: "${baseName}_part1",
      hexColor: originalTrack.hexColor,
      points: pointsPart1,
      waypoints: List.from(originalTrack.waypoints),
    );

    final trackPart2 = TrackModel(
      id: DateTime.now().microsecondsSinceEpoch + 999,
      name: "${baseName}_part2",
      hexColor: "#AF52DE",
      points: pointsPart2,
      waypoints: [],
    );

    // Conservem el track original al sidebar i afegim les dues parts a continuació.
    updatedTracks.insert(trackIndex + 1, trackPart1);
    updatedTracks.insert(trackIndex + 2, trackPart2);

    state = state.copyWith(
      tracks: updatedTracks,
      selectedTrackId: trackPart1.id,
      snappedPoint: null,
      snappedPointIndex: null,
      activeTool: 'none',
    );
  }

  // 🔥 AQUÍ ESTÀ EL MÈTODE QUE ET DEMANAVA LA UI REPARAT:
  void reverseCurrentTrackWithCleanState() {
    if (state.selectedTrackId == null) return;

    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == state.selectedTrackId) {
          return track.copyWith(points: track.points.reversed.toList());
        }
        return track;
      }).toList(),
      selectionStartIndex: null,
      selectionEndIndex: -1,
      snappedPoint: null,
      snappedPointIndex: null,
      activeTool: 'none',
      forceHideReticle: true,
      isSelectingRange: false,
      isMapIdle: false,
      chartSelectionMode: 'simple',
    );
  }

  // =========================================================================
  // 📏 MÀQUINA D'ESTATS DE LA RETÍCULA (SELECCIÓ DE TRAMS DE 2 PUNTS)
  // =========================================================================
  void handleMapPointSelection() {
    if (state.snappedPointIndex == null) return;

    final int currentIndex = state.snappedPointIndex!;

    // 1️⃣ Fase 1: Fixar el punt inicial del tram
    if (state.selectionStartIndex == null && !state.isSelectingRange) {
      state = state.copyWith(
        selectionStartIndex: currentIndex,
        isSelectingRange: true,
        forceHideReticle: false,
      );
      return;
    }

    // 2️⃣ Fase 2: Fixar el punt final del tram
    if (state.selectionStartIndex != null && state.isSelectingRange) {
      final int start = state.selectionStartIndex!;
      final int realStart = start < currentIndex ? start : currentIndex;
      final int realEnd = start < currentIndex ? currentIndex : start;

      state = state.copyWith(
        selectionStartIndex: realStart,
        selectionEndIndex: realEnd,
        isSelectingRange: false,
        forceHideReticle: false,
      );
      return;
    }

    // 3️⃣ Fase 3: Reiniciar per poder seleccionar un nou tram lliure
    if (state.selectionStartIndex != null &&
        state.selectionEndIndex != null &&
        !state.isSelectingRange) {
      state = state.copyWith(
        selectionStartIndex: currentIndex,
        selectionEndIndex: -1,
        isSelectingRange: true,
        forceHideReticle: false,
      );
      return;
    }
  }

  /// 🗑️ ELIMINAR CAPA (Del estado y del Sidebar)
  void deleteTrack(int trackId) {
    // Si borramos el track que estaba seleccionado, ponemos la selección a null
    final int? nextSelectedId = state.selectedTrackId == trackId
        ? null
        : state.selectedTrackId;

    state = state.copyWith(
      tracks: state.tracks.where((t) => t.id != trackId).toList(),
      selectedTrackId: nextSelectedId,
    );
  }

  /// 💾 EXPORTAR GPX (Genera la estructura de texto XML)
  String generateGpxString(TrackModel track) {
    final StringBuffer xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln(
      '<gpx version="1.1" creator="TrackioApp" xmlns="http://topografix.com">',
    );

    // 1. Añadir Waypoints si el track los contiene
    for (final wp in track.waypoints) {
      if (wp.latitude == null || wp.longitude == null) continue;
      xml.writeln('  <wpt lat="${wp.latitude}" lon="${wp.longitude}">');
      if (wp.elevation != null) xml.writeln('    <ele>${wp.elevation}</ele>');
      if (wp.name != null) xml.writeln('    <name>${wp.name}</name>');
      if (wp.comment != null) xml.writeln('    <cmt>${wp.comment}</cmt>');
      xml.writeln('  </wpt>');
    }

    // 2. Añadir Track y Trackpoints
    xml.writeln('  <trk>');
    xml.writeln('    <name>${track.name}</name>');
    xml.writeln('    <trkseg>');

    for (final p in track.points) {
      if (p.latitude == null || p.longitude == null) continue;
      xml.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}">');
      if (p.elevation != null) xml.writeln('        <ele>${p.elevation}</ele>');
      if (p.timestamp != null)
        xml.writeln(
          '        <time>${p.timestamp!.toUtc().toIso8601String()}</time>',
        );
      xml.writeln('      </trkpt>');
    }

    xml.writeln('    </trkseg>');
    xml.writeln('  </trk>');
    xml.writeln('</gpx>');

    return xml.toString();
  }

  // 📍 1. Actualitza la coordenada de la retícula central (es cridarà quan el mapa es mogui)
  void updateWaypointPosition(double latitude, double longitude) {
    final current = state.waypointCameraPosition;
    if (current != null) {
      const double epsilon = 0.000001;
      final bool unchanged =
          (current.latitude - latitude).abs() < epsilon &&
          (current.longitude - longitude).abs() < epsilon;
      if (unchanged) return;
    }

    state = state.copyWith(waypointCameraPosition: LatLng(latitude, longitude));
  }

  // 📍 2. Inserció del waypoint al track seleccionat actiu en aquell moment
  void addWaypointToSelectedTrack({
    String name = 'Waypoint',
    String comment = '',
  }) {
    // Si no hi ha cap track triat o el mapa no té posició, no fem res
    if (state.selectedTrackId == null || state.waypointCameraPosition == null)
      return;

    final targetPosition = state.waypointCameraPosition!;

    // Creem el nou model de fita / waypoint
    final newWaypoint = WaypointModel(
      latitude: targetPosition.latitude,
      longitude: targetPosition.longitude,
      elevation: 0.0,
      name: name,
      comment: comment,
    );

    // Mapegem els tracks actuals per afegir el waypoint només al que està seleccionat
    final updatedTracks = state.tracks.map((track) {
      if (track.id == state.selectedTrackId) {
        return track.copyWith(waypoints: [...track.waypoints, newWaypoint]);
      }
      return track;
    }).toList();

    // Actualitzem l'estat global, tanquem l'eina i netegem variables
    state = state.copyWith(
      tracks: updatedTracks,
      activeTool: 'none',
      waypointCameraPosition: null,
      isMapIdle: false,
    );
  }

  // =========================================================================
  // 📈 SELECCIÓ DES DEL GRÀFIC (SINCRONITZACIÓ BIDIRECCIONAL)
  // =========================================================================

  /// 🌟 1) Actualitza l’agulla blava (hover / drag de posició)
  void updateChartNeedle(int idx) {
    debugPrint(
      '[chart-notifier] updateChartNeedle idx=$idx activeTool=${state.activeTool}',
    );
    state = state.copyWith(chartNeedleIndex: idx, chartSelectionMode: 'simple');
  }

  void startChartRangeSelection({required int startIdx, required int endIdx}) {
    if (state.selectedTrackId == null) {
      debugPrint(
        '[chart-notifier] startChartRangeSelection aborted: no selected track',
      );
      return;
    }

    final activeTrack = state.tracks.firstWhere(
      (t) => t.id == state.selectedTrackId,
    );
    final int totalPoints = activeTrack.points.length;
    if (totalPoints <= 0) return;

    final int clampedStart = startIdx.clamp(0, totalPoints - 1);
    final int clampedEnd = endIdx.clamp(0, totalPoints - 1);
    final int s = clampedStart < clampedEnd ? clampedStart : clampedEnd;
    final int e = clampedStart < clampedEnd ? clampedEnd : clampedStart;

    debugPrint('[chart-notifier] startChartRangeSelection s=$s e=$e');

    state = state.copyWith(
      activeTool: 'range_map',
      selectionStartIndex: s,
      selectionEndIndex: e,
      chartRangeStartIndex: s,
      chartRangeEndIndex: e,
      isSelectingRange: false,
      chartNeedleIndex: null,
      chartSelectionMode: 'range',
    );
  }

  // 🧠 REPARACIÓ FINAL AL PROVIDER (GPX_EDITOR_NOTIFIER)
  void startChartRangeSelectionWithPercent() {
    if (state.selectedTrackId == null) return;

    final activeTrack = state.tracks.firstWhere(
      (t) => t.id == state.selectedTrackId,
    );
    final int totalPoints = activeTrack.points.length;
    if (totalPoints <= 0) return;

    final int startIdx = (totalPoints * 0.25).floor().clamp(0, totalPoints - 1);
    final int endIdx = (totalPoints * 0.75).floor().clamp(0, totalPoints - 1);

    startChartRangeSelection(startIdx: startIdx, endIdx: endIdx);
  }

  /// 🌟 3) ACTUALITZACIÓ D'UNA AGULLA INDIVIDUAL DEL RANG (Mentre l'usuari arrossega els handles)
  void updateIndividualRangeHandle({int? newStartIdx, int? newEndIdx}) {
    if (state.selectedTrackId == null) {
      debugPrint(
        '[chart-notifier] updateIndividualRangeHandle aborted: no selected track',
      );
      return;
    }

    final activeTrack = state.tracks.firstWhere(
      (t) => t.id == state.selectedTrackId,
    );

    final int? currentStart =
        state.chartRangeStartIndex ?? state.selectionStartIndex;
    final int? currentEnd = state.chartRangeEndIndex ?? state.selectionEndIndex;

    int? nextStart = newStartIdx ?? currentStart;
    int? nextEnd = newEndIdx ?? currentEnd;

    if (newStartIdx != null && newEndIdx != null) {
      if (nextStart != null && nextEnd != null && nextStart > nextEnd) {
        final int tmp = nextStart;
        nextStart = nextEnd;
        nextEnd = tmp;
      }
    } else if (newStartIdx != null && newEndIdx == null && currentEnd != null) {
      if (nextStart != null && nextStart > currentEnd) {
        nextStart = currentEnd;
        nextEnd = newStartIdx;
      } else {
        nextEnd = currentEnd;
      }
    } else if (newEndIdx != null &&
        newStartIdx == null &&
        currentStart != null) {
      if (nextEnd != null && nextEnd < currentStart) {
        nextStart = newEndIdx;
        nextEnd = currentStart;
      } else {
        nextStart = currentStart;
      }
    } else if (nextStart != null && nextEnd != null && nextStart > nextEnd) {
      final int tmp = nextStart;
      nextStart = nextEnd;
      nextEnd = tmp;
    }

    final int targetIdx = nextStart ?? nextEnd ?? 0;
    debugPrint(
      '[chart-notifier] updateIndividualRangeHandle start=$newStartIdx end=$newEndIdx target=$targetIdx',
    );
    TrackPointModel? currentSnappedPoint;
    if (targetIdx >= 0 && targetIdx < activeTrack.points.length) {
      currentSnappedPoint = activeTrack.points[targetIdx];
    }

    state = state.copyWith(
      selectionStartIndex: nextStart,
      chartRangeStartIndex: nextStart,
      selectionEndIndex: nextEnd,
      chartRangeEndIndex: nextEnd,
      isSelectingRange: true,
      chartSelectionMode: 'range',

      // 🔒 REPARACIÓ: Sincronitzem el punt fixat de geolocalització i el seu índex
      // perquè el map_rendering_mixin rebi el canvi en el mateix frame de la GPU
      snappedPoint: currentSnappedPoint,
      snappedPointIndex: targetIdx,
    );
  }

  /// 🌟 4) Congelar el rang (Guarda les fites verda i vermella i finalitza l'arrossegament)
  void finalizeChartRangeSelection(int start, int end) {
    final int s = start < end ? start : end;
    final int e = start < end ? end : start;

    debugPrint('[chart-notifier] finalizeChartRangeSelection s=$s e=$e');

    state = state.copyWith(
      selectionStartIndex: s,
      selectionEndIndex: e,
      chartRangeStartIndex: s,
      chartRangeEndIndex: e,
      isSelectingRange: false,
      chartSelectionMode: 'range',
    );
  }

  /// 🌟 5) Esborrar completament el rang i els seus indicadors fixos
  void clearChartSelection() {
    debugPrint(
      '[chart-notifier] clearChartSelection activeTool=${state.activeTool}',
    );
    state = state.copyWith(
      selectionStartIndex: null,
      selectionEndIndex: null,
      chartRangeStartIndex: null,
      chartRangeEndIndex: null,
      isSelectingRange: false,
      activeTool: 'none',
      chartSelectionMode: 'simple',
    );
  }

  /// 🌟 6) Esborrar l’agulla blava mòbil del dit
  void clearChartNeedle() {
    state = state.copyWith(
      chartNeedleIndex: null,
      chartSelectionMode: 'simple',
    );
  }

  /// 📐 CREAR UN NOU TRACK COPIAT A PARTIR DEL RANG ACTUAL ACUTALITZAT
  void createTrackFromSelectedRange() {
    if (state.selectedTrackId == null ||
        state.selectionStartIndex == null ||
        state.selectionEndIndex == null ||
        state.selectionEndIndex == -1) {
      return;
    }

    final int start = state.selectionStartIndex!;
    final int end = state.selectionEndIndex!;

    final activeTrack = state.tracks.firstWhere(
      (t) => t.id == state.selectedTrackId,
    );
    if (start < 0 || end >= activeTrack.points.length) return;

    // Extreiem de forma neta i immutable el tros seleccionat per l'usuari
    final selectedPoints = activeTrack.points.sublist(start, end + 1);
    final int newTrackId = DateTime.now().microsecondsSinceEpoch;

    final newTrack = TrackModel(
      id: newTrackId,
      name: "${activeTrack.name}_segment",
      hexColor: "#FF5722", // Taronja distintiu per a la nova capa
      points: List<TrackPointModel>.from(selectedPoints),
      waypoints: const [],
    );

    state = state.copyWith(
      tracks: [...state.tracks, newTrack],
      selectedTrackId:
          newTrack.id, // Saltem el focus automàticament cap al segment nou
      selectionStartIndex: null,
      selectionEndIndex: -1,
      chartRangeStartIndex: null,
      chartRangeEndIndex: null,
      activeTool: 'none',
    );
  }

  void toggleSpeedChart() {
    state = state.copyWith(showSpeedInChart: !state.showSpeedInChart);
  }

  // =========================================================================
  // 🎨 MÀQUINA D'ESTATS DE L'EINA "DIBUIXAR" (CREACIÓ DE RUTES EN 3D)
  // =========================================================================

  // Instanciem el teu servei de cua multithread protegit amb el Queue corregit
  static final TrackElevationService _elevationService =
      TrackElevationService();

  /// 📐 1. RETÍCULA EN MOVIMENT (línia elàstica temporal)
  /// Sincronitza la previsualització i demana l'alçada del centre de la pantalla
  void updateDrawingLiveLocation(double lat, double lon) {
    if (state.activeTool != 'draw') return;

    final provisionalPoint = TrackPointModel(
      latitude: lat,
      longitude: lon,
      elevation: 0.0,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(drawingLivePoint: provisionalPoint);

    // Demanem Z asíncrona a la cua (el debounce del servei s'encarrega d'esperar el repòs)
    _elevationService.requestPoint(
      lat: lat,
      lon: lon,
      onResult: (resLat, resLon, ele) {
        if (state.drawingLivePoint?.latitude == resLat &&
            state.drawingLivePoint?.longitude == resLon) {
          state = state.copyWith(
            drawingLivePoint: TrackPointModel(
              latitude: resLat,
              longitude: resLon,
              elevation: ele,
              timestamp: state.drawingLivePoint?.timestamp ?? DateTime.now(),
            ),
            // 🔥 CLAU: Forcem un re-render de l'estat duplicant la llista de tracks temporals
            // d'aquesta manera qualsevol giny (com el gràfic) que estigui escoltant reaccionarà en viu.
            tracks: List.from(state.tracks),
          );
        }
      },
    );
  }

  /// 📍 2. FILET DE COORDENADES (CLIC AL MAPA)
  /// Injecta la coordenada immediatament amb Z=0 i resol l'alçada en segon pla
  void addPointToNewTrack(double lat, double lon) {
    if (state.activeTool != 'draw') return;

    final indexNouNode = state.drawingPoints.length;
    final nouNodeInicial = TrackPointModel(
      latitude: lat,
      longitude: lon,
      elevation: 0.0,
      timestamp: DateTime.now(),
    );

    // Feedback instantani a la UI
    final novesCoordenades = [...state.drawingPoints, nouNodeInicial];
    state = state.copyWith(drawingPoints: novesCoordenades);

    // Executem la interpolació bilineal des del CogService a través de la cua
    _elevationService.requestPoint(
      lat: lat,
      lon: lon,
      onResult: (resLat, resLon, ele) {
        // Quan la tessel·la es descarrega d'Azure, mutem sàviament només l'alçada del node exacte
        if (indexNouNode < state.drawingPoints.length) {
          final llistaActualitzada = List<TrackPointModel>.from(
            state.drawingPoints,
          );
          llistaActualitzada[indexNouNode] = TrackPointModel(
            latitude: resLat,
            longitude: resLon,
            elevation: ele,
            timestamp: llistaActualitzada[indexNouNode].timestamp,
          );
          state = state.copyWith(drawingPoints: llistaActualitzada);
        }
      },
    );
  }

  /// ↩️ 3. DESFER (UNDO DIBUIX)
  /// Elimina l'última coordenada pitjada per l'usuari
  void removeLastDrawingPoint() {
    if (state.drawingPoints.isEmpty) return;
    final llistaReduida = List<TrackPointModel>.from(state.drawingPoints)
      ..removeLast();
    state = state.copyWith(drawingPoints: llistaReduida);
  }

  /// 🧹 4. CANCEL·LAR ACCIÓ
  /// Aborta l'edició i buida les llistes temporals de treball
  void cancelDrawing() {
    state = state.copyWith(
      drawingPoints: const [],
      drawingLivePoint: null,
      activeTool: 'none',
    );
  }

  /// 💾 5. FINALITZAR I DESAR RUTA
  /// Salva els nodes provisionals com a capa estable a l'editor amb el seu perfil d'elevacions complet
  void saveDrawnTrack(String trackName) {
    if (state.drawingPoints.isEmpty) return;

    final int nouId = DateTime.now().microsecondsSinceEpoch;

    final nouTrack = TrackModel(
      id: nouId,
      name: trackName.isNotEmpty ? trackName : "Nova Ruta Dibuixada",
      points: List<TrackPointModel>.from(state.drawingPoints),
      hexColor: "#E91E63", // Fúcsia d'edició
      isVisible: true,
      waypoints: const [],
    );

    state = state.copyWith(
      tracks: [...state.tracks, nouTrack],
      selectedTrackId: nouId, // Auto-enfocament
      drawingPoints: const [],
      drawingLivePoint: null,
      activeTool: 'none',
    );
  }

  /// 🌟 NOU PAS A PAS: Retorna la llista de punts clicats + el punt efímer actual de la retícula
  List<TrackPointModel> getComputedDrawingPoints() {
    if (state.drawingPoints.isEmpty) {
      if (state.drawingLivePoint != null) {
        return [state.drawingLivePoint!];
      }
      return const [];
    }

    // Si tenim un punt efímer actiu amb alçada, el concatenem de forma dinàmica al final
    if (state.drawingLivePoint != null) {
      return [...state.drawingPoints, state.drawingLivePoint!];
    }

    return state.drawingPoints;
  }

  /// 📐 MOU LA RETÍCULA EN RÀFEGA SENSE CALCULOS DE Z (Per al moviment fluid 2D)
  void updateDrawingLiveLocationWithoutZ(double lat, double lon) {
    if (state.activeTool != 'draw') return;

    final provisionalPoint = TrackPointModel(
      latitude: lat,
      longitude: lon,
      elevation: 0.0,
      timestamp: DateTime.now(),
    );

    // 🌟 REPARACIÓ: Eliminem el 'tracks: List.from' per trencar el bucle infinit!
    state = state.copyWith(drawingLivePoint: provisionalPoint);
  }

  int? getNearestTrackPointIndexForCoordinates(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.tracks.isEmpty || state.selectedTrackId == null) return null;

    final track = state.tracks.firstWhere((t) => t.id == state.selectedTrackId);
    if (track.points.isEmpty) return null;

    double bestDistance = double.infinity;
    int bestIndex = -1;

    for (int i = 0; i < track.points.length; i++) {
      final p = track.points[i];
      if (p.latitude == null || p.longitude == null) continue;

      final lat = (p.latitude! - centerLat) * 111320;
      final lng =
          (p.longitude! - centerLng) *
          111320 *
          math.cos(centerLat * math.pi / 180);
      final distance = lat * lat + lng * lng;

      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    double maxDistance = currentZoom < 12
        ? 120.0
        : (currentZoom < 15 ? 60.0 : 25.0);

    if (bestIndex >= 0 && bestDistance < maxDistance * maxDistance) {
      return bestIndex;
    }
    return null;
  }

  /// 📐 MURE LA RETÍCULA DE RANG EN VIU (Mentre l'usuari arrossega el mapa a l'APK)
  void updateRangeSelectionLiveFromReticle(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.tracks.isEmpty ||
        state.selectedTrackId == null ||
        state.activeTool != 'range_map')
      return;

    final track = state.tracks.firstWhere((t) => t.id == state.selectedTrackId);
    if (track.points.isEmpty) return;

    final int? bestIndex = getNearestTrackPointIndexForCoordinates(
      centerLat,
      centerLng,
      currentZoom,
    );
    if (bestIndex == null) return;

    final TrackPointModel? snappedPoint =
        bestIndex >= 0 && bestIndex < track.points.length
        ? track.points[bestIndex]
        : null;

    if (state.selectionStartIndex == null) {
      state = state.copyWith(
        selectionStartIndex: bestIndex,
        selectionEndIndex: null,
        chartRangeStartIndex: bestIndex,
        chartRangeEndIndex: null,
        snappedPointIndex: bestIndex,
        snappedPoint: snappedPoint,
        chartSelectionMode: 'range',
      );
    } else if (state.selectionStartIndex != null && state.isSelectingRange) {
      final int start = state.selectionStartIndex!;
      int visualEnd = start < bestIndex ? bestIndex : start;

      state = state.copyWith(
        selectionStartIndex: start,
        selectionEndIndex: visualEnd,
        // Mantenim l'ordre temporal de fixació pels colors del mapa:
        // primer punt (verd) = start, segon punt (vermell) = bestIndex.
        chartRangeStartIndex: start,
        chartRangeEndIndex: bestIndex,
        snappedPointIndex: bestIndex,
        snappedPoint: snappedPoint,
        chartSelectionMode: 'range',
      );
    } else {
      // Amb el tram ja tancat, mantenim el preview del punt actual de retícula
      // perquè el següent "Fixar Inici" comenci al punt realment visible.
      state = state.copyWith(
        snappedPointIndex: bestIndex,
        snappedPoint: snappedPoint,
      );
    }
  }

  void updateRangeSelectionHandleFromMap(
    double centerLat,
    double centerLng,
    double currentZoom, {
    required bool isStartHandle,
  }) {
    if (state.tracks.isEmpty ||
        state.selectedTrackId == null ||
        state.activeTool != 'range_map') {
      return;
    }

    final track = state.tracks.firstWhere((t) => t.id == state.selectedTrackId);
    final int? bestIndex = getNearestTrackPointIndexForCoordinates(
      centerLat,
      centerLng,
      currentZoom,
    );
    if (bestIndex == null) return;

    final int? currentStart = state.selectionStartIndex;
    final int? currentEnd = state.selectionEndIndex;
    if (currentStart == null || currentEnd == null || currentEnd == -1) {
      return;
    }

    // Manté fix el handle oposat i limita el handle actiu per evitar swaps.
    // Això evita que, en creuar-se, semblin moure's els dos extrems alhora.
    final int nextStart;
    final int nextEnd;
    if (isStartHandle) {
      nextStart = bestIndex.clamp(0, currentEnd);
      nextEnd = currentEnd;
    } else {
      nextStart = currentStart;
      nextEnd = bestIndex.clamp(currentStart, track.points.length - 1);
    }

    final TrackPointModel? snappedPoint =
        bestIndex >= 0 && bestIndex < track.points.length
        ? track.points[bestIndex]
        : null;

    state = state.copyWith(
      selectionStartIndex: nextStart,
      chartRangeStartIndex: nextStart,
      selectionEndIndex: nextEnd,
      chartRangeEndIndex: nextEnd,
      snappedPointIndex: bestIndex,
      snappedPoint: snappedPoint,
      isSelectingRange: false,
      chartSelectionMode: 'range',
      forceHideReticle: false,
    );
  }

  void handleRangeMapSelectionTap(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.tracks.isEmpty ||
        state.selectedTrackId == null ||
        state.activeTool != 'range_map') {
      return;
    }

    final track = state.tracks.firstWhere((t) => t.id == state.selectedTrackId);
    final int? snappedIndex = getNearestTrackPointIndexForCoordinates(
      centerLat,
      centerLng,
      currentZoom,
    );
    if (snappedIndex == null) return;

    final TrackPointModel? snappedPoint =
        snappedIndex >= 0 && snappedIndex < track.points.length
        ? track.points[snappedIndex]
        : null;

    if (state.selectionStartIndex != null &&
        state.selectionEndIndex != null &&
        !state.isSelectingRange) {
      // Si el tram ja està tancat, qualsevol nou "fixar punt"
      // reinicia el tram i aquest punt passa a ser el nou inici.
      resetRangeSelectionForNewStart();
      fixRangeStartIndexAt(index: snappedIndex, point: snappedPoint);
      return;
    }

    if (state.selectionStartIndex == null) {
      fixRangeStartIndexAt(index: snappedIndex, point: snappedPoint);
      return;
    }

    if (state.selectionStartIndex != null &&
        (state.selectionEndIndex == null ||
            state.selectionEndIndex == -1 ||
            state.isSelectingRange)) {
      fixRangeEndIndexAt(index: snappedIndex, point: snappedPoint);
    }
  }

  void resetRangeSelectionForNewStart() {
    state = state.copyWith(
      selectionStartIndex: null,
      selectionEndIndex: null,
      chartRangeStartIndex: null,
      chartRangeEndIndex: null,
      isSelectingRange: false,
      forceHideReticle: false,
    );
  }

  void fixRangeStartIndexAt({required int index, TrackPointModel? point}) {
    state = state.copyWith(
      selectionStartIndex: index,
      selectionEndIndex: null,
      chartRangeStartIndex: index,
      chartRangeEndIndex: null,
      snappedPointIndex: index,
      snappedPoint: point,
      isSelectingRange: true,
      chartSelectionMode: 'range',
      forceHideReticle: false,
    );
  }

  /// 🟢 FIXAR EL PUNT INICIAL (Es crida en prémer el botó flotant per primer cop)
  void fixRangeStartIndex() {
    if (state.snappedPointIndex == null) return;
    fixRangeStartIndexAt(
      index: state.snappedPointIndex!,
      point: state.snappedPoint,
    );
  }

  void fixRangeEndIndexAt({required int index, TrackPointModel? point}) {
    if (state.selectionStartIndex == null) return;

    final int start = state.selectionStartIndex!;
    final int realStart = start < index ? start : index;
    final int realEnd = start < index ? index : start;

    state = state.copyWith(
      selectionStartIndex: realStart,
      // Per càlculs interns mantenim el rang ordenat,
      // però pels colors del mapa mantenim l'ordre temporal.
      chartRangeStartIndex: start,
      selectionEndIndex: realEnd,
      chartRangeEndIndex: index,
      snappedPointIndex: index,
      snappedPoint: point,
      isSelectingRange: false,
      chartSelectionMode: 'range',
      forceHideReticle: false,
    );
  }

  /// 🔴 FIXAR EL PUNT FINAL (Es crida en prémer el botó flotant per segon cop)
  void fixRangeEndIndex() {
    if (state.selectionStartIndex == null || state.snappedPointIndex == null)
      return;

    fixRangeEndIndexAt(
      index: state.snappedPointIndex!,
      point: state.snappedPoint,
    );
  }

  /// 🧹 NETEJA ABSOLUTA AL SORTIR (Retorna l'estat a la factoria inicial en tancar l'APK)
  void clearAllTracksAbsolute() {
    state = GpxEditorState.initial();
  }
} // Tancament oficial de la classe GpxEditor
