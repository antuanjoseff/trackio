import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/core/utils/gpx_parser.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/screens/main_editor_layout.dart';
import 'package:trackio/widgets/editor_sidebar_widget.dart';
import 'package:trackio/widgets/static_editor_map_widget.dart';

class MainEditorScreen extends ConsumerStatefulWidget {
  const MainEditorScreen({super.key});

  @override
  ConsumerState<MainEditorScreen> createState() => _MainEditorScreenState();
}

class _MainEditorScreenState extends ConsumerState<MainEditorScreen> {
  Timer? _throttleTimer;
  MapLibreMapController? _controller;
  bool _isReverseAnimating = false;
  static const Duration reverseAnimationDuration = Duration(seconds: 1);
  final GlobalKey _mapKey = GlobalKey(debugLabel: "main_editor_map");

  @override
  void dispose() {
    _throttleTimer?.cancel(); // Neteja el temporitzador de memòria en sortir
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // 🔒 PAS 2: Filtrem l'estat. El build de la pantalla NOMÉS s'executarà si canvia l'eina o el gràfic.
    // Ignorem el moviment continu de píxels de l'snap per salvar el mapa web.
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final showElevationChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );

    final editorState = ref.read(gpxEditorProvider);
    final bool isSplitMode = activeTool == 'split';
    final bool isRangeMode = activeTool == 'range_map';
    final bool isMergeMode = activeTool == 'merge';
    final bool isWaypointMode = activeTool == 'add_waypoint';

    // Afegeix el mode waypoint a la teva variable showReticle existent:
    final bool showReticle =
        isSplitMode || isRangeMode || isMergeMode || isWaypointMode;

    ref.listen<GpxEditorState>(gpxEditorProvider, (previous, next) {
      if (previous?.selectedTrackId != next.selectedTrackId) {
        if (next.selectedTrackId != null) {
          _focusTrack(next.selectedTrackId, next.tracks);
        }
        // 🌟 Forzamos a repintar para mover el efecto de resplandor blanco al nuevo track seleccionado al instante
        _paintTracks(next.tracks);
      }

      // Repintem també quan canvia visibilitat/color/waypoints (no només la longitud).
      if (previous?.tracks != next.tracks && next.loadingTrackIds.isEmpty) {
        _paintTracks(next.tracks);
      }

      if (previous?.snappedPointIndex != next.snappedPointIndex ||
          previous?.snappedPoint != next.snappedPoint) {
        _paintLiveOverlays(next);
      }
    });

    final Widget mapModule = Stack(
      children: [
        StaticEditorMapWidget(
          key: _mapKey,
          onMapCreated: (c) => _controller = c,
          onStyleLoaded: () async {
            await _paintTracks(ref.read(gpxEditorProvider).tracks);
            await _createGlobalLayers();
            await _focusTrack(
              ref.read(gpxEditorProvider).selectedTrackId,
              ref.read(gpxEditorProvider).tracks,
            );
          },
          onCameraMove: (pos) =>
              _handleCameraMove(pos, ref.read(gpxEditorProvider)),
          onCameraIdle: _handleCameraIdle,
        ),

        if (showReticle)
          const Center(
            child: Icon(Icons.add_circle_outline, size: 40, color: Colors.red),
          ),

        // 🎯 PAS 3: Invoquem el nou botó reactiu aïllat
        const _ReactiveSplitButton(),
        const _ReactiveRangeButton(),
        const _ReactiveMergeButton(),
        const _ReactiveWaypointButton(),
      ],
    );

