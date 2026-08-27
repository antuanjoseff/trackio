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
    "layer_waypoint_highlight",
    "layer_start_circle",
    "layer_end_circle",
    "layer_geometry_nodes",
  ];

  String? _overlayAnchorLayerId(Set<String> existingLayers) {
    for (final layerId in _globalOverlayLayerOrder) {
      if (existingLayers.contains(layerId)) {
        return layerId;
      }
    }
    return null;
  }

  void clearGeometryNodesOverlay() {
    if (controller == null) return;
    const Map<String, dynamic> emptyCollection = {
      "type": "FeatureCollection",
      "features": [],
    };
    controller!.setGeoJsonSource("source_geometry_nodes", emptyCollection);
  }

  void setGeometryNodesOverlay(
    List<({int index, TrackPointModel point})> nodes,
  ) {
    if (controller == null) return;

    final features = nodes
        .where((n) => n.point.latitude != null && n.point.longitude != null)
        .map(
          (n) => {
            "type": "Feature",
            "properties": {"index": n.index},
            "geometry": {
              "type": "Point",
              "coordinates": [n.point.longitude!, n.point.latitude!],
            },
          },
        )
        .toList();

    controller!.setGeoJsonSource("source_geometry_nodes", {
      "type": "FeatureCollection",
      "features": features,
    });
  }

  void clearWaypointHighlight() {
    if (controller == null) return;
    const Map<String, dynamic> emptyCollection = {
      "type": "FeatureCollection",
      "features": [],
    };
    controller!.setGeoJsonSource("source_waypoint_highlight", emptyCollection);
  }

  void setWaypointHighlight(LatLng waypoint) {
    if (controller == null) return;
    controller!.setGeoJsonSource("source_waypoint_highlight", {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [waypoint.longitude, waypoint.latitude],
          },
        },
      ],
    });
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

    if (state.activeTool != 'edit_geometry') {
      clearGeometryNodesOverlay();
    }

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
      final int? rawStart =
          state.chartRangeStartIndex ?? state.selectionStartIndex;
      final int? rawEnd = state.chartRangeEndIndex ?? state.selectionEndIndex;

      // Respectem l'ordre temporal de fixació:
      // start = primer punt fixat (verd), end = segon punt fixat (vermell).
      final int? startPointToPaint = rawStart;
      final int? endPointToPaint = rawEnd;

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
        lo = startPointToPaint < endPointToPaint
            ? startPointToPaint
            : endPointToPaint;
        hi = startPointToPaint < endPointToPaint
            ? endPointToPaint
            : startPointToPaint;
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

      if (state.activeTool == 'edit_geometry') {
        return;
      }

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

      if (!existingSources.contains("source_waypoint_highlight")) {
        await controller!.addSource(
          "source_waypoint_highlight",
          const GeojsonSourceProperties(
            data: {"type": "FeatureCollection", "features": []},
          ),
        );
        existingSources.add("source_waypoint_highlight");
      }

      if (!existingLayers.contains("layer_waypoint_highlight")) {
        await controller!.addCircleLayer(
          "source_waypoint_highlight",
          "layer_waypoint_highlight",
          const CircleLayerProperties(
            circleColor: "#FFD54F",
            circleRadius: 11.0,
            circleStrokeColor: "#FFFFFF",
            circleStrokeWidth: 2.5,
            circleOpacity: 0.95,
          ),
        );
        existingLayers.add("layer_waypoint_highlight");
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

      if (!existingSources.contains("source_geometry_nodes")) {
        await controller!.addSource(
          "source_geometry_nodes",
          const GeojsonSourceProperties(
            data: {"type": "FeatureCollection", "features": []},
          ),
        );
        existingSources.add("source_geometry_nodes");
      }

      if (!existingLayers.contains("layer_geometry_nodes")) {
        await controller!.addCircleLayer(
          "source_geometry_nodes",
          "layer_geometry_nodes",
          const CircleLayerProperties(
            circleColor: "#FFFFFF",
            circleRadius: 5.0,
            circleStrokeColor: "#1A73E8",
            circleStrokeWidth: 2.0,
            circleOpacity: 0.95,
          ),
        );
        existingLayers.add("layer_geometry_nodes");
      }
    } catch (e) {
      debugPrint("🟥 createGlobalLayers ERROR CONTROLAT: $e");
    }
  }

  Future<void> paintTracks(List<TrackModel> tracks, int? activeTrackId) async {
    if (controller == null) return;

    if (_paintingTracks) return;

    _paintingTracks = true;

    try {
      final existingLayers = (await controller!.getLayerIds())
          .cast<String>()
          .toSet();

      final existingSources = (await controller!.getSourceIds())
          .cast<String>()
          .toSet();

      // ============================================================
      // 1) ELIMINAR TRACKS QUE JA NO EXISTEIXEN
      // ============================================================

      final visibleTrackIds = tracks.map((t) => t.id).toSet();

      final obsoleteLayerIds = existingLayers.where((layerId) {
        if (!layerId.startsWith("layer_") &&
            !layerId.startsWith("layer_wp_") &&
            !layerId.startsWith("layer_glow_")) {
          return false;
        }

        final idString = layerId
            .replaceFirst("layer_glow_white_", "")
            .replaceFirst("layer_glow_yellow_", "")
            .replaceFirst("layer_wp_", "")
            .replaceFirst("layer_", "");

        final id = int.tryParse(idString);

        return id != null && !visibleTrackIds.contains(id);
      }).toList();

      for (final layerId in obsoleteLayerIds) {
        try {
          await controller!.removeLayer(layerId);
        } catch (_) {}
      }

      final obsoleteSourceIds = existingSources.where((sourceId) {
        if (!sourceId.startsWith("source_") &&
            !sourceId.startsWith("source_wp_")) {
          return false;
        }

        final idString = sourceId
            .replaceFirst("source_wp_", "")
            .replaceFirst("source_", "");

        final id = int.tryParse(idString);

        return id != null && !visibleTrackIds.contains(id);
      }).toList();

      for (final sourceId in obsoleteSourceIds) {
        try {
          await controller!.removeSource(sourceId);
        } catch (_) {}
      }

      // ============================================================
      // 2) PINTAR TRACKS ACTUALS
      // ============================================================

      final List<TrackModel> tracksToPaint = [];

      for (final track in tracks) {
        if (track.points.isEmpty) continue;

        final sourceId = "source_${track.id}";
        final waypointSourceId = "source_wp_${track.id}";

        final coords = track.points
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => [p.longitude!, p.latitude!])
            .toList();

        if (coords.isEmpty) continue;

        tracksToPaint.add(track);

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
          "features": track.waypoints
              .asMap()
              .entries
              .where(
                (entry) =>
                    entry.value.latitude != null &&
                    entry.value.longitude != null,
              )
              .map(
                (entry) => {
                  "type": "Feature",
                  "properties": {
                    "track_id": track.id,
                    "waypoint_index": entry.key,
                    "waypoint_id": "${track.id}_${entry.key}",
                  },
                  "geometry": {
                    "type": "Point",
                    "coordinates": [
                      entry.value.longitude!,
                      entry.value.latitude!,
                    ],
                  },
                },
              )
              .toList(),
        };

        if (existingSources.contains(sourceId)) {
          await controller!.setGeoJsonSource(sourceId, trackGeojson);
        } else {
          await controller!.addSource(
            sourceId,
            GeojsonSourceProperties(data: trackGeojson),
          );

          existingSources.add(sourceId);
        }

        if (existingSources.contains(waypointSourceId)) {
          await controller!.setGeoJsonSource(waypointSourceId, waypointGeojson);
        } else {
          await controller!.addSource(
            waypointSourceId,
            GeojsonSourceProperties(data: waypointGeojson),
          );

          existingSources.add(waypointSourceId);
        }
      }

      // ============================================================
      // 3) RECREAR ORDRE DE CAPES
      // ============================================================

      final currentLayerIds = (await controller!.getLayerIds())
          .cast<String>()
          .toSet();

      String? insertionAnchorLayerId = _overlayAnchorLayerId(currentLayerIds);

      for (final track in tracksToPaint) {
        final layerId = "layer_${track.id}";
        final waypointLayerId = "layer_wp_${track.id}";
        final glowWhite = "layer_glow_white_${track.id}";
        final glowYellow = "layer_glow_yellow_${track.id}";

        for (final id in [waypointLayerId, layerId, glowYellow, glowWhite]) {
          if (currentLayerIds.contains(id)) {
            try {
              await controller!.removeLayer(id);
            } catch (_) {}
          }
        }

        final active = track.id == activeTrackId;

        final showGlow = active && track.isVisible;

        await controller!.addCircleLayer(
          "source_wp_${track.id}",
          waypointLayerId,
          CircleLayerProperties(
            circleColor: active ? "#FFFFFF" : "#FFFFFF",
            circleRadius: active ? 9 : 8,
            circleStrokeColor: track.hexColor,
            circleStrokeWidth: 2,
            circleOpacity: track.isVisible ? 1 : 0,
          ),
          belowLayerId: insertionAnchorLayerId,
        );

        insertionAnchorLayerId = waypointLayerId;

        await controller!.addLineLayer(
          "source_${track.id}",
          layerId,
          LineLayerProperties(
            lineColor: track.hexColor,
            lineWidth: active ? 5.5 : 3.5,
            lineOpacity: track.isVisible ? 1 : 0,
            lineCap: "round",
            lineJoin: "round",
          ),
          belowLayerId: insertionAnchorLayerId,
        );

        insertionAnchorLayerId = layerId;

        if (showGlow) {
          await controller!.addLineLayer(
            "source_${track.id}",
            glowWhite,
            const LineLayerProperties(
              lineColor: "#000000",
              lineWidth: 9.5,
              lineOpacity: 0.85,
              lineCap: "round",
              lineJoin: "round",
            ),
            belowLayerId: insertionAnchorLayerId,
          );

          insertionAnchorLayerId = glowWhite;
        }
      }
    } catch (e) {
      debugPrint("paintTracks ERROR: $e");
    } finally {
      _paintingTracks = false;
    }
  }
}
