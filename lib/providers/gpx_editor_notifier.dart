import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_state.dart';

part 'gpx_editor_notifier.g.dart';

@riverpod
class GpxEditor extends _$GpxEditor {
  @override
  GpxEditorState build() {
    return GpxEditorState.initial();
  }

  /// Selecciona el track en el estado global.
  void selectTrack(int? trackId) {
    state = state.copyWith(
      selectedTrackId: trackId,
      snappedPoint: null,
      snappedPointIndex: null,
      selectionStartIndex: null,
      selectionEndIndex: -1,
      isSelectingRange: false,
      forceHideReticle: false,
      isMapIdle: false,
    );
  }

  void setActiveTool(String tool) {
    state = state.copyWith(
      activeTool: tool,
      snappedPoint: null,
      snappedPointIndex: null,
      selectionStartIndex: null,
      selectionEndIndex: -1,
      isSelectingRange: false,
      forceHideReticle: false,
      isMapIdle: false,
    );
  }

  void setMapIdle(bool isIdle) {
    state = state.copyWith(isMapIdle: isIdle);
  }

  void updateSnappedPoint(TrackPointModel? point, int? index) {
    state = state.copyWith(snappedPoint: point, snappedPointIndex: index);
  }

  void toggleElevationChart() {
    state = state.copyWith(showElevationChart: !state.showElevationChart);
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

  void addImportedTracks(List<TrackModel> newTracks) {
    // 🔒 GENERACIÓ D'IDS SEGURS: Assegurem enters únics de 64 bits nets i forcem la instanciació de llista nova
    final List<TrackModel> fixed = [];
    int baseTimestamp = DateTime.now().microsecondsSinceEpoch;

    for (int i = 0; i < newTracks.length; i++) {
      final track = newTracks[i];
      // Modifiquem l'ID creant una nova referència immutable transparent per a Isar i Riverpod
      track.id = baseTimestamp + i;
      fixed.add(track);
    }

    // Actualitzem l'estat forçant a crear una llista totalment nova a la memòria
    state = state.copyWith(
      tracks: [...state.tracks, ...fixed],
      // Seleccionem obligatòriament el primer track importat per activar la reactivitat visual de la llista
      selectedTrackId: fixed.first.id,
    );

    // Print de depuració per confirmar que les dades entren correctament al proveïdor
    debugPrint(
      "📥 RIVERPOD: S'han afegit ${fixed.length} tracks a l'estat. Total actual: ${state.tracks.length}",
    );
  }

  // =========================================================================
  // 📏 LÒGICA MATEMÀTICA DE SNAPPING (DINS DEL FITXER CENTRAL)
  // =========================================================================
  void calculateSnapping(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.tracks.isEmpty || state.selectedTrackId == null) return;

    final bool isSplitMode = state.activeTool == 'split';
    final bool isRangeMapMode = state.activeTool == 'range_map';
    if (!isSplitMode && !isRangeMapMode) return;

    // 🔒 SENSE BLOCATGES: Deixem que el càlcul s'execute sempre en moure el mapa.
    // Així el cercle blau reaccionarà sempre, tant per a 'split' com per a 'range_map' [1.1].
    int step = 1;
    if (currentZoom < 9)
      step = 16;
    else if (currentZoom < 11)
      step = 8;
    else if (currentZoom < 13)
      step = 4;
    else if (currentZoom < 15)
      step = 2;

    final int? activeTrackId = int.tryParse(state.selectedTrackId.toString());
    final trackIndex = state.tracks.indexWhere((t) => t.id == activeTrackId);
    if (trackIndex == -1) return;

    final activeTrack = state.tracks[trackIndex];
    final points = activeTrack.points;
    if (points.isEmpty) return;

    double minDistance = double.infinity;
    TrackPointModel? closestPoint;
    int closestIndex = -1;

    for (int i = 0; i < points.length; i += step) {
      final point = points[i];
      if (point.latitude == null || point.longitude == null) continue;

      final double dLat = point.latitude! - centerLat;
      final double dLng = point.longitude! - centerLng;
      final double distance = dLat * dLat + dLng * dLng;

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
        closestIndex = i;
      }
    }

    if (closestPoint != null && closestIndex >= 0) {
      state = state.copyWith(
        snappedPoint: closestPoint,
        snappedPointIndex: closestIndex,
      );
    } else {
      state = state.copyWith(snappedPoint: null, snappedPointIndex: null);
    }
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

    updatedTracks.removeAt(trackIndex);
    updatedTracks.add(trackPart1);
    updatedTracks.add(trackPart2);

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
}