    return MainEditorLayout(
      t: t,
      editorState: editorState,
      mapModule: mapModule,
      showElevationChart: showElevationChart,
      isReverseAnimating: _isReverseAnimating,
      onPaintTracks: _paintTracks,
      onReverseTrack: _reverseSelectedTrackWithAnimation,
      onImportPressed: () => _importGpxFiles(context, ref),
    );
  }

  void _handleCameraMove(CameraPosition pos, GpxEditorState state) {
    // 📍 MODO WAYPOINT OPTIMIZADO CONTRA CONGELAMIENTO
    if (state.activeTool == 'add_waypoint') {
      // 1. Solo cambiamos el flag de reposo si realmente estaba en TRUE, evitando bucles repetitivos de renderizado
      if (state.isMapIdle) {
        ref.read(gpxEditorProvider.notifier).setMapIdle(false);
      }
      return;
    }
    if (state.activeTool != 'split' &&
        state.activeTool != 'range_map' &&
        state.activeTool != 'merge')
      return;

    if (_throttleTimer?.isActive ?? false) return;

    // Throttle real a 60ms
    _throttleTimer = Timer(const Duration(milliseconds: 60), () {
      ref
          .read(gpxEditorProvider.notifier)
          .calculateSnapping(
            pos.target.latitude,
            pos.target.longitude,
            pos.zoom,
          );
      _paintLiveOverlays(
        ref.read(gpxEditorProvider),
      ); // Dibuixa dinàmicament a la GPU ON CAMERA MOVE!
    });
  }

  void _handleCameraIdle() {
    final state = ref.read(gpxEditorProvider);
    // 📍 MODO WAYPOINT CUANDO EL MAPA SE DETIENE POR COMPLETO
    if (state.activeTool == 'add_waypoint') {
      final pos = _controller?.cameraPosition;
      if (pos != null) {
        ref
            .read(gpxEditorProvider.notifier)
            .updateWaypointPosition(pos.target.latitude, pos.target.longitude);
      }
      // Activamos el reposo de forma segura al final para que emerja el botón flotante
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      return;
    }

    // 🌟 REPARAT: Deixem passar també 'merge' quan el mapa es quedi quiet
    if (state.activeTool != 'split' &&
        state.activeTool != 'range_map' &&
        state.activeTool != 'merge')
      return;

    final pos = _controller?.cameraPosition;
    if (pos != null) {
      ref
          .read(gpxEditorProvider.notifier)
          .calculateSnapping(
            pos.target.latitude,
            pos.target.longitude,
            pos.zoom,
          );
    }
    ref.read(gpxEditorProvider.notifier).setMapIdle(true);
    _paintLiveOverlays(ref.read(gpxEditorProvider));
  }

  void _paintLiveOverlays(GpxEditorState state) async {
    if (_controller == null || state.selectedTrackId == null) return;

    final int? activeTrackId = int.tryParse(state.selectedTrackId.toString());
    final trackIndex = state.tracks.indexWhere((t) => t.id == activeTrackId);
    if (trackIndex == -1) return;

    final track = state.tracks[trackIndex];
    final int? snappedIndex = state.snappedPointIndex;
    const Map<String, dynamic> emptyCollection = {
      "type": "FeatureCollection",
      "features": [],
    };

    // 🔵 1) ACTUALITZACIÓ DEL CERCLE BLAU (SEMPRE EN VIU PER A SPLIT I RANGE)
    if (state.snappedPoint != null) {
      final p = state.snappedPoint!;
      if (p.longitude != null && p.latitude != null) {
        final pointGeojson = {
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
        };
        await _controller!.setGeoJsonSource(
          "source_snapped_point",
          pointGeojson,
        );
      }
    } else {
      await _controller!.setGeoJsonSource(
        "source_snapped_point",
        emptyCollection,
      );
    }

    // ✂️ 2) BIFURCACIÓ DE LA LÍNIA DEL TRAM SEGONS L'EINA ACTIVA
    int lo = 0;
    int hi = snappedIndex ?? 0;

    if (state.activeTool == 'merge') {
      // ==========================================
      // 🤝 COMPORTAMENT EN VIU DE L'EINA MERGE
      // ==========================================
      if (state.previewPoints != null && state.previewPoints!.isNotEmpty) {
        final previewCoords = state.previewPoints!
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => [p.longitude!, p.latitude!])
            .toList();

        await _controller!.setGeoJsonSource("source_range", {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": previewCoords},
            },
          ],
        });
      } else {
        // Si no hi ha track proper, esborrem immediatament la previsualització de la GPU
        await _controller!.setGeoJsonSource("source_range", emptyCollection);
      }
      return; // 🎯 Sortida ràpida: Evitem entrar a la lògica de les altres eines de sota
    } else if (state.activeTool == 'range_map') {
      // ==========================================
      // 📊 COMPORTAMENT COMPLET DE L'EINA TRAM
      // ==========================================
      if (state.selectionStartIndex == null) {
        // Fase 1: Sense punt inicial, netegem la línia però no sortim (deixem el cercle blau actiu)
        await _controller!.setGeoJsonSource("source_range", emptyCollection);
        return;
      } else if (state.selectionStartIndex != null &&
          state.selectionEndIndex != null &&
          state.selectionEndIndex != -1 &&
          !state.isSelectingRange) {
        // 🔥 OPCIÓ 2 DETECTADA: TRAM DESAT I FIXAT (Fase 3)
        // Ignorem totalment el 'snappedIndex' de la càmera en moviment.
        // Generem la línia fixa unint els dos punts desats a l'estat perquè no es mogui [1.1].
        lo = state.selectionStartIndex!;
        hi = state.selectionEndIndex!;

        final segment = <List<double>>[];
        for (int i = lo; i <= hi; i++) {
          final p = track.points[i];
          if (p.longitude != null && p.latitude != null)
            segment.add([p.longitude!, p.latitude!]);
        }
        await _controller!.setGeoJsonSource("source_range", {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": segment},
            },
          ],
        });
        return; // Retornem per no deixar que el bucle inferior trepitge aquest dibuix [1.1]
      } else {
        // Fase 2: Selecció activa en moviment. La línia creix fins a la retícula [1.1].
        if (snappedIndex == null) return;
        final int start = state.selectionStartIndex!;
        lo = start < snappedIndex ? start : snappedIndex;
        hi = start < snappedIndex ? snappedIndex : start;
      }
    } else if (state.activeTool == 'split') {
      // ==========================================
      // ✂️ COMPORTAMENT SENSE TOCAR DE L'EINA SPLIT (100% EN VIU)
      // ==========================================
      if (snappedIndex == null) return;
      lo = 0; // L'origen és sempre el punt zero de la ruta [1.1]
      hi = snappedIndex; // El final segueix la retícula a cada frame [1.1]
    } else {
      // Si no hi ha cap eina activa, esborrem i marxem
      await _controller!.setGeoJsonSource("source_range", emptyCollection);
      return;
    }

    // Aquest bucle final només s'executarà per a la selecció elàstica (Fase 2 del range) o per a l'split continu [1.1]
    final segment = <List<double>>[];
    for (int i = lo; i <= hi; i++) {
      final p = track.points[i];
      if (p.longitude != null && p.latitude != null) {
        segment.add([p.longitude!, p.latitude!]);
      }
    }

    await _controller!.setGeoJsonSource("source_range", {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": segment},
        },
      ],
    });
  }

  Future<void> _focusTrack(int? trackId, List<TrackModel> tracks) async {
    if (_controller == null || trackId == null || tracks.isEmpty) return;

    final track = tracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => tracks.first,
    );
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
      await _controller!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(sumLat / validPoints, sumLng / validPoints),
        ),
      );
    }
  }

  Future<void> _createGlobalLayers() async {
    if (_controller == null) return;
    try {
      await _controller!.addSource(
        "source_range",
        const GeojsonSourceProperties(
          data: {"type": "FeatureCollection", "features": []},
        ),
      );

      // Base blanca gruixuda sòlida
      await _controller!.addLineLayer(
        "source_range",
        "layer_range_white",
        const LineLayerProperties(lineColor: "#FFFFFF", lineWidth: 6.5),
      );
      // Línia superior taronja discontínua cridant
      await _controller!.addLineLayer(
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
      await _controller!.addSource(
        "source_snapped_point",
        const GeojsonSourceProperties(
          data: {"type": "FeatureCollection", "features": []},
        ),
      );
      await _controller!.addCircleLayer(
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

  Future<void> _paintTracks(List<TrackModel> tracks) async {
    if (_controller == null) return;

    // 1. Llegim l'id del track que està actiu actualment a Riverpod
    final int? activeTrackId = ref.read(gpxEditorProvider).selectedTrackId;

    // 2. Protegim totes les capes (incloses les dues de contorn actiu) de l'escombrador de la GPU
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

    // 🔥 1) ESCOMBRADOR TOTAL DE SEGURETAT:
    try {
      final List<String> currentLayers = (await _controller!.getLayerIds())
          .cast<String>();
      final Set<String> currentLayerSet = currentLayers.toSet();

      for (final layerId in currentLayers) {
        if (layerId.startsWith("layer_") &&
            layerId != "layer_range_white" &&
            layerId != "layer_range_orange" &&
            layerId != "layer_snapped_circle" &&
            !wantedLayerIds.contains(layerId)) {
          try {
            await _controller!.removeLayer(layerId);
          } catch (_) {}
        }
      }

      // 🔥 2) PINTAT REFRESCAT DELS TRACKS ACTIUS
      final Set<String> existingSourceSet = (await _controller!.getSourceIds())
          .cast<String>()
          .toSet();

      for (final track in tracks) {
        if (track.points.isEmpty) continue;

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

        if (coords.isEmpty) continue;

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

        if (existingSourceSet.contains(sourceId)) {
          await _controller!.setGeoJsonSource(sourceId, trackGeojson);
        } else {
          await _controller!.addSource(
            sourceId,
            GeojsonSourceProperties(data: trackGeojson),
          );
          existingSourceSet.add(sourceId);
        }

        if (existingSourceSet.contains(waypointSourceId)) {
          await _controller!.setGeoJsonSource(
            waypointSourceId,
            waypointGeojson,
          );
        } else {
          await _controller!.addSource(
            waypointSourceId,
            GeojsonSourceProperties(data: waypointGeojson),
          );
          existingSourceSet.add(waypointSourceId);
        }

        // Neteja higiènica de capes antigues per evitar duplicats orfes
        if (currentLayerSet.contains(layerId)) {
          try {
            await _controller!.removeLayer(layerId);
          } catch (_) {}
        }
        if (currentLayerSet.contains(glowWhiteLayerId)) {
          try {
            await _controller!.removeLayer(glowWhiteLayerId);
          } catch (_) {}
        }
        if (currentLayerSet.contains(glowYellowLayerId)) {
          try {
            await _controller!.removeLayer(glowYellowLayerId);
          } catch (_) {}
        }

        final bool isActiveTrack = track.id == activeTrackId;

        // 🌟 CAPA 1 (A BAIX DE TOT): BASE BLANCA ULTRA-GRUIXUDA
        if (isActiveTrack && track.isVisible) {
          await _controller!.addLineLayer(
            sourceId,
            glowWhiteLayerId,
            const LineLayerProperties(
              lineColor: "#FFFFFF",
              lineWidth: 8.5, // El llit blanc exterior més ample
              lineJoin: "round",
              lineCap: "round",
            ),
            belowLayerId: "layer_range_white",
          );
          currentLayerSet.add(glowWhiteLayerId);
        }

        // 🌟 CAPA 2 (AL MIG): PERFIL GROC REFLECTANT
        if (isActiveTrack && track.isVisible) {
          await _controller!.addLineLayer(
            sourceId,
            glowYellowLayerId,
            const LineLayerProperties(
              lineColor: "#FFEB3B", // Groc seguretat
              lineWidth:
                  6.0, // Intermedi per deixar veure la vora blanca de sota
              lineJoin: "round",
              lineCap: "round",
            ),
            belowLayerId:
                "layer_range_white", // Es manté sota les eines, quedant per sobre de la blanca
          );
          currentLayerSet.add(glowYellowLayerId);
        }

        // 🌟 CAPA 3 (A DALT DE TOT): LA TEVA LÍNIA DE COLOR ORIGINAL
        await _controller!.addLineLayer(
          sourceId,
          layerId,
          LineLayerProperties(
            lineColor: track.hexColor,
            lineWidth:
                3.5, // Més estreta per deixar veure els contorns inferiors que sobresurten
            lineOpacity: track.isVisible ? 1.0 : 0.0,
          ),
          belowLayerId:
              "layer_range_white", // Es manté sota les eines, quedant per sobre de la groga i la blanca
        );
        currentLayerSet.add(layerId);

        if (currentLayerSet.contains(waypointLayerId)) {
          try {
            await _controller!.removeLayer(waypointLayerId);
          } catch (_) {}
        }

        await _controller!.addCircleLayer(
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
      debugPrint("Avís netejant capes velles: $e");
    }
  }

  Future<void> _clearTrackAndToolOverlays(int trackId) async {
    if (_controller == null) return;
    const Map<String, dynamic> emptyCollection = {
      "type": "FeatureCollection",
      "features": [],
    };
    await _controller!.setGeoJsonSource("source_$trackId", emptyCollection);
    await _controller!.setGeoJsonSource("source_range", emptyCollection);
    await _controller!.setGeoJsonSource(
      "source_snapped_point",
      emptyCollection,
    );
  }

  Future<void> _animateTrackRedraw(TrackModel track) async {
    if (_controller == null) return;

    final sourceId = "source_${track.id}";
    final validCoords = track.points
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => [p.longitude!, p.latitude!])
        .toList();
    if (validCoords.isEmpty) return;

    const int framesCount = 60;
    final Duration perFrameDelay = reverseAnimationDuration ~/ framesCount;
    final progressive = <List<double>>[];
    final int step = (validCoords.length / framesCount).ceil();

    for (int i = 0; i < validCoords.length; i += step) {
      if (!mounted || _controller == null) return;
      progressive.add(validCoords[i]);

      await _controller!.setGeoJsonSource(sourceId, {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": List<List<double>>.from(progressive),
            },
          },
        ],
      });
      await Future.delayed(perFrameDelay);
    }

    await _controller!.setGeoJsonSource(sourceId, {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": validCoords},
        },
      ],
    });
  }

  Future<void> _reverseSelectedTrackWithAnimation(WidgetRef ref) async {
    if (_controller == null || _isReverseAnimating) return;

    final before = ref.read(gpxEditorProvider);
    final selectedTrackId = before.selectedTrackId;
    if (selectedTrackId == null) return;

    setState(() => _isReverseAnimating = true);
    try {
      await _clearTrackAndToolOverlays(selectedTrackId);
      ref.read(gpxEditorProvider.notifier).reverseCurrentTrackWithCleanState();
      final after = ref.read(gpxEditorProvider);
      final trackIndex = after.tracks.indexWhere(
        (t) => t.id == selectedTrackId,
      );
      if (trackIndex == -1) return;

      await _animateTrackRedraw(after.tracks[trackIndex]);
    } finally {
      if (mounted) setState(() => _isReverseAnimating = false);
    }
  }

  Future<void> _importGpxFiles(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    // ⏳ Mostrem el loading central al mil·lisegon i forcem el mini salt de frame
    setState(() => _isReverseAnimating = true);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final List<TrackModel> parsed = [];
      for (final file in result.files) {
        // 🌟 LA CLAU MÀGICA PER A FLUTTER WEB:
        // Cedim el control al navegador durant un instant abans de començar el processament.
        // Això permet que l'animació de la rodet es mogui i giri de forma 100% fluida!
        await Future.delayed(Duration.zero);

        final content = file.bytes != null
            ? utf8.decode(file.bytes!)
            : await File(file.path!).readAsString();

        parsed.add(GpxParser.parse(content, file.name));
      }

      // Injectem a Riverpod
      ref.read(gpxEditorProvider.notifier).addImportedTracks(parsed);

      // Repintem el mapa
      await _paintTracks(ref.read(gpxEditorProvider).tracks);
      await _focusTrack(
        ref.read(gpxEditorProvider).selectedTrackId,
        ref.read(gpxEditorProvider).tracks,
      );
    } catch (e) {
      debugPrint("Error important tracks: $e");
    } finally {
      // 🧼 Apaguem el loading sempre al final de forma segura
      if (mounted) setState(() => _isReverseAnimating = false);
    }
  }

  void _showMobileBottomSheet(
    BuildContext context,
    WidgetRef ref,
    GpxEditorState state,
    AppLocalizations t,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        color: Colors.white,
        child: EditorSidebarWidget(
          state: state,
          t: t,
          onPaintTracks: _paintTracks,
          onReverseTrack: _reverseSelectedTrackWithAnimation,
          onImportPressed: () => _importGpxFiles(context, ref),
        ),
      ),
    );
  }
}

