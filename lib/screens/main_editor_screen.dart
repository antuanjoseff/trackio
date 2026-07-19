import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as gmath;
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
  int _snapRevision = 0;
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
          // 🌟 DINS DEL TEU StaticEditorMapWidget -> onMapClick:
          onMapClick: (coordinates) async {
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

            // ✂️ MÒDUL TALLAR (SPLIT) REPARAT:
            if (activeTool == 'split') {
              // 🔒 SEGURETAT: Ja no calculem snapping geogràfic aquí perquè
              // la càmera ja ha fet el snap a base de píxels durant el moviment!
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

            // 📐 MÒDUL SELECCIÓ (RANGE_MAP) REPARAT:
            if (activeTool == 'range_map') {
              notifier.setMapIdle(true);
              notifier.handleMapPointSelection();
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return;
            }

            // 🔗 MÒDUL UNIR (MERGE) REPARAT:
            if (activeTool == 'merge') {
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
            unawaited(_addDrawPointAtVisibleReticle());
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

  void _handleMouseMove(
    LatLng targetCoords,
    double currentZoom,
    GpxEditorState state,
  ) {
    // 🎨 1. EINA DIBUIXAR: Si estem tirant línies de zero amb ratolí
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

    // 📍 2. EINA WAYPOINT: Mou la posició del punt efímer sota el punter
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

    // ✂️ 3. EINES CONTEXTUALS (SPLIT, RANGE_MAP, MERGE) PER A RATOLÍ:
    if (!['split', 'range_map', 'merge'].contains(state.activeTool)) return;
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(const Duration(milliseconds: 40), () {
      // Executa el snapping clàssic enviant de forma directa la coordenada del punter
      ref
          .read(gpxEditorProvider.notifier)
          .calculateSnapping(
            targetCoords.latitude,
            targetCoords.longitude,
            currentZoom,
          );

      // Sincronitza l'estat d'espera perquè el botó de tallar reaccioni si cal
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);

      // Força a la GPU de MapLibre a repintar el cercle taronja imantat sota el ratolí
      paintLiveOverlays(ref.read(gpxEditorProvider));
    });
  }

  Future<LatLng?> _getVisibleReticleLatLng() async {
    if (_controller == null) return null;

    final RenderBox? renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return _controller!.cameraPosition?.target;
    }

    final gmath.Point<double> centerPixel = gmath.Point(
      renderBox.size.width / 2,
      renderBox.size.height / 2,
    );

    try {
      return await _controller!.toLatLng(centerPixel);
    } catch (_) {
      return _controller!.cameraPosition?.target;
    }
  }

  Future<void> _addDrawPointAtVisibleReticle() async {
    final LatLng? target =
        await _getVisibleReticleLatLng() ?? _controller?.cameraPosition?.target;
    if (!mounted || target == null) return;

    ref
        .read(gpxEditorProvider.notifier)
        .addPointToNewTrack(target.latitude, target.longitude);
    paintLiveOverlays(ref.read(gpxEditorProvider));
  }

  Future<void> _handleCameraMove(
    CameraPosition pos,
    GpxEditorState state,
  ) async {
    if (state.activeTool == 'draw') {
      ref
          .read(gpxEditorProvider.notifier)
          .updateDrawingLiveLocationWithoutZ(
            pos.target.latitude,
            pos.target.longitude,
          );
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'add_waypoint') {
      final LatLng? coordsReticula = await _getVisibleReticleLatLng();
      if (coordsReticula != null) {
        ref
            .read(gpxEditorProvider.notifier)
            .updateWaypointPosition(
              coordsReticula.latitude,
              coordsReticula.longitude,
            );
      }
      if (state.isMapIdle) {
        ref.read(gpxEditorProvider.notifier).setMapIdle(false);
      }
      return;
    }

    if (!['split', 'range_map', 'merge'].contains(state.activeTool)) return;

    if (state.isMapIdle) {
      ref.read(gpxEditorProvider.notifier).setMapIdle(false);
    }

    // 🌟 LA REPARACIÓ CRÍTICA SÍNCRONA:
    // Cridem al teu helper per esbrinar quina coordenada real hi ha sota de la creu vermella
    final LatLng? centreReticulaReal = await _getVisibleReticleLatLng();
    final LatLng puntDestiCalcul = centreReticulaReal ?? pos.target;

    // 🔥 INJECCIÓ CORRECTA: Enviem les coordenades geogràfiques reals corregides del Viewport.
    // En rebre el punt exacte, el Fallback Geogràfic del teu Notifier s'activarà correctament dins del radi
    // de tolerància sota el dit. El cercle blau s'alliberarà de l'índex 0 i farà l'snap perfecte frame a frame.
    ref
        .read(gpxEditorProvider.notifier)
        .calculateSnapping(
          puntDestiCalcul.latitude,
          puntDestiCalcul.longitude,
          pos.zoom,
        );

    paintLiveOverlays(ref.read(gpxEditorProvider));
  }

  Future<void> _handleCameraIdle() async {
    final state = ref.read(gpxEditorProvider);
    final pos = _controller?.cameraPosition;
    if (pos == null) return;

    if (state.activeTool == 'draw') {
      ref
          .read(gpxEditorProvider.notifier)
          .updateDrawingLiveLocation(pos.target.latitude, pos.target.longitude);
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'add_waypoint') {
      final LatLng? coordsReticula = await _getVisibleReticleLatLng();
      if (coordsReticula != null) {
        ref
            .read(gpxEditorProvider.notifier)
            .updateWaypointPosition(
              coordsReticula.latitude,
              coordsReticula.longitude,
            );
      }
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      return;
    }

    if (!['split', 'range_map', 'merge'].contains(state.activeTool)) return;

    _throttleTimer?.cancel();

    // Sincronització definitiva amb màxima precisió sobre la creu visible en aturar el mapa
    final LatLng? centreReticulaReal = await _getVisibleReticleLatLng();
    final LatLng puntDeCercar = centreReticulaReal ?? pos.target;

    ref
        .read(gpxEditorProvider.notifier)
        .calculateSnapping(
          puntDeCercar.latitude,
          puntDeCercar.longitude,
          pos.zoom,
        );

    // 🌟 EFECTE CENTRAT DE SEGURETAT DE SENDA:
    // Si l'snap és correcte, centrem suaument el mapa a sobre del punt imantat per segellar l'alineació
    final currentState = ref.read(gpxEditorProvider);
    if (currentState.snappedPoint != null && _controller != null) {
      final p = currentState.snappedPoint!;
      if (p.latitude != null && p.longitude != null) {
        _controller!.moveCamera(
          CameraUpdate.newLatLng(LatLng(p.latitude!, p.longitude!)),
        );
      }
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
    // 1️⃣ REPARACIÓ PLATAFORMA: Afegim .platform i filtrem majúscules/minúscules
    final result = await FilePicker.pickFiles(
      // 🔥 MANTINGUT CORREGIT: .platform
      type: FileType.custom,
      allowedExtensions: ['gpx', 'GPX'],
      withData: true,
      allowMultiple: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    // Activem l'animació de processament en segon pla
    setState(() => _isReverseAnimating = true);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final List<TrackModel> parsed = [];
      for (final file in result.files) {
        // 🔍 FILTRE DE SEGURETAT EXTRA: Validació manual del nom del fitxer
        final extension = file.name.split('.').last.toLowerCase();
        if (extension != 'gpx') {
          debugPrint("Fitxer ignorat per no ser GPX: ${file.name}");
          continue;
        }

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
          parsed.add(GpxParser.parse(content, file.name));
        } else {
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

      ref.read(gpxEditorProvider.notifier).addImportedTracks(parsed);
      await _paintTracksWrapper(ref.read(gpxEditorProvider).tracks);

      // 🌟 REPARACIÓ / FIT TO GPX: El teu mètode _focusTrack ja s'encarrega d'analitzar
      // tots els punts del track seleccionat i moure la càmera amb bounding box.
      // Forcem l'espera asíncrona immediata per centrar la pantalla de cop.
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
    // 🌟 Eliminem el filtre de _isReverseAnimating perquè ja no hi haurà bloqueig
    if (_controller == null) return;

    final before = ref.read(gpxEditorProvider);
    final selectedTrackId = before.selectedTrackId;
    if (selectedTrackId == null) return;

    // ❌ ELIMINAT: Ja no posem la pantalla gràfica a "true" (no es mostrarà el fons borrós)

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

      // Executa la inversió síncrona a la memòria
      ref.read(gpxEditorProvider.notifier).reverseCurrentTrackWithCleanState();

      final after = ref.read(gpxEditorProvider);
      final trackIndex = after.tracks.indexWhere(
        (t) => t.id == selectedTrackId,
      );
      if (trackIndex == -1) return;

      // Executa el redibuix progressiu de la línia directament sobre el mapa
      await _animateTrackRedraw(after.tracks[trackIndex]);
    } catch (e) {
      debugPrint("Error en invertir el track: $e");
    }
    // ❌ ELIMINAT: Esborrat el bloc finally amb el setState de tancament
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
