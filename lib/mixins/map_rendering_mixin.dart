import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_state.dart';

mixin MapRenderingMixin {
  // Aquest mixin obligarà la pantalla a oferir accés al controlador del mapa
  MapLibreMapController? get controller;
  bool _paintingTracks = false;

  static const List<String> _globalOverlayLayerOrder = [
    "layer_range_white",
    "layer_range_orange",
    "layer_snapped_circle",
    "layer_start_circle",
    "layer_end_circle",
  ];

  String? _overlayAnchorLayerId(Set<String> existingLayers) {
    for (final layerId in _globalOverlayLayerOrder) {
      if (existingLayers.contains(layerId)) {
        return layerId;
      }
    }
    return null;
  }

  // 🌟 REPARACIÓ: Eliminem el 'async' de la capçalera per fer el flux síncron i fluid
  void paintLiveOverlays(GpxEditorState state, {LatLng? reticleLatLng}) {
    if (controller == null) {
      return;
    }

    const Map<String, dynamic> emptyCollection = {
      "type": "FeatureCollection",
      "features": [],
    };

    // ========================= DRAW =========================
    if (state.activeTool == 'draw') {
      // 🌟 REPARACIÓ: Traiem el 'await' de totes aquestes línies de moviment continu
      controller!.setGeoJsonSource("source_start_range", emptyCollection);
      controller!.setGeoJsonSource("source_end_range", emptyCollection);

      if (state.drawingPoints.isEmpty && state.drawingLivePoint == null) {
        controller!.setGeoJsonSource("source_range", emptyCollection);
        controller!.setGeoJsonSource("source_snapped_point", emptyCollection);
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

          controller!.setGeoJsonSource("source_snapped_point", {
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
        controller!.setGeoJsonSource("source_snapped_point", emptyCollection);
      }

      if (drawCoords.length >= 2) {
        controller!.setGeoJsonSource("source_range", {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": drawCoords},
            },
          ],
        });
      } else {
        controller!.setGeoJsonSource("source_range", emptyCollection);
      }
      return;
    }

    // ========================= OTHER TOOLS =========================
    if (state.selectedTrackId == null) return;

    final int? activeTrackId = int.tryParse(state.selectedTrackId.toString());
    final trackIndex = state.tracks.indexWhere((t) => t.id == activeTrackId);
    if (trackIndex == -1) return;

    final track = state.tracks[trackIndex];
    final int? snappedIndex = state.snappedPointIndex;

    int lo = 0;
    int hi = snappedIndex ?? 0;

    // ------------------ GESTIÓ EXCLUSIVA DEL PUNT BLAU MÒBIL ------------------
    if (state.activeTool == 'range_map') {
      controller!.setGeoJsonSource("source_snapped_point", emptyCollection);
    } else {
      if (state.snappedPoint != null) {
        final p = state.snappedPoint!;
        // 🌟 SENSE AWAIT: El cercle blau rep les dades de cop i llisca sense parpellejar
        controller!.setGeoJsonSource("source_snapped_point", {
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
        controller!.setGeoJsonSource("source_snapped_point", emptyCollection);
      }
    }

    // ------------------ MERGE ------------------
    if (state.activeTool == 'merge') {
      if (state.previewPoints != null && state.previewPoints!.isNotEmpty) {
        final previewCoords = state.previewPoints!
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => [p.longitude!, p.latitude!])
            .toList();

        controller!.setGeoJsonSource("source_range", {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": previewCoords},
            },
          ],
        });
      } else {
        controller!.setGeoJsonSource("source_range", emptyCollection);
      }
      return;
    }

    // ------------------ RANGE_MAP UNIFICAT I DINÀMIC ------------------
    if (state.activeTool == 'range_map' || state.activeTool == 'range_chart') {
      final int? startPointToPaint = state.chartRangeStartIndex;
      final int? endPointToPaint = state.chartRangeEndIndex;

      // 🟢 1. Pintar cercle verd (Inici del Rang)
      if (startPointToPaint != null &&
          startPointToPaint >= 0 &&
          startPointToPaint < track.points.length) {
        final pStart = track.points[startPointToPaint];
        controller!.setGeoJsonSource("source_start_range", {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [pStart.longitude!, pStart.latitude!],
              },
            },
          ],
        });
      } else {
        controller!.setGeoJsonSource("source_start_range", emptyCollection);
      }

      // 🔴 2. Pintar cercle vermell (Final del Rang)
      if (endPointToPaint != null &&
          endPointToPaint >= 0 &&
          endPointToPaint < track.points.length) {
        final pEnd = track.points[endPointToPaint];
        controller!.setGeoJsonSource("source_end_range", {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [pEnd.longitude!, pEnd.latitude!],
              },
            },
          ],
        });
      } else {
        controller!.setGeoJsonSource("source_end_range", emptyCollection);
      }

      if (startPointToPaint != null && endPointToPaint != null) {
        lo = startPointToPaint;
        hi = endPointToPaint;
      } else {
        controller!.setGeoJsonSource("source_range", emptyCollection);
        return;
      }
    }
    // ------------------ SPLIT ------------------
    else if (state.activeTool == 'split') {
      controller!.setGeoJsonSource("source_start_range", emptyCollection);
      controller!.setGeoJsonSource("source_end_range", emptyCollection);

      if (snappedIndex == null) {
        controller!.setGeoJsonSource("source_range", emptyCollection);
        return;
      }
      lo = 0;
      hi = snappedIndex;
    }
    // ------------------ NETEJA ABSOLUTA SI L'EINA ÉS 'NONE' O ALTRA ------------------
    else {
      controller!.setGeoJsonSource("source_range", emptyCollection);
      controller!.setGeoJsonSource("source_start_range", emptyCollection);
      controller!.setGeoJsonSource("source_end_range", emptyCollection);

      // 🌟 REPARACIÓ: Si hi ha un punt blau actiu a la memòria en cicle lliure ('none'),
      // bloquegem que aquesta clàusula el buidi en el mateix frame per evitar pampallugues.
      if (state.snappedPoint == null) {
        controller!.setGeoJsonSource("source_snapped_point", emptyCollection);
      }
      return;
    }

    // ========================= BUILD SEGMENT =========================
    final segment = <List>[];
    for (int i = lo; i <= hi; i++) {
      if (i >= track.points.length) break;
      final p = track.points[i];
      if (p.longitude != null && p.latitude != null) {
        segment.add([p.longitude!, p.latitude!]);
      }
    }

    // bloc 2
    final bool shouldExtendToReticle =
        reticleLatLng != null &&
        (state.activeTool == 'split' || state.activeTool == 'range_map');
    if (shouldExtendToReticle) {
      segment.add([reticleLatLng.longitude, reticleLatLng.latitude]);
    }

    if (segment.length >= 2) {
      controller!.setGeoJsonSource("source_range", {
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
      controller!.setGeoJsonSource("source_range", emptyCollection);
    }
  }

  Future<void> createGlobalLayers() async {
    if (controller == null) return;

    try {
      final Set<String> existingSources = (await controller!.getSourceIds())
          .cast<String>()
          .toSet();

      final Set<String> existingLayers = (await controller!.getLayerIds())
          .cast<String>()
          .toSet();

      // ============================================================
      // SOURCE + LAYERS RANGE
      // ============================================================

      if (!existingSources.contains("source_range")) {
        await controller!.addSource(
          "source_range",
          const GeojsonSourceProperties(
            data: {"type": "FeatureCollection", "features": []},
          ),
        );
        existingSources.add("source_range");
      }

      if (!existingLayers.contains("layer_range_white")) {
        await controller!.addLineLayer(
          "source_range",
          "layer_range_white",
          const LineLayerProperties(lineColor: "#FFFFFF", lineWidth: 6.5),
        );
        existingLayers.add("layer_range_white");
      }

      if (!existingLayers.contains("layer_range_orange")) {
        await controller!.addLineLayer(
          "source_range",
          "layer_range_orange",
          const LineLayerProperties(
            lineColor: "#FF8800",
            lineWidth: 3.5,
            lineDasharray: [3.0, 2.5],
          ),
        );
        existingLayers.add("layer_range_orange");
      }

      // ============================================================
      // PUNT BLAU SNAP
      // ============================================================

      if (!existingSources.contains("source_snapped_point")) {
        await controller!.addSource(
          "source_snapped_point",
          const GeojsonSourceProperties(
            data: {"type": "FeatureCollection", "features": []},
          ),
        );
        existingSources.add("source_snapped_point");
      }

      if (!existingLayers.contains("layer_snapped_circle")) {
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
        existingLayers.add("layer_snapped_circle");
      }

      // ============================================================
      // CERCLE VERD - INICI RANG
      // ============================================================

      if (!existingSources.contains("source_start_range")) {
        await controller!.addSource(
          "source_start_range",
          const GeojsonSourceProperties(
            data: {"type": "FeatureCollection", "features": []},
          ),
        );
        existingSources.add("source_start_range");
      }

      if (!existingLayers.contains("layer_start_circle")) {
        await controller!.addCircleLayer(
          "source_start_range",
          "layer_start_circle",
          const CircleLayerProperties(
            circleColor: "#4CAF50",
            circleRadius: 9.0,
            circleStrokeColor: "#FFFFFF",
            circleStrokeWidth: 2.5,
          ),
        );
        existingLayers.add("layer_start_circle");
      }

      // ============================================================
      // CERCLE VERMELL - FINAL RANG
      // ============================================================

      if (!existingSources.contains("source_end_range")) {
        await controller!.addSource(
          "source_end_range",
          const GeojsonSourceProperties(
            data: {"type": "FeatureCollection", "features": []},
          ),
        );
        existingSources.add("source_end_range");
      }

      if (!existingLayers.contains("layer_end_circle")) {
        await controller!.addCircleLayer(
          "source_end_range",
          "layer_end_circle",
          const CircleLayerProperties(
            circleColor: "#F44336",
            circleRadius: 9.0,
            circleStrokeColor: "#FFFFFF",
            circleStrokeWidth: 2.5,
          ),
        );
        existingLayers.add("layer_end_circle");
      }
    } catch (e) {
      debugPrint("🟥 createGlobalLayers ERROR CONTROLAT: $e");
    }
  }

  Future<void> paintTracks(List<TrackModel> tracks, int? activeTrackId) async {
    if (controller == null) {
      return;
    }

    // 🔒 Evita dues pintades simultànies (molt freqüent en Flutter Web)
    if (_paintingTracks) {
      return;
    }

    _paintingTracks = true;

    try {
      final List<String> currentLayers = (await controller!.getLayerIds())
          .cast<String>();

      final Set<String> currentLayerSet = currentLayers.toSet();

      final Set<String> existingSourceSet = (await controller!.getSourceIds())
          .cast<String>()
          .toSet();

      final List<TrackModel> tracksToPaint = [];

      for (final track in tracks) {
        if (track.points.isEmpty) {
          continue;
        }

        final sourceId = "source_${track.id}";
        final waypointSourceId = "source_wp_${track.id}";

        final coords = track.points
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => [p.longitude!, p.latitude!])
            .toList();

        if (coords.isEmpty) {
          continue;
        }

        tracksToPaint.add(track);

        final waypointCoords = track.waypoints
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => [p.longitude!, p.latitude!])
            .toList();

        final trackGeojson = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": coords},
            },
          ],
        };

        final waypointGeojson = {
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

        // ============================================================
        // SOURCES
        // ============================================================

        if (existingSourceSet.contains(sourceId)) {
          await controller!.setGeoJsonSource(sourceId, trackGeojson);
        } else {
          try {
            await controller!.addSource(
              sourceId,
              GeojsonSourceProperties(data: trackGeojson),
            );
            existingSourceSet.add(sourceId);
          } catch (_) {
            await controller!.setGeoJsonSource(sourceId, trackGeojson);
          }
        }

        if (existingSourceSet.contains(waypointSourceId)) {
          await controller!.setGeoJsonSource(waypointSourceId, waypointGeojson);
        } else {
          try {
            await controller!.addSource(
              waypointSourceId,
              GeojsonSourceProperties(data: waypointGeojson),
            );
            existingSourceSet.add(waypointSourceId);
          } catch (_) {
            await controller!.setGeoJsonSource(
              waypointSourceId,
              waypointGeojson,
            );
          }
        }
      }

      // Reordenem sempre les capes de tracks perquè segueixin exactament l'ordre del sidebar.
      for (final track in tracksToPaint) {
        final layerId = "layer_${track.id}";
        final glowWhiteLayerId = "layer_glow_white_${track.id}";
        final glowYellowLayerId = "layer_glow_yellow_${track.id}";
        final waypointLayerId = "layer_wp_${track.id}";

        final List<String> layersToRemove = [
          waypointLayerId,
          layerId,
          glowYellowLayerId,
          glowWhiteLayerId,
        ];

        for (final id in layersToRemove) {
          if (currentLayerSet.contains(id)) {
            try {
              await controller!.removeLayer(id);
            } catch (_) {}
            currentLayerSet.remove(id);
          }
        }
      }

      String? insertionAnchorLayerId = _overlayAnchorLayerId(currentLayerSet);

      for (final track in tracksToPaint) {
        final sourceId = "source_${track.id}";
        final layerId = "layer_${track.id}";
        final glowWhiteLayerId = "layer_glow_white_${track.id}";
        final glowYellowLayerId = "layer_glow_yellow_${track.id}";
        final waypointSourceId = "source_wp_${track.id}";
        final waypointLayerId = "layer_wp_${track.id}";

        final bool isActiveTrack = track.id == activeTrackId;
        final bool shouldShowGlow = isActiveTrack && track.isVisible;

        // De dalt a baix per track: waypoints, línia base, glow groc, glow blanc.
        await controller!.addCircleLayer(
          waypointSourceId,
          waypointLayerId,
          CircleLayerProperties(
            circleColor: isActiveTrack ? "#FFEB3B" : "#FFFFFF",
            circleRadius: 6.0,
            circleStrokeColor: track.hexColor,
            circleStrokeWidth: 2.0,
            circleOpacity: track.isVisible ? 1.0 : 0.0,
            circleStrokeOpacity: track.isVisible ? 1.0 : 0.0,
          ),
          belowLayerId: insertionAnchorLayerId,
        );
        insertionAnchorLayerId = waypointLayerId;
        currentLayerSet.add(waypointLayerId);

        await controller!.addLineLayer(
          sourceId,
          layerId,
          LineLayerProperties(
            lineColor: track.hexColor,
            lineWidth: 3.5,
            lineOpacity: track.isVisible ? 1.0 : 0.0,
          ),
          belowLayerId: insertionAnchorLayerId,
        );
        insertionAnchorLayerId = layerId;
        currentLayerSet.add(layerId);

        if (shouldShowGlow) {
          await controller!.addLineLayer(
            sourceId,
            glowYellowLayerId,
            const LineLayerProperties(
              lineColor: "#FFEB3B",
              lineWidth: 6.0,
              lineJoin: "round",
              lineCap: "round",
              lineOpacity: 1.0,
            ),
            belowLayerId: insertionAnchorLayerId,
          );
          insertionAnchorLayerId = glowYellowLayerId;
          currentLayerSet.add(glowYellowLayerId);

          await controller!.addLineLayer(
            sourceId,
            glowWhiteLayerId,
            const LineLayerProperties(
              lineColor: "#FFFFFF",
              lineWidth: 8.5,
              lineJoin: "round",
              lineCap: "round",
              lineOpacity: 1.0,
            ),
            belowLayerId: insertionAnchorLayerId,
          );
          insertionAnchorLayerId = glowWhiteLayerId;
          currentLayerSet.add(glowWhiteLayerId);
        }
      }
    } catch (e) {
      debugPrint("🟥 paintTracks ERROR CONTROLAT: $e");
    } finally {
      _paintingTracks = false;
    }
  }
}