// =========================================================================
// 🎯 PAS 3: WIDGET REACCIÓ DEL BOTÓ FLOTANT (AÏLLAT DE FORMA INDEPENDENT)
// =========================================================================
// Dins de class _ReactiveSplitButton extends ConsumerWidget a la part inferior de main_editor_screen.dart
class _ReactiveSplitButton extends ConsumerWidget {
  const _ReactiveSplitButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSnappedPoint = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPoint != null),
    );

    final bool show = activeTool == 'split' && isMapIdle && hasSnappedPoint;
    if (!show) return const SizedBox.shrink();

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 60),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
            elevation: 6,
          ),
          icon: const Icon(Icons.content_cut),
          label: Text(t.selectSplitPoint),
          onPressed: () async {
            // 🔍 1) Busquem la pantalla principal des del context de forma immediata
            final screenState = context
                .findAncestorStateOfType<_MainEditorScreenState>();
            if (screenState == null) return;

            // 🔒 2) CONTROL D'ORDRE INVERS:
            // Primer demanem al Notifier que calculi la divisió de dades EN MEMÒRIA,
            // però sense apagar l'eina de split automàticament perquè el botó no desaparegui de cop.
            ref.read(gpxEditorProvider.notifier).executeTrackSplit();

            // 🎨 3) RENDERING ASÍNCRON CONTROLAT:
            // Pintem les noves capes (_part1 i _part2) i netegem la línia discontínua taronja.
            // Com que el botó flotant encara es manté viu i visible, el 'context' és 100% vàlid
            // i Flutter Web no llançarà mai cap excepció de component "disposed".
            final stateDespresDelTall = ref.read(gpxEditorProvider);
            await screenState._paintTracks(stateDespresDelTall.tracks);

            if (screenState._controller != null) {
              await screenState._controller!.setGeoJsonSource("source_range", {
                "type": "FeatureCollection",
                "features": [],
              });
            }

            // 🧼 4) NETEJA FINAL DE SEGURETAT:
            // Un cop la GPU de MapLibre ja ha finalitzat el dibuix i s'ha estabilitzat,
            // ara sí que diem al Notifier que canviï de forma segura l'eina a 'none'
            // per tancar la retícula i amagar aquest botó de manera natural.
            ref.read(gpxEditorProvider.notifier).setActiveTool('none');
          },
        ),
      ),
    );
  }
}

