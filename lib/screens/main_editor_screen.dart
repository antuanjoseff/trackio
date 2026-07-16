import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trackio/core/utils/dialogs.dart';
import 'package:trackio/core/utils/gpx_parser.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/screens/main_editor_layout.dart';
import 'package:trackio/widgets/reactive_draw_button.dart';
import 'package:trackio/widgets/static_editor_map_widget.dart';
import 'package:trackio/mixins/map_rendering_mixin.dart';
import 'package:trackio/widgets/reactive_editor_buttons.dart';

class MainEditorScreen extends ConsumerStatefulWidget {
  const MainEditorScreen({super.key});

  @override
  ConsumerState<MainEditorScreen> createState() => MainEditorScreenState();
}

class MainEditorScreenState extends ConsumerState<MainEditorScreen>
    with MapRenderingMixin {
  Timer? _throttleTimer;
  MapLibreMapController? _controller;
  bool _isReverseAnimating = false;
  static const Duration reverseAnimationDuration = Duration(seconds: 1);
  final GlobalKey _mapKey = GlobalKey(debugLabel: "main_editor_map");

  @override
  MapLibreMapController? get controller => _controller;

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  bool get _hasMouseConnected =>
      RendererBinding.instance.mouseTracker.mouseIsConnected;

  // Mètodes auxiliars propis de la pantalla
  Future<void> _paintTracksWrapper(List<TrackModel> tracks) async {
    final activeId = ref.read(gpxEditorProvider).selectedTrackId;
    await paintTracks(tracks, activeId);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final showElevationChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );

    final editorState = ref.watch(gpxEditorProvider);
    final liveShowSidebar = ref.watch(
      gpxEditorProvider.select((s) => s.showSidebar),
    );
    final bool hasMouse = _hasMouseConnected;
    final MouseCursor mapCursor = hasMouse && activeTool == 'add_waypoint'
        ? SystemMouseCursors.precise
        : MouseCursor.defer;

    final bool showReticle =
        [
          'split',
          'range_map',
          'merge',
          'add_waypoint',
          'draw',
        ].contains(activeTool) &&
        !hasMouse;

    ref.listen<GpxEditorState>(gpxEditorProvider, (previous, next) {
      if (previous?.selectedTrackId != next.selectedTrackId) {
        if (next.selectedTrackId != null)
          _focusTrack(next.selectedTrackId, next.tracks);
        _paintTracksWrapper(next.tracks);
      }
      if (previous?.tracks != next.tracks && next.loadingTrackIds.isEmpty) {
        _paintTracksWrapper(next.tracks);
      }
      if (previous?.snappedPointIndex != next.snappedPointIndex ||
          previous?.snappedPoint != next.snappedPoint) {
        paintLiveOverlays(next);
      }
    });

    final Widget mapModule = Stack(
      children: [
        StaticEditorMapWidget(
          key: _mapKey,
          cursor: mapCursor,
          onMapCreated: (c) => _controller = c,
          onStyleLoaded: () async {
            await _paintTracksWrapper(ref.read(gpxEditorProvider).tracks);
            await createGlobalLayers();
            await _focusTrack(
              ref.read(gpxEditorProvider).selectedTrackId,
              ref.read(gpxEditorProvider).tracks,
            );
          },
          onCameraMove: (pos) {
            if (hasMouse) return;
            _handleCameraMove(pos, ref.read(gpxEditorProvider));
          },
          onCameraIdle: _handleCameraIdle,
          onMouseHoverMap: (coordinates) {
            if (!hasMouse) return;
            final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
            _handleMouseMove(coordinates, zoom, ref.read(gpxEditorProvider));
          },

          // 🌟 CLIC DIRECTE EN MODE ESCRIPTORI
          onMapClick: (coordinates) async {
            if (!hasMouse) return;

            FocusScope.of(context).requestFocus();

            final state = ref.read(gpxEditorProvider);
            final notifier = ref.read(gpxEditorProvider.notifier);
            final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
            final activeTool = state.activeTool;

            if (activeTool == 'draw') {
              notifier.addPointToNewTrack(
                coordinates.latitude,
                coordinates.longitude,
              );
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return;
            }

            if (activeTool == 'split') {
              notifier.calculateSnapping(
                coordinates.latitude,
                coordinates.longitude,
                zoom,
              );
              notifier.setMapIdle(true);
              notifier.executeTrackSplit();

              final stateAfterSplit = ref.read(gpxEditorProvider);
              await paintTracks(
                stateAfterSplit.tracks,
                stateAfterSplit.selectedTrackId,
              );
              if (_controller != null) {
                await _controller!.setGeoJsonSource("source_range", {
                  "type": "FeatureCollection",
                  "features": [],
                });
              }
              return;
            }

            if (activeTool == 'range_map') {
              notifier.calculateSnapping(
                coordinates.latitude,
                coordinates.longitude,
                zoom,
              );
              notifier.setMapIdle(true);
              notifier.handleMapPointSelection();
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return;
            }

            if (activeTool == 'merge') {
              notifier.calculateSnapping(
                coordinates.latitude,
                coordinates.longitude,
                zoom,
              );
              notifier.setMapIdle(true);
              notifier.executeTracksMerge();
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return;
            }

            if (activeTool == 'add_waypoint') {
              notifier.updateWaypointPosition(
                coordinates.latitude,
                coordinates.longitude,
              );
              notifier.setMapIdle(true);

              final selectedTrackId = state.selectedTrackId;
              if (selectedTrackId == null) return;
              final track = state.tracks.firstWhere(
                (t) => t.id == selectedTrackId,
              );
              final String defaultName = "Punt ${track.waypoints.length + 1}";
              final String? name = await askWaypointNameDialog(
                context,
                defaultName,
              );
              if (name == null || name.isEmpty) return;

              notifier.addWaypointToSelectedTrack(name: name, comment: "");
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return;
            }

            _handleMouseMove(coordinates, zoom, state);
          },
        ),

        // ⭐ BOTÓ DEL SIDEBAR A SOBRE DEL MAPA
        Positioned(
          top: 12,
          left: 12,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                liveShowSidebar
                    ? Icons.view_sidebar
                    : Icons.view_sidebar_outlined,
                color: Colors.blue,
              ),
              onPressed: () =>
                  ref.read(gpxEditorProvider.notifier).toggleSidebar(),
            ),
          ),
        ),

        if (showReticle)
          const Center(
            child: Icon(Icons.add_circle_outline, size: 40, color: Colors.red),
          ),

        // 🌟 En ratolí ocultem botons contextuals, excepte el menú de dibuix
        if (!hasMouse) ...[
          const ReactiveSplitButton(),
          const ReactiveRangeButton(),
          const ReactiveMergeButton(),
          const ReactiveWaypointButton(),
        ],
        const ReactiveDrawButton(),
      ],
    );

    return KeyboardListener(
      // 🌟 Escotem de forma global els esdeveniments del teclat físic a la Web
      focusNode: FocusNode()
        ..requestFocus(), // Força el focus automàtic al teclat
      onKeyEvent: (KeyEvent event) {
        // Només capturem el moment de pitjar la tecla (evitem repeticions si es manté premuda)
        if (event is KeyDownEvent) {
          final currentState = ref.read(gpxEditorProvider);

          // 🔒 Regla de seguretat: Només actuem si l'eina activa és 'draw' i premem Enter
          if (currentState.activeTool == 'draw' &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            // Reutilitzem exactament la mateixa lògica del teu botó blau central:
            if (_controller != null) {
              final center = _controller!.cameraPosition?.target;
              if (center != null) {
                // 1. Fixem el punt real a Riverpod
                ref
                    .read(gpxEditorProvider.notifier)
                    .addPointToNewTrack(center.latitude, center.longitude);

                // 2. Forcem el repintat instantani de la línia taronja del mapa i el gràfic
                paintLiveOverlays(ref.read(gpxEditorProvider));
              }
            }
          }
        }
      },
      child: MainEditorLayout(
        t: t,
        editorState: editorState,
        mapModule: mapModule,
        showElevationChart: showElevationChart,
        isReverseAnimating: _isReverseAnimating,
        onPaintTracks: _paintTracksWrapper,
        onReverseTrack: _reverseSelectedTrackWithAnimation,
        onImportPressed: () => _importGpxFiles(context, ref),
      ),
    );
  }

  void _handleCameraMove(CameraPosition pos, GpxEditorState state) {
    // 🌟 EN MOVIMENT: Sincronització en 2D ultraràpida sense demanar la Z ni tocar la xarxa
    if (state.activeTool == 'draw') {
      // 1. Modifiquem només la lat/lon del punt efímer en memòria (amb Z=0 temporal)
      ref
          .read(gpxEditorProvider.notifier)
          .updateDrawingLiveLocationWithoutZ(
            pos.target.latitude,
            pos.target.longitude,
          );
      // 2. Pintem en viu a la GPU de MapLibre a 60 FPS purs
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return; // Sortida ràpida de seguretat
    }

    if (state.activeTool == 'add_waypoint') {
      if (state.isMapIdle)
        ref.read(gpxEditorProvider.notifier).setMapIdle(false);
      return;
    }
    if (!['split', 'range_map', 'merge'].contains(state.activeTool)) return;
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(const Duration(milliseconds: 60), () {
      ref
          .read(gpxEditorProvider.notifier)
          .calculateSnapping(
            pos.target.latitude,
            pos.target.longitude,
            pos.zoom,
          );
      paintLiveOverlays(ref.read(gpxEditorProvider));
    });
  }

  void _handleMouseMove(
    LatLng targetCoords,
    double currentZoom,
    GpxEditorState state,
  ) {
    if (state.activeTool == 'draw') {
      ref
          .read(gpxEditorProvider.notifier)
          .updateDrawingLiveLocationWithoutZ(
            targetCoords.latitude,
            targetCoords.longitude,
          );
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'add_waypoint') {
      ref
          .read(gpxEditorProvider.notifier)
          .updateWaypointPosition(
            targetCoords.latitude,
            targetCoords.longitude,
          );
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      return;
    }

    if (!['split', 'range_map', 'merge'].contains(state.activeTool)) return;
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(const Duration(milliseconds: 40), () {
      ref
          .read(gpxEditorProvider.notifier)
          .calculateSnapping(
            targetCoords.latitude,
            targetCoords.longitude,
            currentZoom,
          );
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      paintLiveOverlays(ref.read(gpxEditorProvider));
    });
  }

  void _handleCameraIdle() {
    if (_hasMouseConnected) return;

    final state = ref.read(gpxEditorProvider);

    // 🌟 AL DETINDRE'S (DEBOUNCE): Resolem la Z real del punt central només quan el mapa es queda quiet
    if (state.activeTool == 'draw') {
      final pos = _controller?.cameraPosition;
      if (pos != null) {
        // Cridem al teu mètode original que activa la cua per calcular l'alçada real a Azure/Django
        ref
            .read(gpxEditorProvider.notifier)
            .updateDrawingLiveLocation(
              pos.target.latitude,
              pos.target.longitude,
            );
      }
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'add_waypoint') {
      final pos = _controller?.cameraPosition;
      if (pos != null)
        ref
            .read(gpxEditorProvider.notifier)
            .updateWaypointPosition(pos.target.latitude, pos.target.longitude);
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      return;
    }

    if (!['split', 'range_map', 'merge'].contains(state.activeTool)) return;

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
    paintLiveOverlays(ref.read(gpxEditorProvider));
  }

  Future<void> _focusTrack(int? trackId, List<TrackModel> tracks) async {
    if (_controller == null || trackId == null || tracks.isEmpty) return;
    final track = tracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => tracks.first,
    );
    if (track.points.isEmpty) return;

    double sumLat = 0, sumLng = 0;
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

  Future<void> _importGpxFiles(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
      withData: true,
      allowMultiple: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _isReverseAnimating = true);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final List<TrackModel> parsed = [];
      for (final file in result.files) {
        await Future.delayed(Duration.zero);
        final content = file.bytes != null
            ? utf8.decode(file.bytes!)
            : await File(file.path!).readAsString();
        parsed.add(GpxParser.parse(content, file.name));
      }
      ref.read(gpxEditorProvider.notifier).addImportedTracks(parsed);
      await _paintTracksWrapper(ref.read(gpxEditorProvider).tracks);
      await _focusTrack(
        ref.read(gpxEditorProvider).selectedTrackId,
        ref.read(gpxEditorProvider).tracks,
      );
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isReverseAnimating = false);
    }
  }

  Future<void> _reverseSelectedTrackWithAnimation(WidgetRef ref) async {
    if (_controller == null || _isReverseAnimating) return;

    final before = ref.read(gpxEditorProvider);
    final selectedTrackId = before.selectedTrackId;
    if (selectedTrackId == null) return;

    setState(() => _isReverseAnimating = true);
    try {
      // 1. Neteja higiènica de les capes i línies taronges de selecció a la GPU
      const Map<String, dynamic> emptyCollection = {
        "type": "FeatureCollection",
        "features": [],
      };
      await _controller!.setGeoJsonSource(
        "source_$selectedTrackId",
        emptyCollection,
      );
      await _controller!.setGeoJsonSource("source_range", emptyCollection);
      await _controller!.setGeoJsonSource(
        "source_snapped_point",
        emptyCollection,
      );

      // 2. Girarem el track en memòria amb el teu Notifier de Riverpod
      ref.read(gpxEditorProvider.notifier).reverseCurrentTrackWithCleanState();

      // 3. Recuperem el track ja girat per poder fer l'animació de dibuixat
      final after = ref.read(gpxEditorProvider);
      final trackIndex = after.tracks.indexWhere(
        (t) => t.id == selectedTrackId,
      );
      if (trackIndex == -1) return;

      // 4. Executem la teva animació nativa a 60 FPS
      await _animateTrackRedraw(after.tracks[trackIndex]);
    } catch (e) {
      debugPrint("Error en invertir el track: $e");
    } finally {
      if (mounted) setState(() => _isReverseAnimating = false);
    }
  }

  // 🌟 RECUPERAT: Mantens la teva funció nativa d'animació frame a frame per al redibuix progressiu
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
}
