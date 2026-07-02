import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_state.dart';

// Indispensable per a la generació de codi de Riverpod 2
part 'gpx_editor_notifier.g.dart';

/// 🧠 CONTROLADOR EN RIVERPOD 2: Gestiona la lògica de negoci, retícula i talls de Trackio
@riverpod
class GpxEditor extends _$GpxEditor {
  @override
  GpxEditorState build() {
    return GpxEditorState.initial();
  }

  final Set<int> _deployedTrackIds = {};

  /// Guarda el controlador del mapa en el estado global
  void setMapController(MapLibreMapController controller) {
    state = state.copyWith(mapController: controller);
    _updateMapLayers();
  }

  /// Seleccionar un track de la llista per activar-lo al mapa
  void selectTrack(int? trackId) {
    state = state.copyWith(
      selectedTrackId: trackId,
      snappedPoint: null,
      snappedPointIndex: null,
      selectionStartIndex: null,
      selectionEndIndex: -1, // Reseteo explícito del tramo en el copyWith
      isSelectingRange: false,
      forceHideReticle: false,
      isMapIdle: false,
    );
    _updateMapLayers();
  }

  /// Seleccionar track, engrosar visualmente su línea y enfocar la cámara
  void selectTrackAndFocus(int? trackId) {
    selectTrack(trackId);
    if (trackId == null || state.mapController == null) return;

    final track = state.tracks.firstWhere((t) => t.id == trackId);
    if (track.points.isEmpty) return;

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
    _updateMapLayers();
  }

  /// TOGGLE DEL GRÀFIC D'ELEVACIONS
  void toggleElevationChart() {
    state = state.copyWith(showElevationChart: !state.showElevationChart);
  }