// 📊 COMPONENT REACTIU RECUPERAT: BOTÓ FLOTANT PER A LA SELECCIÓ DE TRAMS
class _ReactiveRangeButton extends ConsumerWidget {
  const _ReactiveRangeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    // Escoltem de forma aïllada les propietats individuals de l'eina de tram
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSnappedPoint = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPoint != null),
    );

    final isSelectingRange = ref.watch(
      gpxEditorProvider.select((s) => s.isSelectingRange),
    );
    final hasStart = ref.watch(
      gpxEditorProvider.select((s) => s.selectionStartIndex != null),
    );

    // Només es mostra si l'eina és 'range_map', el mapa està quiet i tenim un punt imantat
    final bool show = activeTool == 'range_map' && isMapIdle && hasSnappedPoint;
    if (!show) return const SizedBox.shrink();

    // 🏷️ Canviem el text del botó de forma dinàmica segons la fase del tram
    String labelText = t.confirmRangeStartPoint;
    if (hasStart && isSelectingRange) {
      labelText = t.confirmRangeEndPoint;
    } else if (hasStart && !isSelectingRange) {
      labelText = t.selectNewRange;
    }

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 60),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange.shade800,
            elevation: 6,
          ),
          icon: const Icon(Icons.add_location_alt),
          label: Text(labelText),
          onPressed: () {
            // 🎯 Executem la màquina d'estats síncrona del teu Notifier (Fase 1, 2 o 3)
            ref.read(gpxEditorProvider.notifier).handleMapPointSelection();

            // 🔒 SOLUCIÓ AL COMPILADOR: No cridem a cap mètode privat des d'aquí.
            // L'estat canviarà i el 'ref.listen' del mètode build de la pantalla principal
            // s'encarregarà de cridar a '_paintLiveOverlays' de forma nativa.
          },
        ),
      ),
    );
  }
}

