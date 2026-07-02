import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart'; // 🆕 Importamos el motor del mapa
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_state.dart';

// Indispensable per a la generació de codi de Riverpod 2
part 'gpx_editor_notifier.g.dart';

/// 🧠 CONTROLADOR EN RIVERPOD 2: Gestiona la lògica de negoci de Trackio
@riverpod
class GpxEditor extends _$GpxEditor {
  /// El mètode build() substitueix el constructor i defineix l'estat inicial
  @override
  GpxEditorState build() {
    return GpxEditorState.initial();
  }

  /// 🛠️ 1. NUEVO: Guarda el controlador del mapa en el estado global
  void setMapController(MapLibreMapController controller) {
    state = state.copyWith(mapController: controller);
    _updateMapLayers(); // Intenta pintar de inmediato si ya existen tracks
  }

  /// Seleccionar un track de la llista per activar-lo al mapa
  void selectTrack(int? trackId) {
    state = state.copyWith(
      selectedTrackId: trackId,
      snappedPoint: null,
      snappedPointIndex: null,
    );
  }

  /// 🔄 2. NUEVO: Seleccionar track, engrosar visualmente su línea y enfocar la cámara
  void selectTrackAndFocus(int? trackId) {
    selectTrack(trackId);

    if (trackId == null || state.mapController == null) return;

    // Buscamos el track seleccionado dentro del listado en memoria
    final track = state.tracks.firstWhere((t) => t.id == trackId);
    if (track.points.isEmpty) return;

    // Algoritmo rápido para calcular el punto central medio y desplazar la cámara allí
    double sumLat = 0;
    double sumLng = 0;
    int validPoints = 0;

    for (final p in track.points) {
      if (p.latitude != null && p.longitude != null) {
        sumLat += p.latitude!;
        sumLng += p.longitude!;
        validPoints++;
      }
    }

    if (validPoints > 0) {
      state.mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(sumLat / validPoints, sumLng / validPoints),
        ),
      );
    }

    _updateMapLayers(); // Refresca los grosores e hilos en el mapa nativo
  }

  /// Canviar d'eina activa (ej: 'split', 'merge', 'inverse', 'none')
  void setActiveTool(String tool) {
    state = state.copyWith(
      activeTool: tool,
      snappedPoint: null,
      snappedPointIndex: null,
    );
  }

  /// Controlar si el mapa està quiet o en moviment
  void setMapIdle(bool isIdle) {
    state = state.copyWith(isMapIdle: isIdle);
  }

  /// Actualitzar el punt d'imantació (snapping) calculat pel mapa
  void updateSnappedPoint(TrackPointModel? point, int? index) {
    state = state.copyWith(snappedPoint: point, snappedPointIndex: index);
  }

  // =========================================================================
  // ALGORITMES D'EDICIÓ (REGLAS DE NEGOCIO)
  // =========================================================================

  /// ↩️ INVERTIR TRACK SELECCIONAT
  void reverseCurrentTrack() {
    if (state.selectedTrackId == null) return;

    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == state.selectedTrackId) {
          final reversedPoints = List<TrackPointModel>.from(
            track.points.reversed,
          );
          track.points = reversedPoints;
        }
        return track;
      }).toList(),
    );
    _updateMapLayers(); // 🆕 Refrescamos el mapa tras invertir la geometría
  }

  /// ✂️ CORTAR TRACK (SPLIT)
  void splitCurrentTrack() {
    if (state.selectedTrackId == null || state.snappedPointIndex == null) {
      return;
    }

    final int cutIndex = state.snappedPointIndex!;
    final List<TrackModel> updatedTracks = List.from(state.tracks);

    final trackIndex = updatedTracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    if (trackIndex == -1) return;

    final targetTrack = updatedTracks[trackIndex];
    if (cutIndex <= 0 || cutIndex >= targetTrack.points.length - 1) return;

    final pointsPartA = targetTrack.points.sublist(0, cutIndex + 1);
    final pointsPartB = targetTrack.points.sublist(cutIndex);

    final trackPartB = TrackModel(
      name: "${targetTrack.name} (Parte B)",
      hexColor: "#AF52DE",
      points: pointsPartB,
      waypoints: [],
    )..id = DateTime.now().millisecondsSinceEpoch;

    targetTrack.name = "${targetTrack.name} (Parte A)";
    targetTrack.points = pointsPartA;
    updatedTracks.add(trackPartB);

    state = state.copyWith(
      tracks: updatedTracks,
      selectedTrackId: targetTrack.id,
      snappedPoint: null,
      snappedPointIndex: null,
    );
    _updateMapLayers(); // 🆕 Redibujamos las capas resultantes tras el tijerazo
  }

  /// 🔗 UNIR DOS TRACKS (MERGE)
  void mergeTracks(int secondTrackId) {
    if (state.selectedTrackId == null ||
        state.selectedTrackId == secondTrackId) {
      return;
    }

    final List<TrackModel> updatedTracks = List.from(state.tracks);

    final indexA = updatedTracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    final indexB = updatedTracks.indexWhere((t) => t.id == secondTrackId);
    if (indexA == -1 || indexB == -1) return;

    final trackA = updatedTracks[indexA];
    final trackB = updatedTracks[indexB];

    final combinedPoints = <TrackPointModel>[
      ...trackA.points,
      ...trackB.points,
    ];
    final combinedWaypoints = <WaypointModel>[
      ...trackA.waypoints,
      ...trackB.waypoints,
    ];

    // Buscamos y removemos del mapa de forma nativa la capa B que va a desaparecer
    if (state.mapController != null) {
      try {
        state.mapController!.removeLayer("layer_${trackB.id}");
        state.mapController!.removeSource("source_${trackB.id}");
      } catch (_) {}
    }

    trackA.points = combinedPoints;
    trackA.waypoints = combinedWaypoints;
    trackA.name = "${trackA.name} + ${trackB.name}";

    updatedTracks.removeAt(indexB);

    state = state.copyWith(
      tracks: updatedTracks,
      selectedTrackId: trackA.id,
      activeTool: 'none',
    );
    _updateMapLayers(); // 🆕 Refrescamos el nuevo trazo fusionado continuo
  }

  /// 🗂️ Inyecta una lista de tracks directamente en el Gestor de Capas
  void addImportedTracks(List<TrackModel> newTracks) {
    state = state.copyWith(
      tracks: [...state.tracks, ...newTracks],
      selectedTrackId:
          state.selectedTrackId ??
          (newTracks.isNotEmpty ? newTracks.first.id : null),
    );
    _updateMapLayers(); // 🆕 Pintar en el mapa de forma inmediata al importar
  }

  /// 🖌️ 3. NUEVO: Transforma los tracks activos en GeoJSON válidos y los inyecta en MapLibre GL
  /// 🖌️ Transforma los tracks activos en GeoJSON y los inyecta de forma segura en MapLibre GL
  void _updateMapLayers() {
    final controller = state.mapController;

    // Si el mapa aún no está enlazado o está inicializándose en Chrome, abortamos pacíficamente
    if (controller == null) {
      debugPrint(
        "⚠️ [TRACKIO] Intento de pintado abortado: El controlador del mapa aún no está listo.",
      );
      return;
    }

    for (final track in state.tracks) {
      final String sourceId = "source_${track.id}";
      final String layerId = "layer_${track.id}";

      final geojson = {
        "type": "Feature",
        "properties": {},
        "geometry": {
          "type": "LineString",
          "coordinates": track.points
              .where((p) => p.longitude != null && p.latitude != null)
              .map((p) => [p.longitude!, p.latitude!])
              .toList(),
        },
      };

      try {
        final bool isSelected = track.id == state.selectedTrackId;

        // Limpieza controlada de fuentes previas
        try {
          controller.removeLayer(layerId);
          controller.removeSource(sourceId);
        } catch (_) {}

        if (track.isVisible && track.points.isNotEmpty) {
          // Inyectamos el JSON nativo en el hilo de renderizado de CanvasKit
          controller.addSource(
            sourceId,
            GeojsonSourceProperties(data: geojson),
          );
          controller.addLayer(
            sourceId,
            layerId,
            LineLayerProperties(
              lineColor: track.hexColor,
              lineWidth: isSelected ? 5.0 : 3.0,
              lineJoin: "round",
              lineCap: "round",
            ),
          );
          debugPrint(
            "🎨 [TRACKIO] Capa '$layerId' pintada en el mapa con éxito.",
          );
        }
      } catch (e) {
        debugPrint("Error gestionando capas GeoJSON de MapLibre: $e");
      }
    }
  }

  /// 🎯 ALGORITMO DE IMÁN (SNAPPING) AVANZADO MULTI-TRACK
  void calculateSnapping(double centerLat, double centerLng) {
    if (state.tracks.isEmpty) return;

    const double maxToleranceDegrees = 0.0018;
    final double maxToleranceSquared =
        maxToleranceDegrees * maxToleranceDegrees;

    // ✂️ CASO A: HERRAMIENTA DE RECORTE (SPLIT)
    if (state.activeTool == 'split') {
      if (state.selectedTrackId == null) return;
      final trackIndex = state.tracks.indexWhere(
        (t) => t.id == state.selectedTrackId,
      );
      if (trackIndex == -1) return;

      final activeTrack = state.tracks[trackIndex];
      double minDistance = double.infinity;
      TrackPointModel? closestPoint;
      int closestIndex = -1;

      for (int i = 0; i < activeTrack.points.length; i++) {
        final point = activeTrack.points[i];
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

      if (minDistance < maxToleranceSquared) {
        state = state.copyWith(
          snappedPoint: closestPoint,
          snappedPointIndex: closestIndex,
        );
      } else {
        state = state.copyWith(snappedPoint: null, snappedPointIndex: null);
      }
      return;
    }

    // 🔗 CASO B: HERRAMIENTA DE UNIÓN (MERGE)
    if (state.activeTool == 'merge') {
      double minDistance = double.infinity;
      TrackPointModel? closestEndMultiplierPoint;
      int targetTrackIdForMerge = -1;
      for (final track in state.tracks) {
        if (track.id == state.selectedTrackId ||
            !track.isVisible ||
            track.points.isEmpty) {
          continue;
        }
        final pointsToCheck = [track.points.first, track.points.last];
        for (final point in pointsToCheck) {
          if (point.latitude == null || point.longitude == null) continue;
          final double dLat = point.latitude! - centerLat;
          final double dLng = point.longitude! - centerLng;
          final double distance = dLat * dLat + dLng * dLng;
          if (distance < minDistance) {
            minDistance = distance;
            closestEndMultiplierPoint = point;
            targetTrackIdForMerge = track.id;
          }
        }
      }
      if (minDistance < maxToleranceSquared) {
        state = state.copyWith(
          snappedPoint: closestEndMultiplierPoint,
          snappedPointIndex: targetTrackIdForMerge,
        );
      } else {
        state = state.copyWith(snappedPoint: null, snappedPointIndex: null);
      }
    }
  }

  /// 👁️ Commuta la visibilitat d'un track (Amagar / Mostrar)
  void toggleTrackVisibility(int trackId) {
    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == trackId) {
          track.isVisible = !track.isVisible;
        }
        return track;
      }).toList(),
    );
    _updateMapLayers(); // 🔄 Forcem a MapLibre a redibuixar el mapa i aplicar el canvi
  }

  /// 🎨 Canvia el color d'un track de forma individualitzada
  void updateTrackColor(int trackId, String hexColor) {
    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == trackId) {
          track.hexColor = hexColor;
        }
        return track;
      }).toList(),
    );
    _updateMapLayers(); // 🔄 Forcem a MapLibre a pintar la línia amb el nou color
  }
}
