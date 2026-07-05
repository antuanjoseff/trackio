import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
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

  // Mantenim el teu mètode original de tota la vida intacte:
  void addImportedTracks(List<TrackModel> newTracks) {
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
    );
  }

  // =========================================================================
  // 📏 LÒGICA MATEMÀTICA DE SNAPPING (DINS DEL FITXER CENTRAL)
  // =========================================================================
  // Dins del teu GpxEditor Notifier

  void calculateSnapping(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.tracks.isEmpty || state.selectedTrackId == null) return;

    final bool isSplitMode = state.activeTool == 'split';
    final bool isRangeMapMode = state.activeTool == 'range_map';
    final bool isMergeMode = state.activeTool == 'merge'; // 🌟 Nova eina
    if (!isSplitMode && !isRangeMapMode && !isMergeMode) return;

    // 🔒 SENSE BLOCATGES: Mantenim el teu càlcul de pas (step) segons el zoom original
    int step = 1;
    if (currentZoom < 9)
      step = 16;
    else if (currentZoom < 11)
      step = 8;
    else if (currentZoom < 13)
      step = 4;
    else if (currentZoom < 15)
      step = 2;

    // =========================================================================
    // 🤝 BLOC NOU: LÒGICA DE PROXIMITAT PER AL MERGE (SORTIDA RÀPIDA)
    // =========================================================================
    if (isMergeMode) {
      double minGlobalDistance = double.infinity;
      int? closestTrackId;
      List<TrackPointModel>? closestTrackPoints;

      for (final track in state.tracks) {
        if (track.id == state.selectedTrackId)
          continue; // Ignorem el track del sidebar

        for (int i = 0; i < track.points.length; i += step) {
          final p = track.points[i];
          if (p.latitude == null || p.longitude == null) continue;

          final double dLat = p.latitude! - centerLat;
          final double dLng = p.longitude! - centerLng;
          final double distance = dLat * dLat + dLng * dLng;

          if (distance < minGlobalDistance) {
            minGlobalDistance = distance;
            closestTrackId = track.id;
            closestTrackPoints = track.points;
          }
        }
      }

      // 🔒 Llindar de distància de seguretat (aprox. 40-50 metres a la realitat)
      const double safetyThreshold = 0.0005;
      if (minGlobalDistance < safetyThreshold &&
          closestTrackId != null &&
          closestTrackPoints != null) {
        if (state.previewTrackId == closestTrackId)
          return; // Ja està previsualitzat, sortim

        final trackA = state.tracks.firstWhere(
          (t) => t.id == state.selectedTrackId,
        );

        // El track seleccionat al sidebar (A) va SEMPRE obligatòriament a l'inici
        final List<TrackPointModel> tempMergedPoints = [
          ...trackA.points,
          ...closestTrackPoints,
        ];

        state = state.copyWith(
          previewTrackId: closestTrackId,
          previewPoints: tempMergedPoints,
          isMapIdle: false,
        );
      } else {
        // Si s'allunya del track o no hi ha res a prop, netegem la previsualització de fons
        if (state.previewTrackId != null) {
          state = state.copyWith(previewTrackId: null, previewPoints: null);
        }
      }
      return; // 🎯 SORTIDA RÀPIDA: Evitem que el merge entri a la lògica de sota
    }

    // =========================================================================
    // ✂️ EL TEU CODI ORIGINAL PER A 'SPLIT' I 'RANGE_MAP' (100% INTACTE)
    // =========================================================================
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

    debugPrint(
      "🤝 MERGE SUCCESS: Creado track unificado conservando los originales.",
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

  /// Es crida quan l'usuari fa el primer toc a la muntanya del gràfic
  void startChartRangeSelection(int index) {
    state = state.copyWith(
      selectionStartIndex: index,
      selectionEndIndex:
          -1, // Netegem qualsevol final anterior (-1 es tradueix a null al teu copyWith)
      isSelectingRange: true,
      snappedPointIndex: index,
    );
  }

  /// Es crida contínuament frame a frame mentre es mou el dit pel perfil d'altituds
  void updateChartRangeSelection(int index, TrackPointModel point) {
    state = state.copyWith(snappedPointIndex: index, snappedPoint: point);
  }

  /// Es crida quan l'usuari aixeca el dit del gràfic, congelant el tram definitiu
  void finalizeChartRangeSelection(int start, int end) {
    state = state.copyWith(
      selectionStartIndex: start < end ? start : end,
      selectionEndIndex: start < end ? end : start,
      isSelectingRange: false,
    );
  }
}