// 🤝 COMPONENT REACTIU: BOTÓ FLOTANT PER A LA CONFIRMACIÓ DEL MERGE INTERACTIU
class _ReactiveMergeButton extends ConsumerWidget {
  const _ReactiveMergeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    // Escoltem de forma aïllada per evitar re-renders a la pantalla principal
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasPreview = ref.watch(
      gpxEditorProvider.select((s) => s.previewTrackId != null),
    );

    // 🔒 REGLA INTERACTIVA: Només es mostra si l'eina és 'merge',
    // el mapa s'ha aturat i la retícula ha caçat un track proper.
    final bool show = activeTool == 'merge' && isMapIdle && hasPreview;
    if (!show) return const SizedBox.shrink();

    return Center(
      child: Transform.translate(
        offset: const Offset(
          0,
          60,
        ), // Clavat a la mateixa alçada que els teus altres botons flotants
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            elevation: 6,
          ),
          icon: const Icon(Icons.call_merge),
          label: Text(t.confirmTracksMerge),
          onPressed: () {
            // 🔍 1) Busquem la pantalla principal des del context de forma immediata
            final screenState = context
                .findAncestorStateOfType<_MainEditorScreenState>();
            if (screenState == null) return;

            // 🧼 2) NETEJA INSTANTÀNIA DE LA PREVISUALITZACIÓ
            // Netegem immediatament el fil taronja discontinu abans que es destrueixin els tracks,
            // d'aquesta manera evitem qualsevol excepció de renderitzat al canvas de Flutter Web.
            if (screenState._controller != null) {
              screenState._controller!.setGeoJsonSource("source_range", const {
                "type": "FeatureCollection",
                "features": [],
              });
            }

            // 🤝 3) EXECUTEM EL MERGE A RIVERPOD
            // El Notifier mutarà la llista de tracks en memòria.
            ref.read(gpxEditorProvider.notifier).executeTracksMerge();
          },
        ),
      ),
    );
  }
}