  /// Canviar d'eina activa (ej: 'split', 'merge', 'range_map', 'none')
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
    _updateMapLayers();
  }

  void setMapIdle(bool isIdle) {
    state = state.copyWith(isMapIdle: isIdle);
  }

  void updateSnappedPoint(TrackPointModel? point, int? index) {
    state = state.copyWith(snappedPoint: point, snappedPointIndex: index);
  }

  // =========================================================================
  // 📏 LOGICA DE SELECCIÓN DE TRAMOS (MÁQUINA DE ESTADOS RECTÍCULA)
  // =========================================================================

  /// SELECCIÓ DES DEL GRÀFIC (Click & Drag en Web o LongPress en Mòbils)
  void setRangeFromChart(int start, int end) {
    state = state.copyWith(selectionStartIndex: start, selectionEndIndex: end);
    _updateMapLayers();
  }

  /// REACCIONS AL MOVIMENT DEL MAPA (Muestra la retícula oculta)
  void handleMapMovement() {
    setMapIdle(false);
    if (state.forceHideReticle) {
      state = state.copyWith(forceHideReticle: false);
    }
  }

  /// SELECCIÓ DES DEL MAPA AMB RETÍCULA (Secuencia de 3 puntos)
  void handleMapPointSelection() {
    print(
      "🟦 handleMapPointSelection() → snapped=${state.snappedPointIndex}, start=${state.selectionStartIndex}, end=${state.selectionEndIndex}, isSelecting=${state.isSelectingRange}",
    );

    if (state.snappedPointIndex == null) {
      print("❌ snappedPointIndex és null → no faig res");
      return;
    }

    final int currentIndex = state.snappedPointIndex!;
    print("🎯 currentIndex=$currentIndex");

    // 1️⃣ Punt inicial
    if (state.selectionStartIndex == null && !state.isSelectingRange) {
      print("🟢 FASE 1 → Fixant punt inicial");
      state = state.copyWith(
        selectionStartIndex: currentIndex,
        isSelectingRange: true,
        forceHideReticle: false,
      );
      print(
        "➡️ Nou estat: start=${state.selectionStartIndex}, isSelecting=${state.isSelectingRange}",
      );
      _updateMapLayers();
      return;
    }

    // 2️⃣ Punt final
    if (state.selectionStartIndex != null && state.isSelectingRange) {
      print("🟠 FASE 2 → Fixant punt final");
      final int start = state.selectionStartIndex!;
      final int realStart = start < currentIndex ? start : currentIndex;
      final int realEnd = start < currentIndex ? currentIndex : start;

      print("📏 realStart=$realStart realEnd=$realEnd");

      state = state.copyWith(
        selectionStartIndex: realStart,
        selectionEndIndex: realEnd,
        isSelectingRange: false,
        forceHideReticle: false,
      );

      print(
        "➡️ Nou estat: start=${state.selectionStartIndex}, end=${state.selectionEndIndex}, isSelecting=${state.isSelectingRange}",
      );
      _updateMapLayers();
      return;
    }

    // 3️⃣ Nou tram després de tenir un tram complet
    if (state.selectionStartIndex != null &&
        state.selectionEndIndex != null &&
        !state.isSelectingRange) {
      print("🔵 FASE 3 → Reiniciant per seleccionar un nou tram");
      state = state.copyWith(
        selectionStartIndex: currentIndex,
        selectionEndIndex: -1,
        isSelectingRange: true,
        forceHideReticle: false,
      );
      print(
        "➡️ Nou estat: start=${state.selectionStartIndex}, end=${state.selectionEndIndex}, isSelecting=${state.isSelectingRange}",
      );
      _updateMapLayers();
      return;
    }

    print(
      "⚪ No ha entrat en cap fase → estat actual: start=${state.selectionStartIndex}, end=${state.selectionEndIndex}, isSelecting=${state.isSelectingRange}",
    );
  }

  // =========================================================================
  // ✂️ ACCIONES DE EDICIÓN SOBRE EL TRAMO SELECCIONADO
  // =========================================================================

  /// ACCIÓN: ELIMINAR EL TRAMO SELECCIONADO
  void deleteSelectedRange() {
    if (state.selectedTrackId == null ||
        state.selectionStartIndex == null ||
        state.selectionEndIndex == null)
      return;

    final int start = state.selectionStartIndex!;
    final int end = state.selectionEndIndex!;
    final List<TrackModel> updatedTracks = List.from(state.tracks);

    final trackIndex = updatedTracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    if (trackIndex == -1) return;

    final targetTrack = updatedTracks[trackIndex];
    final pointsPartA = targetTrack.points.sublist(0, start + 1);
    final pointsPartB = targetTrack.points.sublist(end);

    targetTrack.name = "${targetTrack.name} (Part A)";
    targetTrack.points = pointsPartA;

    final trackPartB = TrackModel(
      name: "${targetTrack.name} (Part B)",
      hexColor: "#FF9500",
      points: pointsPartB,
    )..id = DateTime.now().millisecondsSinceEpoch;

    updatedTracks.add(trackPartB);

    state = state.copyWith(
      tracks: updatedTracks,
      selectedTrackId: targetTrack.id,
      selectionStartIndex: null,
      selectionEndIndex: -1,
      activeTool: 'none',
    );
    _updateMapLayers();
  }

  /// ACCIÓN: INVERTIR SENTIDO ÚNICAMENTE DEL TRAMO SELECCIONADO
  void reverseSelectedRange() {
    if (state.selectedTrackId == null ||
        state.selectionStartIndex == null ||
        state.selectionEndIndex == null)
      return;

    final int start = state.selectionStartIndex!;
    final int end = state.selectionEndIndex!;

    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == state.selectedTrackId) {
          final rangePoints = track.points.sublist(start, end + 1);
          final reversedRange = List<TrackPointModel>.from(
            rangePoints.reversed,
          );
          track.points.replaceRange(start, end + 1, reversedRange);
        }
        return track;
      }).toList(),
    );
    _updateMapLayers();
  }

  // =========================================================================
  // ALGORITMES DE RECONSTRUCCIÓ GEOJSON (PINTAT OPTIMITZAT)
  // =========================================================================

  /// INVERTIR TRACK SELECCIONAT
  void reverseCurrentTrack() {
    if (state.selectedTrackId == null) return;

    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == state.selectedTrackId) {
          // Creem una nova instància del model per respectar la immutabilitat d'Isar
          return track.copyWith(points: track.points.reversed.toList());
        }
        return track;
      }).toList(),
    );
    _updateMapLayers();
  }

  /// CORTAR TRACK (SPLIT)
  void splitCurrentTrack() {
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

    final pointsPartA = originalTrack.points.sublist(0, cutIndex + 1);
    final pointsPartB = originalTrack.points.sublist(cutIndex);

    // Modificació segura creant instàncies netes
    originalTrack.name = "${originalTrack.name} (Parte A)";
    originalTrack.points = pointsPartA;

    final trackPartB =
        TrackModel(
            name:
                "${originalTrack.name.replaceAll(' (Parte A)', '')} (Parte B)",
            hexColor: "#AF52DE",
            points: pointsPartB,
            waypoints: [],
          )
          ..id = DateTime.now()
              .microsecondsSinceEpoch; // microsegons eviten IDs duplicats

    updatedTracks.add(trackPartB);

    state = state.copyWith(
      tracks: updatedTracks,
      selectedTrackId: originalTrack.id,
      snappedPoint: null,
      snappedPointIndex: null,
    );
    _updateMapLayers();
  }

  /// UNIR DOS TRACKS (MERGE)
  void mergeTracks(int secondTrackId) {
    if (state.selectedTrackId == null || state.selectedTrackId == secondTrackId)
      return;

    final List<TrackModel> updatedTracks = List.from(state.tracks);
    final indexA = updatedTracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );
    final indexB = updatedTracks.indexWhere((t) => t.id == secondTrackId);
    if (indexA == -1 || indexB == -1) return;

    final trackA = updatedTracks[indexA];
    final trackB = updatedTracks[indexB];

    // Combinació eficient de llistes
    trackA.points = [...trackA.points, ...trackB.points];
    trackA.waypoints = [...trackA.waypoints, ...trackB.waypoints];
    trackA.name = "${trackA.name} + ${trackB.name}";

    // Netegem la capa del track que desapareix abans de treure'l de la llista
    if (state.mapController != null) {
      try {
        state.mapController!.removeLayer("layer_${trackB.id}");
        state.mapController!.removeSource("source_${trackB.id}");
      } catch (_) {}
    }

    updatedTracks.removeAt(indexB);

    state = state.copyWith(
      tracks: updatedTracks,
      selectedTrackId: trackA.id,
      activeTool: 'none',
    );
    _updateMapLayers();
  }

  void addImportedTracks(List<TrackModel> newTracks) {
    print(
      "📥 [IMPORT] addImportedTracks cridat amb ${newTracks.length} tracks.",
    );
    for (var t in newTracks) {
      print(
        "   ↳ Track detectat: '${t.name}' amb ${t.points.length} punts. ID: ${t.id}",
      );
    }

    state = state.copyWith(
      tracks: [...state.tracks, ...newTracks],
      selectedTrackId:
          state.selectedTrackId ??
          (newTracks.isNotEmpty ? newTracks.first.id : null),
    );

    print(
      "📥 [IMPORT] Estat de Riverpod actualitzat. selectedTrackId actual: ${state.selectedTrackId}",
    );

    // Cridem directament sense retards per veure la traça immediata
    _updateMapLayers();
  }

  void _updateMapLayers() {
    final controller = state.mapController;
    if (controller == null) return;

    // 1️⃣ Esborrem totes les capes d'estat
    for (final track in state.tracks) {
      final String layerId = "layer_${track.id}";
      final String sourceId = "source_${track.id}";
      try {
        controller.removeLayer(layerId);
      } catch (_) {}
      try {
        controller.removeSource(sourceId);
      } catch (_) {}
    }
    try {
      controller.removeLayer("layer_range_white");
    } catch (_) {}
    try {
      controller.removeLayer("layer_range_orange");
    } catch (_) {}
    try {
      controller.removeSource("source_range");
    } catch (_) {}
    try {
      controller.removeLayer("layer_snapped_circle");
    } catch (_) {}
    try {
      controller.removeSource("source_snapped_point");
    } catch (_) {}

    // 2️⃣ Dibuixem els tracks base visibles
    for (final track in state.tracks) {
      if (!track.isVisible || track.points.isEmpty) continue;

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
        controller.addSource(sourceId, GeojsonSourceProperties(data: geojson));
        controller.addLayer(
          sourceId,
          layerId,
          LineLayerProperties(
            lineColor: track.hexColor,
            lineWidth: isSelected ? 5.5 : 3.0,
            lineJoin: "round",
            lineCap: "round",
          ),
          // ✅ CORREGIT: Eliminem 'belowLayerId' perquè MapLibre web pugui dibuixar la línia neta a l'acte
        );
      } catch (e) {
        print("Error injectant track original: $e");
      }
    }

    // 3️⃣ Dibuixem el tram seleccionat dinàmic
    final trackId = state.selectedTrackId;
    final int? start = state.selectionStartIndex;
    final bool isSelecting = state.isSelectingRange;
    final int? end = isSelecting
        ? state.snappedPointIndex
        : state.selectionEndIndex;

    if (trackId != null && start != null && end != null && end >= 0) {
      final track = state.tracks.firstWhere((t) => t.id == trackId);
      final int lo = start < end ? start : end;
      final int hi = start < end ? end : start;

      if (hi < track.points.length) {
        final List<List<double>> segment = [];
        for (int i = lo; i <= hi; i++) {
          final p = track.points[i];
          if (p.longitude != null && p.latitude != null) {
            segment.add([p.longitude!, p.latitude!]);
          }
        }

        final Map<String, dynamic> rangeGeoJson = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {},
              "geometry": {"type": "LineString", "coordinates": segment},
            },
          ],
        };

        try {
          controller.addSource(
            "source_range",
            GeojsonSourceProperties(data: rangeGeoJson),
          );
          controller.addLineLayer(
            "source_range",
            "layer_range_white",
            const LineLayerProperties(
              lineColor: "#FFFFFF",
              lineWidth: 7.0,
              lineJoin: "round",
              lineCap: "round",
            ),
          );
          controller.addLineLayer(
            "source_range",
            "layer_range_orange",
            const LineLayerProperties(
              lineColor: "#FF8800",
              lineWidth: 3.5,
              lineDasharray: [2, 2],
              lineJoin: "round",
              lineCap: "round",
            ),
          );
        } catch (e) {
          print("Error creant capa de selecció: $e");
        }
      }
    }

    // 4️⃣ CAPA SUPERIOR (A DALT DE TOT): EL CERCLE BLAU DE SNAPPING
    if (state.activeTool == 'range_map' && state.snappedPoint != null) {
      final sPoint = state.snappedPoint!;
      if (sPoint.longitude != null && sPoint.latitude != null) {
        final Map<String, dynamic> pointGeoJson = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {},
              "geometry": {
                "type": "Point",
                "coordinates": [sPoint.longitude!, sPoint.latitude!],
              },
            },
          ],
        };

        try {
          controller.addSource(
            "source_snapped_point",
            GeojsonSourceProperties(data: pointGeoJson),
          );
          controller.addCircleLayer(
            "source_snapped_point",
            "layer_snapped_circle",
            const CircleLayerProperties(
              circleColor: "#007AFF",
              circleRadius: 8.0,
              circleStrokeColor: "#FFFFFF",
              circleStrokeWidth: 2.0,
              circleOpacity: 0.9,
            ),
          );
        } catch (_) {}
      }
    }
  }

  void calculateSnapping(
    double centerLat,
    double centerLng,
    double currentZoom,
  ) {
    if (state.tracks.isEmpty) return;

    int step = 1;
    if (currentZoom < 9) {
      step = 16;
    } else if (currentZoom < 11) {
      step = 8;
    } else if (currentZoom < 13) {
      step = 4;
    } else if (currentZoom < 15) {
      step = 2;
    }

    const double maxToleranceDegrees = 0.0018;
    final double maxToleranceSquared =
        maxToleranceDegrees * maxToleranceDegrees;
    final bool isRangeMapMode = state.activeTool == 'range_map';

    if (state.activeTool == 'split' || isRangeMapMode) {
      if (state.selectedTrackId == null) return;

      final activeTrack = state.tracks.firstWhere(
        (t) => t.id == state.selectedTrackId,
        orElse: () => state.tracks.first,
      );

      double minDistance = double.infinity;
      TrackPointModel? closestPoint;
      int closestIndex = -1;

      final points = activeTrack.points;
      final int pointsLength = points.length;

      for (int i = 0; i < pointsLength; i += step) {
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

      if (isRangeMapMode && closestPoint != null && closestIndex >= 0) {
        state = state.copyWith(
          snappedPoint: closestPoint,
          snappedPointIndex: closestIndex,
        );
      } else if (minDistance < maxToleranceSquared) {
        state = state.copyWith(
          snappedPoint: closestPoint,
          snappedPointIndex: closestIndex,
        );
      } else {
        state = state.copyWith(snappedPoint: null, snappedPointIndex: null);
      }
    }
  }

  void toggleTrackVisibility(int trackId) {
    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == trackId) {
          track.isVisible = !track.isVisible; // Modifica el color
        }
        return track;
      }).toList(), // Força a crear una llista totalment nova a la memòria
    );
    _updateMapLayers();
  }

  void updateTrackColor(int trackId, String hexColor) {
    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == trackId) {
          track.hexColor = hexColor; // Modifica la visibilitat
        }
        return track;
      }).toList(), // Força a crear una llista totalment nova a la memòria
    );
    _updateMapLayers();
  }
}
