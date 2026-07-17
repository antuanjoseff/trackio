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

TrackModel _parseGpxOnBackgroundIsolate(Map<String, String> payload) {
  final content = payload['content'] ?? '';
  final fileName = payload['fileName'] ?? 'imported_track';
  return GpxParser.parse(content, fileName);
}

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
      if (previous?.drawingPoints != next.drawingPoints ||
          previous?.drawingLivePoint != next.drawingLivePoint ||
          previous?.activeTool != next.activeTool) {
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

          // 🌟 CLIC DIRECTE EN MODE ESCRIPTORI / MÒBIL REGULAT
          onMapClick: (coordinates) async {
            FocusScope.of(context).requestFocus();

            final state = ref.read(gpxEditorProvider);
            final notifier = ref.read(gpxEditorProvider.notifier);
            final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
            final activeTool = state.activeTool;

            // En dispositius sense ratolí, split/range/merge confirmen sempre
            // el punt sota la retícula central (camera target), igual que el cursor.
            final LatLng snapTarget =
                !hasMouse &&
                    ['split', 'range_map', 'merge'].contains(activeTool)
                ? (_controller?.cameraPosition?.target ?? coordinates)
                : coordinates;

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
                snapTarget.latitude,
                snapTarget.longitude,
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
                snapTarget.latitude,
                snapTarget.longitude,
                zoom,
              );
              notifier.setMapIdle(true);
              notifier.handleMapPointSelection();
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return;
            }

            if (activeTool == 'merge') {
              notifier.calculateSnapping(
                snapTarget.latitude,
                snapTarget.longitude,
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

        // ⭐ BOTÓ DEL SIDEBAR A SOBRE DEL MAPA (Ocult a l'APK mòbil per no duplicar amb l'AppBar)
        if (hasMouse)
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
    if (state.isMapIdle) {
      ref.read(gpxEditorProvider.notifier).setMapIdle(false);
    }
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
    // 🌐 WEB CONTEXT: Si hi ha un ratolí físic, ens saltem el repòs perquè tot es calcula a '_handleMouseMove'
    if (_hasMouseConnected) return;

    final state = ref.read(gpxEditorProvider);
    final pos = _controller?.cameraPosition;
    if (pos == null) return;

    // 🎨 EINA DIBUIXAR (Mòbil): Resolem la Z real del punt central només quan el mapa es queda quiet
    if (state.activeTool == 'draw') {
      ref
          .read(gpxEditorProvider.notifier)
          .updateDrawingLiveLocation(pos.target.latitude, pos.target.longitude);
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'add_waypoint') {
      ref
          .read(gpxEditorProvider.notifier)
          .updateWaypointPosition(pos.target.latitude, pos.target.longitude);
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      return;
    }

    if (!['split', 'range_map', 'merge'].contains(state.activeTool)) return;

    // 🌟 SINCRO APK MÒBIL: Calculem snapping exactament on apunta el centre de la retícula
    ref
        .read(gpxEditorProvider.notifier)
        .calculateSnapping(pos.target.latitude, pos.target.longitude, pos.zoom);

    // Això activa els teus botons contextuals flotants de confirmació de l'APK (split, merge...)
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
    // 1️⃣ REPARACIÓ PLATAFORMA: Forcem la instància unificada nativa de FilePicker
    // Això permet que Android obri el selector de documents de l'APK de forma correcta
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
      withData:
          true, // 🌟 Carrega els bytes directament a la RAM de la Web i de l'APK mòbil
      allowMultiple: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    // Activem l'animació de processament en segon pla (pantalla borrosa de càrrega)
    setState(() => _isReverseAnimating = true);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final List<TrackModel> parsed = [];
      for (final file in result.files) {
        // Fem una lectura robusta: bytes (web/mòbil) i fallback a path (Android)
        String? content;
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!, allowMalformed: true);
        } else if (!kIsWeb && file.path != null) {
          content = await File(file.path!).readAsString();
        }

        if (content == null || content.trim().isEmpty) {
          debugPrint("Avís: no s'ha pogut llegir el fitxer ${file.name}.");
          continue;
        }

        if (kIsWeb) {
          // 🌐 RUTA WEB: Parseig síncron clàssic ràpid en ordinadors
          parsed.add(GpxParser.parse(content, file.name));
        } else {
          // A Android release, compute requereix callback top-level/static.
          final TrackModel trackModel = await compute(
            _parseGpxOnBackgroundIsolate,
            {'content': content, 'fileName': file.name},
          );
          parsed.add(trackModel);
        }
      }

      if (parsed.isEmpty) {
        debugPrint(
          "No s'ha importat cap track vàlid des dels fitxers seleccionats.",
        );
        return;
      }

      // Inserim les rutes noves a Riverpod i redibuixem el mapa de MapLibre de cop
      ref.read(gpxEditorProvider.notifier).addImportedTracks(parsed);
      await _paintTracksWrapper(ref.read(gpxEditorProvider).tracks);
      await _focusTrack(
        ref.read(gpxEditorProvider).selectedTrackId,
        ref.read(gpxEditorProvider).tracks,
      );
    } catch (e) {
      debugPrint("Error analitzant el fitxer a l'APK mòbil o Web: $e");
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
      ref.read(gpxEditorProvider.notifier).reverseCurrentTrackWithCleanState();
      final after = ref.read(gpxEditorProvider);
      final trackIndex = after.tracks.indexWhere(
        (t) => t.id == selectedTrackId,
      );
      if (trackIndex == -1) return;
      await _animateTrackRedraw(after.tracks[trackIndex]);
    } catch (e) {
      debugPrint("Error en invertir el track: $e");
    } finally {
      if (mounted) setState(() => _isReverseAnimating = false);
    }
  }

  Future _animateTrackRedraw(TrackModel track) async {
    if (_controller == null) return;
    final sourceId = "source_${track.id}";
    final validCoords = track.points
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => [p.longitude!, p.latitude!])
        .toList();
    if (validCoords.isEmpty) return;
    const int framesCount = 60;
    final Duration perFrameDelay = reverseAnimationDuration ~/ framesCount;
    final progressive = <List>[];
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
              "coordinates": List<List>.from(progressive),
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