// 📍 COMPONENT REACTIU: BOTÓ FLOTANT PER AFEGIR WAYPOINTS
class _ReactiveWaypointButton extends ConsumerWidget {
  const _ReactiveWaypointButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    // Escoltem només el canvi de l'eina, si el mapa s'ha aturat i si el panell inferior està obert
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSelectedTrack = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId != null),
    );
    final showElevationChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );

    // Si l'eina no és la de waypoints, o el mapa es mou, o no hi ha track seleccionat, s'amaga
    if (activeTool != 'add_waypoint' || !isMapIdle || !hasSelectedTrack) {
      return const SizedBox.shrink();
    }

    return Positioned(
      // S'adapta automàticament per no xocar amb el gràfic d'elevació inferior
      bottom: showElevationChart ? 200 : 24,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton.extended(
          backgroundColor: Colors.blueAccent.shade700,
          icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
          label: Text(
            t.addWaypoint,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            final screenState = context
                .findAncestorStateOfType<_MainEditorScreenState>();
            if (screenState == null) return;

            // 1) Inserim el waypoint a la llista de l'estat de Riverpod
            ref
                .read(gpxEditorProvider.notifier)
                .addWaypointToSelectedTrack(
                  name: "${t.waypointNamePrefix}-${DateTime.now().second}",
                  comment: t.waypointCommentFromGrid,
                );

            // 2) Forcem el repintat de les capes del mapa perquè dibuixi la nova fita a la GPU
            final estatActualitzat = ref.read(gpxEditorProvider);
            await screenState._paintTracks(estatActualitzat.tracks);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t.waypointAddedToActiveTrack),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }
}
