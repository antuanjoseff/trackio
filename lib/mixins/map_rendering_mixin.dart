import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_state.dart';

mixin MapRenderingMixin {
  // Aquest mixin obligarà la pantalla a oferir accés al controlador del mapa
  MapLibreMapController? get controller;

  void paintLiveOverlays(GpxEditorState state, {LatLng? reticleLatLng}) async {
    if (controller == null) {
      return;
    }

    const Map<String, dynamic> emptyCollection = {
      "type": "FeatureCollection",
      "features": [],
    };

    // ========================= DRAW =========================
    if (state.activeTool == 'draw') {
      if (state.drawingPoints.isEmpty && state.drawingLivePoint == null) {
        await controller!.setGeoJsonSource("source_range", emptyCollection);
        await controller!.setGeoJsonSource(
          "source_snapped_point",
          emptyCollection,
        );
        return;
      }

      final drawCoords = <List<double>>[];
      for (final p in state.drawingPoints) {
        if (p.latitude != null && p.longitude != null) {
          drawCoords.add([p.longitude!, p.latitude!]);
        }
      }

      if (state.drawingLivePoint != null) {
        final live = state.drawingLivePoint!;
        if (live.latitude != null && live.longitude != null) {
          drawCoords.add([live.longitude!, live.latitude!]);

          await controller!.setGeoJsonSource("source_snapped_point", {
            "type": "FeatureCollection",
            "features": [
              {
                "type": "Feature",
                "geometry": {
                  "type": "Point",
                  "coordinates": [live.longitude!, live.latitude!],
                },
              },
            ],
          });
        }
      } else {
        await controller!.setGeoJsonSource(
          "source_snapped_point",
          emptyCollection,
        );
      }

      if (drawCoords.length >= 2) {
        await controller!.setGeoJsonSource("source_range", {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": drawCoords},
            },
          ],
        });
      } else {
        await controller!.setGeoJsonSource("source_range", emptyCollection);
      }
      return;
    }

    // ========================= OTHER TOOLS =========================

    if (state.selectedTrackId == null) {
      return;
    }

    final int? activeTrackId = int.tryParse(state.selectedTrackId.toString());
    final trackIndex = state.tracks.indexWhere((t) => t.id == activeTrackId);
    if (trackIndex == -1) {
      return;
    }

    final track = state.tracks[trackIndex];
    final int? snappedIndex = state.snappedPointIndex;

    // ------------------ POINT BLUE ------------------
    if (state.snappedPoint != null) {
      final p = state.snappedPoint!;

      await controller!.setGeoJsonSource("source_snapped_point", {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [p.longitude!, p.latitude!],
            },
          },
        ],
      });
    } else {
      await controller!.setGeoJsonSource(
        "source_snapped_point",
        emptyCollection,
      );
    }

    int lo = 0;
    int hi = snappedIndex ?? 0;

    // ------------------ MERGE ------------------
    if (state.activeTool == 'merge') {
      if (state.previewPoints != null && state.previewPoints!.isNotEmpty) {
        final previewCoords = state.previewPoints!
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => [p.longitude!, p.latitude!])
            .toList();

        await controller!.setGeoJsonSource("source_range", {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": previewCoords},
            },
          ],
        });
      } else {
        await controller!.setGeoJsonSource("source_range", emptyCollection);
      }
      return;
    }

    // ------------------ RANGE_MAP ------------------
    if (state.activeTool == 'range_map') {
      // 1️⃣ Fase Inicial: Si encara no s'ha triat cap punt d'origen, esborrem el tram efímer i marxem
      if (state.selectionStartIndex == null) {
        await controller!.setGeoJsonSource("source_range", emptyCollection);
        return;
      }

      // 2️⃣ Fase Final (Tram Tancat): Tenim origen i final consolidats i ja no estem arrossegant
      if (state.selectionStartIndex != null &&
          state.selectionEndIndex != null &&
          state.selectionEndIndex != -1 &&
          !state.isSelectingRange) {
        lo = state.selectionStartIndex!;
        hi = state.selectionEndIndex!;
      }
      // 3️⃣ Fase d'Espera Elàstica: L'usuari ha fixat l'origen i està movent el mapa buscant el final
      else {
        // Si el mapa s'està movent per una zona buida i el SNAP falla, usem l'últim conegut
        // o simplement no pintem la línia elàstica fins que s'imanti a un altre node proper.
        if (snappedIndex == null) {
          return;
        }

        final int start = state.selectionStartIndex!;
        // Ordenem els indexos de forma dinàmica per si l'usuari arrossega cap enrere del track original
        lo = start < snappedIndex ? start : snappedIndex;
        hi = start < snappedIndex ? snappedIndex : start;
      }
    }
    // ------------------ SPLIT ------------------
    else if (state.activeTool == 'split') {
      if (snappedIndex == null) {
        await controller!.setGeoJsonSource("source_range", emptyCollection);
        return;
      }
      lo = 0;
      hi = snappedIndex;
    } else {
      await controller!.setGeoJsonSource("source_range", emptyCollection);
      return;
    }

    // ------------------ BUILD SEGMENT ------------------
    final segment = <List>[];
    for (int i = lo; i <= hi; i++) {
      if (i >= track.points.length) break;
      final p = track.points[i];
      if (p.longitude != null && p.latitude != null) {
        segment.add([p.longitude!, p.latitude!]);
      }
    }

    final bool shouldExtendToReticle =
        reticleLatLng != null &&
        (state.activeTool == 'split' || state.activeTool == 'range_map');

    if (shouldExtendToReticle) {
      segment.add([reticleLatLng.longitude, reticleLatLng.latitude]);
    }

    if (segment.length >= 2) {
      await controller!.setGeoJsonSource("source_range", {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": List<List>.from(segment),
            },
          },
        ],
      });
    } else {
      await controller!.setGeoJsonSource("source_range", emptyCollection);
    }
  }

  Future<void> createGlobalLayers() async {
    if (controller == null) return;
    try {
      await controller!.addSource(
        "source_range",
        const GeojsonSourceProperties(
          data: {"type": "FeatureCollection", "features": []},
        ),
      );
      await controller!.addLineLayer(
        "source_range",
        "layer_range_white",
        const LineLayerProperties(lineColor: "#FFFFFF", lineWidth: 6.5),
      );
      await controller!.addLineLayer(
        "source_range",
        "layer_range_orange",
        const LineLayerProperties(
          lineColor: "#FF8800",
          lineWidth: 3.5,
          lineDasharray: [3.0, 2.5],
        ),
      );
    } catch (_) {}

    try {
      await controller!.addSource(
        "source_snapped_point",
        const GeojsonSourceProperties(
          data: {"type": "FeatureCollection", "features": []},
        ),
      );
      await controller!.addCircleLayer(
        "source_snapped_point",
        "layer_snapped_circle",
        const CircleLayerProperties(
          circleColor: "#007AFF",
          circleRadius: 9.0,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2.5,
        ),
      );
    } catch (_) {}
  }

  Future<void> paintTracks(List<TrackModel> tracks, int? activeTrackId) async {
    if (controller == null) {
      return;
    }

    final Set<String> wantedLayerIds = tracks
        .expand(
          (track) => [
            "layer_${track.id}",
            "layer_glow_white_${track.id}",
            "layer_glow_yellow_${track.id}",
            "layer_wp_${track.id}",
          ],
        )
        .toSet();

    try {
      final List<String> currentLayers = (await controller!.getLayerIds())
          .cast<String>();
      final Set<String> currentLayerSet = currentLayers.toSet();

      for (final layerId in currentLayers) {
        if (layerId.startsWith("layer_") &&
            layerId != "layer_range_white" &&
            layerId != "layer_range_orange" &&
            layerId != "layer_snapped_circle" &&
            !wantedLayerIds.contains(layerId)) {
          try {
            await controller!.removeLayer(layerId);
          } catch (_) {}
        }
      }

      final Set<String> existingSourceSet = (await controller!.getSourceIds())
          .cast<String>()
          .toSet();

      for (final track in tracks) {
        if (track.points.isEmpty) {
          continue;
        }

        final sourceId = "source_${track.id}";
        final layerId = "layer_${track.id}";
        final glowWhiteLayerId = "layer_glow_white_${track.id}";
        final glowYellowLayerId = "layer_glow_yellow_${track.id}";
        final waypointSourceId = "source_wp_${track.id}";
        final waypointLayerId = "layer_wp_${track.id}";

        final coords = track.points
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => [p.longitude!, p.latitude!])
            .toList();

        final waypointCoords = track.waypoints
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => [p.longitude!, p.latitude!])
            .toList();

        if (coords.isEmpty) {
          continue;
        }

        final Map<String, dynamic> trackGeojson = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": coords},
            },
          ],
        };

        final Map<String, dynamic> waypointGeojson = {
          "type": "FeatureCollection",
          "features": waypointCoords
              .map(
                (c) => {
                  "type": "Feature",
                  "geometry": {"type": "Point", "coordinates": c},
                },
              )
              .toList(),
        };

        // SOURCE TRACK
        if (existingSourceSet.contains(sourceId)) {
          await controller!.setGeoJsonSource(sourceId, trackGeojson);
        } else {
          await controller!.addSource(
            sourceId,
            GeojsonSourceProperties(data: trackGeojson),
          );
          existingSourceSet.add(sourceId);
        }

        // SOURCE WAYPOINTS
        if (existingSourceSet.contains(waypointSourceId)) {
          await controller!.setGeoJsonSource(waypointSourceId, waypointGeojson);
        } else {
          await controller!.addSource(
            waypointSourceId,
            GeojsonSourceProperties(data: waypointGeojson),
          );
          existingSourceSet.add(waypointSourceId);
        }

        // REMOVE OLD LAYERS
        for (final lid in [layerId, glowWhiteLayerId, glowYellowLayerId]) {
          if (currentLayerSet.contains(lid)) {
            try {
              await controller!.removeLayer(lid);
            } catch (_) {}
          }
        }

        final bool isActiveTrack = track.id == activeTrackId;
        // GLOW WHITE
        if (isActiveTrack && track.isVisible) {
          await controller!.addLineLayer(
            sourceId,
            glowWhiteLayerId,
            const LineLayerProperties(
              lineColor: "#FFFFFF",
              lineWidth: 8.5,
              lineJoin: "round",
              lineCap: "round",
            ),
            belowLayerId: "layer_range_white",
          );
          currentLayerSet.add(glowWhiteLayerId);
        }

        // GLOW YELLOW
        if (isActiveTrack && track.isVisible) {
          await controller!.addLineLayer(
            sourceId,
            glowYellowLayerId,
            const LineLayerProperties(
              lineColor: "#FFEB3B",
              lineWidth: 6.0,
              lineJoin: "round",
              lineCap: "round",
            ),
            belowLayerId: "layer_range_white",
          );
          currentLayerSet.add(glowYellowLayerId);
        }

        // MAIN TRACK LAYER
        await controller!.addLineLayer(
          sourceId,
          layerId,
          LineLayerProperties(
            lineColor: track.hexColor,
            lineWidth: 3.5,
            lineOpacity: track.isVisible ? 1.0 : 0.0,
          ),
          belowLayerId: "layer_range_white",
        );
        currentLayerSet.add(layerId);

        // WAYPOINT LAYER
        if (currentLayerSet.contains(waypointLayerId)) {
          try {
            await controller!.removeLayer(waypointLayerId);
          } catch (_) {}
        }

        await controller!.addCircleLayer(
          waypointSourceId,
          waypointLayerId,
          CircleLayerProperties(
            circleColor: isActiveTrack ? "#FFEB3B" : "#FFFFFF",
            circleRadius: isActiveTrack ? 6.0 : 4.5,
            circleStrokeColor: track.hexColor,
            circleStrokeWidth: 2.0,
            circleOpacity: track.isVisible ? 1.0 : 0.0,
            circleStrokeOpacity: track.isVisible ? 1.0 : 0.0,
          ),
        );
        currentLayerSet.add(waypointLayerId);
      }
    } catch (e) {
      debugPrint("🟥 paintTracks ERROR: $e");
    }
  }
}
