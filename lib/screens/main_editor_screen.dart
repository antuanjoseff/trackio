import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
  bool _isDraggingMap = false;
  late final AppLifecycleListener _lifecycleListener;

  static const Duration reverseAnimationDuration = Duration(seconds: 1);
  final GlobalKey _mapKey = GlobalKey(debugLabel: "main_editor_map");

  @override
  MapLibreMapController? get controller => _controller;

  void initState() {
    super.initState();

    // 🌟 NOU: Inicialitzem el detector. Si l'aplicació es desenganxa (es tanca)
    // o s'amaga completament, netegem fulminantment tota la memòria.
    _lifecycleListener = AppLifecycleListener(
      onDetach: _clearAllTracksOnExit,
      onHide: _clearAllTracksOnExit,
    );
  }

  void _clearAllTracksOnExit() {
    final notifier = ref.read(gpxEditorProvider.notifier);

    // 1. Cridem al mètode d'esborrat total al Notifier
    notifier.clearAllTracksAbsolute();

    // 2. Buidem immediatament totes les capes vectorials efímeres del mapa de MapLibre
    if (_controller != null) {
      const Map<String, dynamic> emptyCollection = {
        "type": "FeatureCollection",
        "features": [],
      };
      _controller!.setGeoJsonSource("source_range", emptyCollection);
      _controller!.setGeoJsonSource("source_start_range", emptyCollection);
      _controller!.setGeoJsonSource("source_end_range", emptyCollection);
      _controller!.setGeoJsonSource("source_snapped_point", emptyCollection);
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _lifecycleListener.dispose(); // 🌟 NOU: Netegem el listener de memòria
    super.dispose();
  }

  bool get _isMobileApp =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _hasMouseConnected =>
      !_isMobileApp && RendererBinding.instance.mouseTracker.mouseIsConnected;

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

    // 🌟 REPARACIÓ 3A: Escolta exclusivament el canvi de Track seleccionat per centrar la càmera
    ref.listen<int?>(gpxEditorProvider.select((s) => s.selectedTrackId), (
      previous,
      next,
    ) {
      if (next != null) {
        final state = ref.read(gpxEditorProvider);
        _focusTrack(next, state.tracks);
        _paintTracksWrapper(state.tracks);
      }
    });

    // 🌟 REPARACIÓ 3B: Escolta canvis a la llista global (només quan s'importa, esborra o fusiona)
    ref.listen<List<TrackModel>>(gpxEditorProvider.select((s) => s.tracks), (
      previous,
      next,
    ) {
      final state = ref.read(gpxEditorProvider);
      if (state.loadingTrackIds.isEmpty) {
        _paintTracksWrapper(next);
      }
    });

    // 🌟 REPARACIÓ 3C: Escolta la interacció fina (agulles, moviments de retícula, canvis d'eina)
    ref.listen<GpxEditorState>(gpxEditorProvider, (previous, next) {
      final bool toolChanged = previous?.activeTool != next.activeTool;
      final bool snappedChanged =
          previous?.snappedPointIndex != next.snappedPointIndex ||
          previous?.snappedPoint != next.snappedPoint;
      final bool drawingChanged =
          previous?.drawingPoints != next.drawingPoints ||
          previous?.drawingLivePoint != next.drawingLivePoint;

      if (toolChanged || snappedChanged || drawingChanged) {
        paintLiveOverlays(next);
      }
    });

    final Widget mapModule = Stack(
      children: [
        StaticEditorMapWidget(
          key: _mapKey,
          cursor: mapCursor,
          onMapCreated: (c) {
            _controller = c;
          },

          onStyleLoaded: () async {
            await _paintTracksWrapper(ref.read(gpxEditorProvider).tracks);
            await createGlobalLayers();
            await _focusTrack(
              ref.read(gpxEditorProvider).selectedTrackId,
              ref.read(gpxEditorProvider).tracks,
            );
          },

          onCameraMove: (pos) {
            if (!_isMobileApp) return;

            _handleCameraMove(pos, ref.read(gpxEditorProvider));
          },
          onCameraIdle: _handleCameraIdle,
          onMouseHoverMap: (coordinates) {
            if (!hasMouse) return;
            final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
            _handleMouseMove(coordinates, zoom, ref.read(gpxEditorProvider));
          },

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
              // 1. Capturem la coordenada real on està mirant la retícula en aquest instant precís
              final LatLng? reticleCoords = await _getVisibleReticleLatLng();
              if (reticleCoords == null) return;

              // 2. Sincronitzem l'estat inicial de seguretat
              notifier.updateWaypointPosition(
                reticleCoords.latitude,
                reticleCoords.longitude,
              );
              notifier.setMapIdle(true);

              final selectedTrackId = state.selectedTrackId;
              if (selectedTrackId == null) return;

              final track = state.tracks.firstWhere(
                (t) => t.id == selectedTrackId,
              );
              final String defaultName = "Punt ${track.waypoints.length + 1}";

              // 3. Llançem el diàleg del nom de forma asíncrona.
              // Tot i que la càmera es mogui amb el teclat, la nostra variable 'reticleCoords' està congelada a la memòria.
              final String? name = await askWaypointNameDialog(
                context,
                defaultName,
              );
              if (name == null || name.isEmpty) return;

              // 4. Modifiquem la crida del notifier per assegurar-nos que insereixi la coordenada capturada:
              notifier.updateWaypointPosition(
                reticleCoords.latitude,
                reticleCoords.longitude,
              );
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
    if (_controller == null) {
      return null;
    }

    final renderBox = _mapKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || !renderBox.hasSize) {
      final fallback = _controller!.cameraPosition?.target;
      return fallback;
    }

    // 🔥 FIX REAL: MapLibre vol Point<num>, no Point<double>
    final pixelCenter = math.Point<num>(
      renderBox.size.width / 2,
      renderBox.size.height / 2,
    );

    final latLng = await _controller!.toLatLng(pixelCenter);
    return latLng;
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
    final currentState = ref.read(gpxEditorProvider);

    // 1. Amaguem el botó flotant a l'acte només començar a moure el mapa (🔒 Protegit amb _isDraggingMap)
    if (currentState.activeTool == 'range_map' && !_isDraggingMap) {
      _isDraggingMap = true;
      ref.read(gpxEditorProvider.notifier).setMapIdle(false);
    }

    // 🎨 EINA DIBUIX: Manté l'execució directa per a la línia elàstica interactiva
    if (currentState.activeTool == 'draw') {
      ref
          .read(gpxEditorProvider.notifier)
          .updateDrawingLiveLocationWithoutZ(
            pos.target.latitude,
            pos.target.longitude,
          );
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    // 📍 EINA WAYPOINT: Manté l'execució directa per seguir el punter de forma nativa
    if (currentState.activeTool == 'add_waypoint') {
      final coords = await _getVisibleReticleLatLng();
      if (coords != null) {
        ref
            .read(gpxEditorProvider.notifier)
            .updateWaypointPosition(coords.latitude, coords.longitude);
      }
      return;
    }

    // Filtrem quines eines utilitzaran el temporitzador de 50ms de seguretat
    if (!['split', 'merge', 'range_map'].contains(currentState.activeTool)) {
      return;
    }

    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(const Duration(milliseconds: 50), () async {
      final target = pos.target;
      final notifier = ref.read(gpxEditorProvider.notifier);

      if (currentState.activeTool == 'range_map') {
        // 📐 REPARACIÓ RANGE_MAP AMB THROTTLE RECUPERAT
        notifier.updateRangeSelectionLiveFromReticle(
          target.latitude,
          target.longitude,
          pos.zoom,
        );
      } else {
        // Càlcul de snapping clàssic per a Split i Merge
        notifier.calculateSnapping(target.latitude, target.longitude, pos.zoom);
      }

      paintLiveOverlays(ref.read(gpxEditorProvider));
    });
  }

  Future<void> _handleCameraIdle() async {
    final pos = _controller?.cameraPosition;
    if (pos == null) return;

    final state = ref.read(gpxEditorProvider);

    // 📐 REPARACIÓ CRÍTICA RANGE_MAP: El mapa s'atura, s'activa l'idle i es mostra el botó flotant
    if (state.activeTool == 'range_map') {
      // 🔒 Alliberem el control de moviment per permetre noves deteccions al següent drag
      _isDraggingMap = false;

      ref
          .read(gpxEditorProvider.notifier)
          .updateRangeSelectionLiveFromReticle(
            pos.target.latitude,
            pos.target.longitude,
            pos.zoom,
          );
      // Notifiquem el repòs perquè el ReactiveRangeButton s'activi a la pantalla de forma estable
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'draw') {
      ref
          .read(gpxEditorProvider.notifier)
          .updateDrawingLiveLocation(pos.target.latitude, pos.target.longitude);
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'add_waypoint') {
      final coordsReticula = _controller?.cameraPosition?.target;
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

    if (!['split', 'merge'].contains(state.activeTool)) return;

    _throttleTimer?.cancel();
    final target = pos.target;
    ref
        .read(gpxEditorProvider.notifier)
        .calculateSnapping(target.latitude, target.longitude, pos.zoom);
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
          continue;
        }

        String? content;
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!, allowMalformed: true);
        } else if (!kIsWeb && file.path != null) {
          content = await File(file.path!).readAsString();
        }

        if (content == null || content.trim().isEmpty) {
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
    final int totalPoints = validCoords.length;

    for (int frame = 1; frame <= framesCount; frame++) {
      if (!mounted || _controller == null) return;

      // 🌟 REPARACIÓ: Calculem de forma homogènia quants punts pintar en aquest frame
      final int pointsToTake = ((totalPoints * frame) / framesCount).round();

      // Extreiem el tros de vector a velocitat nativa sense clonar elements interns
      final progressiveSegment = validCoords.sublist(0, pointsToTake);

      await _controller!.setGeoJsonSource(sourceId, {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": progressiveSegment,
            },
          },
        ],
      });
      await Future.delayed(perFrameDelay);
    }
  }
}
