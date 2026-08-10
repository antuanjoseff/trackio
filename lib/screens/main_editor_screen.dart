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
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/core/utils/dialogs.dart';
import 'package:trackio/core/utils/gpx_parser.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/screens/main_editor_layout.dart';
import 'package:trackio/widgets/reactive_draw_button.dart';
import 'package:trackio/widgets/reactive_geometry_edit_toolbar.dart';
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
  static const MethodChannel _fileOpenIntentChannel = MethodChannel(
    'trackio/file_open_intents',
  );

  int _backPressCounter = 0;
  DateTime? _lastBackPressTime;

  Timer? _throttleTimer;
  MapLibreMapController? _controller;
  bool _isReverseAnimating = false;
  bool _isDraggingMap = false;
  bool _isSidebarReordering = false;
  bool _isWebGeometryNodeDragging = false;
  bool _isImportingExternalFile = false;
  String? _activeRangeMapHandle;
  late final AppLifecycleListener _lifecycleListener;
  final GlobalKey _staticMapKey = GlobalKey(debugLabel: "main_editor_map");
  static const Duration reverseAnimationDuration = Duration(seconds: 1);

  // 🌟 EL CANVI EXCLUSIU: Aquí hem ESBORRAT del tot la línia 'late final GlobalKey...' [INDEX]

  @override
  MapLibreMapController? get controller => _controller;

  @override
  void initState() {
    super.initState();

    // ⚡ CONFIGURACIÓ PROTEGIDA: Completament neta [INDEX]
    _lifecycleListener = AppLifecycleListener(
      onResume: _consumePendingExternalGpxPath,
      onDetach: kIsWeb ? null : _clearAllTracksOnExit,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumePendingExternalGpxPath());
    });
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
      _controller!.setGeoJsonSource("source_geometry_nodes", emptyCollection);
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

  Future<void> _updateGeometryNodesOverlay() async {
    if (_controller == null || !mounted) return;

    final state = ref.read(gpxEditorProvider);
    if (state.activeTool != 'edit_geometry' || state.selectedTrackId == null) {
      clearGeometryNodesOverlay();
      return;
    }

    final int trackIndex = state.tracks.indexWhere(
      (t) => t.id == state.selectedTrackId,
    );

    if (trackIndex == -1) {
      clearGeometryNodesOverlay();
      return;
    }

    final TrackModel activeTrack = state.tracks[trackIndex];

    if (activeTrack.points.isEmpty) {
      clearGeometryNodesOverlay();
      return;
    }

    final RenderBox? renderBox =
        _staticMapKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || !renderBox.hasSize) {
      clearGeometryNodesOverlay();
      return;
    }

    final double width = renderBox.size.width;
    final double height = renderBox.size.height;
    const double minNodeSpacingPx = 15.0;
    final double devicePixelRatio =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final double coordinateScale = _isMobileApp && devicePixelRatio > 0
        ? devicePixelRatio
        : 1.0;

    final List<TrackPointModel> visibleNodes = [];
    math.Point<num>? lastAcceptedPoint;

    for (final point in activeTrack.points) {
      if (point.latitude == null || point.longitude == null) continue;

      final screenPoint = await _controller!.toScreenLocation(
        LatLng(point.latitude!, point.longitude!),
      );

      final double x = screenPoint.x.toDouble() / coordinateScale;
      final double y = screenPoint.y.toDouble() / coordinateScale;

      if (x < 0 || x > width || y < 0 || y > height) continue;

      if (lastAcceptedPoint != null) {
        final double dx = x - lastAcceptedPoint.x.toDouble();
        final double dy = y - lastAcceptedPoint.y.toDouble();
        final double distancePx = math.sqrt((dx * dx) + (dy * dy));
        if (distancePx < minNodeSpacingPx) continue;
      }

      visibleNodes.add(point);
      lastAcceptedPoint = math.Point<num>(x, y);
    }

    setGeometryNodesOverlay(visibleNodes);
  }

  void _handleSidebarReorderDragStateChanged(bool isDragging) {
    if (_isSidebarReordering == isDragging) return;
    setState(() => _isSidebarReordering = isDragging);
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
    final bool isGeometryAddMode =
        editorState.activeTool == 'edit_geometry' &&
        editorState.geometryEditMode == 'add';
    final bool isGeometryDeleteMode =
        editorState.activeTool == 'edit_geometry' &&
        editorState.geometryEditMode == 'delete';
    final bool isGeometryMoveMode =
        editorState.activeTool == 'edit_geometry' &&
        editorState.geometryEditMode == 'move';
    final bool isDraggingRangeHandle =
        activeTool == 'range_map' && _activeRangeMapHandle != null;
    final MouseCursor mapCursor =
        hasMouse &&
            (activeTool == 'add_waypoint' ||
                isGeometryAddMode ||
                isGeometryDeleteMode ||
                isGeometryMoveMode ||
                isDraggingRangeHandle)
        ? (isDraggingRangeHandle
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.precise)
        : MouseCursor.defer;

    final bool showReticle =
        !hasMouse &&
        ([
              'split',
              'range_map',
              'merge',
              'add_waypoint',
              'draw',
            ].contains(activeTool) ||
            isGeometryAddMode ||
            isGeometryDeleteMode ||
            isGeometryMoveMode);

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
      unawaited(_updateGeometryNodesOverlay());
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
      unawaited(_updateGeometryNodesOverlay());
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
      final bool rangeChanged =
          previous?.chartRangeStartIndex != next.chartRangeStartIndex ||
          previous?.chartRangeEndIndex != next.chartRangeEndIndex ||
          previous?.selectionStartIndex != next.selectionStartIndex ||
          previous?.selectionEndIndex != next.selectionEndIndex;

      if (toolChanged || snappedChanged || drawingChanged || rangeChanged) {
        paintLiveOverlays(next);
      }
      if (toolChanged || rangeChanged) {
        unawaited(_updateGeometryNodesOverlay());
      }
    });

    final Widget mapModule = Stack(
      children: [
        StaticEditorMapWidget(
          key: _staticMapKey,
          cursor: mapCursor,
          panEnabled:
              !_isSidebarReordering &&
              !_isWebGeometryNodeDragging &&
              _activeRangeMapHandle == null,
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
            _handleCameraMove(pos, ref.read(gpxEditorProvider));
          },
          onCameraIdle: _handleCameraIdle,
          onMouseHoverMap: (coordinates) {
            if (!hasMouse) return;
            final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
            _handleMouseMove(coordinates, zoom, ref.read(gpxEditorProvider));
          },
          onMousePrimaryDownMap: (coordinates) {
            final state = ref.read(gpxEditorProvider);
            if (!hasMouse) return;

            if (state.activeTool == 'range_map' &&
                state.selectionStartIndex != null &&
                state.selectionEndIndex != null &&
                !state.isSelectingRange) {
              final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
              final notifier = ref.read(gpxEditorProvider.notifier);
              final clickedIndex = notifier
                  .getNearestTrackPointIndexForCoordinates(
                    coordinates.latitude,
                    coordinates.longitude,
                    zoom,
                  );

              if (clickedIndex == state.selectionStartIndex) {
                if (mounted) {
                  setState(() {
                    _activeRangeMapHandle = 'start';
                  });
                }
                notifier.setMapIdle(false);
                paintLiveOverlays(ref.read(gpxEditorProvider));
                return;
              }

              if (clickedIndex == state.selectionEndIndex) {
                if (mounted) {
                  setState(() {
                    _activeRangeMapHandle = 'end';
                  });
                }
                notifier.setMapIdle(false);
                paintLiveOverlays(ref.read(gpxEditorProvider));
                return;
              }
            }

            if (state.activeTool != 'edit_geometry' ||
                state.geometryEditMode != 'move') {
              return;
            }

            final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
            final notifier = ref.read(gpxEditorProvider.notifier);

            notifier.calculateMoveNodeSnap(
              coordinates.latitude,
              coordinates.longitude,
              zoom,
            );
            notifier.selectMoveNodeFromCurrentSnap();

            final int? selectedIndex = ref
                .read(gpxEditorProvider)
                .geometryMoveNodeIndex;
            if (selectedIndex == null) return;

            if (mounted) {
              setState(() {
                _isWebGeometryNodeDragging = true;
              });
            }

            notifier.setMapIdle(false);
            paintLiveOverlays(ref.read(gpxEditorProvider));
          },
          onMousePrimaryDragMap: (coordinates) {
            final state = ref.read(gpxEditorProvider);
            if (!hasMouse) return;

            if (state.activeTool == 'range_map' &&
                _activeRangeMapHandle != null) {
              final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
              final notifier = ref.read(gpxEditorProvider.notifier);
              notifier.updateRangeSelectionHandleFromMap(
                coordinates.latitude,
                coordinates.longitude,
                zoom,
                isStartHandle: _activeRangeMapHandle == 'start',
              );
              notifier.setMapIdle(false);
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return;
            }

            if (!_isWebGeometryNodeDragging ||
                state.activeTool != 'edit_geometry' ||
                state.geometryEditMode != 'move' ||
                state.geometryMoveNodeIndex == null) {
              return;
            }

            if (_throttleTimer?.isActive ?? false) return;
            _throttleTimer = Timer(const Duration(milliseconds: 50), () {
              final notifier = ref.read(gpxEditorProvider.notifier);
              notifier.moveSelectedNodeTo(
                coordinates.latitude,
                coordinates.longitude,
              );
              paintLiveOverlays(ref.read(gpxEditorProvider));
              unawaited(_updateGeometryNodesOverlay());
            });
          },
          onMousePrimaryUpMap: () {
            final state = ref.read(gpxEditorProvider);
            if (state.activeTool == 'range_map' &&
                _activeRangeMapHandle != null) {
              if (mounted) {
                setState(() {
                  _activeRangeMapHandle = null;
                });
              }
              ref.read(gpxEditorProvider.notifier).setMapIdle(true);
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return;
            }

            if (!hasMouse ||
                !_isWebGeometryNodeDragging ||
                state.activeTool != 'edit_geometry' ||
                state.geometryEditMode != 'move') {
              return;
            }

            _throttleTimer?.cancel();
            if (mounted) {
              setState(() {
                _isWebGeometryNodeDragging = false;
              });
            }

            final notifier = ref.read(gpxEditorProvider.notifier);
            notifier.confirmMoveNodePosition();
            notifier.setMapIdle(true);
            paintLiveOverlays(ref.read(gpxEditorProvider));
            unawaited(_updateGeometryNodesOverlay());
          },

          onMapClick: (coordinates) async {
            FocusScope.of(context).requestFocus();

            final state = ref.read(gpxEditorProvider);
            final notifier = ref.read(gpxEditorProvider.notifier);

            // 🛡️ Si el gràfic està en mode rang però no estem editant el tram amb el mapa,
            // el clic net el tanca. Quan l'eina de rang del mapa està activa, el clic
            // s'ha de reutilitzar per fixar el primer o segon punt del tram.
            if (state.chartSelectionMode == 'range' &&
                state.activeTool != 'range_map') {
              notifier.clearChartSelection();
              paintLiveOverlays(ref.read(gpxEditorProvider));
              return; // Aturem la intercepció creuada aquí!
            }

            final zoom = _controller?.cameraPosition?.zoom ?? 13.0;
            final activeTool = state.activeTool;

            if (activeTool == 'draw') {
              // ⚡ TALLAFOCS REAL PER A LA WEB CONTRA LA FILTRACIÓ DEL CLIC
              if (_controller != null) {
                // Convertim el clic geogràfic en píxels reals del navegador (X, Y)
                final math.Point<num> screenPoint = await _controller!
                    .toScreenLocation(coordinates);

                // 📐 ZONA DE SEGURETAT DE LA BARRA DE DIBUIX:
                // Com que el botó a la Web està centrat a dalt (top: 16), el Card ocupa tota la
                // franja superior. Si el ratolí prem per sobre dels 85 píxels verticals (screenPoint.y < 85),
                // bloquegem el procés perquè sabem de ciència certa que l'usuari està interaccionant amb el menú.
                if (screenPoint.y < 85) {
                  // Cicle de tancament segur: marxem netament sense injectar cap punt fantasma
                  return;
                }
              }

              // Si el clic es fa a qualsevol altra zona del mapa, dibuixem de manera 100% normal
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

            // 📐 MÒDUL SELECCIÓ (RANGE_MAP) REPARAT EXCLUSIVAMENT PER A RATOLÍ EN WEB:
            if (activeTool == 'range_map') {
              if (!hasMouse) return;

              notifier.handleRangeMapSelectionTap(
                coordinates.latitude,
                coordinates.longitude,
                zoom,
              );
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

            if (activeTool == 'edit_geometry' &&
                state.geometryEditMode == 'add' &&
                hasMouse) {
              notifier.calculateAddNodeSnap(
                coordinates.latitude,
                coordinates.longitude,
                zoom,
              );
              notifier.addNodeAtCurrentSnap();
              paintLiveOverlays(ref.read(gpxEditorProvider));
              unawaited(_updateGeometryNodesOverlay());
              return;
            }

            if (activeTool == 'edit_geometry' &&
                state.geometryEditMode == 'delete' &&
                hasMouse) {
              notifier.calculateDeleteNodeSnap(
                coordinates.latitude,
                coordinates.longitude,
                zoom,
              );
              notifier.deleteNodeAtCurrentSnap();
              paintLiveOverlays(ref.read(gpxEditorProvider));
              unawaited(_updateGeometryNodesOverlay());
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
                color: AppColors.starTrekGold.withOpacity(0.85),
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
                  color: AppColors.starTrekRed,
                ),
                onPressed: () =>
                    ref.read(gpxEditorProvider.notifier).toggleSidebar(),
              ),
            ),
          ),

        if (showReticle)
          const Center(
            child: Icon(
              Icons.add_circle_outline,
              size: 40,
              color: AppColors.starTrekRed,
            ),
          ),

        // 🌟 En ratolí ocultem botons contextuals, excepte el menú de dibuix
        if (!hasMouse) ...[
          const ReactiveSplitButton(),
          const ReactiveRangeButton(),
          const ReactiveMergeButton(),
          const ReactiveWaypointButton(),
          const ReactiveAddNodeButton(),
          const ReactiveDeleteNodeButton(),
          const ReactiveMoveNodeButton(),
        ],
        const ReactiveGeometryEditToolbar(),
        const ReactiveDrawButton(),
      ],
    );

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();

        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          _backPressCounter = 1;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.pressBackAgainToExit),
              duration: const Duration(seconds: 2),
            ),
          );

          return false;
        }

        if (_backPressCounter == 1) {
          return true; // surt de la app
        }

        return false;
      },
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            final currentState = ref.read(gpxEditorProvider);
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
          onSidebarReorderDragStateChanged:
              _handleSidebarReorderDragStateChanged,
        ),
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

    if (state.activeTool == 'edit_geometry' &&
        state.geometryEditMode == 'add' &&
        _hasMouseConnected) {
      ref
          .read(gpxEditorProvider.notifier)
          .calculateAddNodeSnap(
            targetCoords.latitude,
            targetCoords.longitude,
            currentZoom,
          );
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'edit_geometry' &&
        state.geometryEditMode == 'delete' &&
        _hasMouseConnected) {
      ref
          .read(gpxEditorProvider.notifier)
          .calculateDeleteNodeSnap(
            targetCoords.latitude,
            targetCoords.longitude,
            currentZoom,
          );
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    if (state.activeTool == 'edit_geometry' &&
        state.geometryEditMode == 'move' &&
        _hasMouseConnected &&
        !_isWebGeometryNodeDragging) {
      ref
          .read(gpxEditorProvider.notifier)
          .calculateMoveNodeSnap(
            targetCoords.latitude,
            targetCoords.longitude,
            currentZoom,
          );
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    // ✂️ 3. EINES CONTEXTUALS (SPLIT, RANGE_MAP, MERGE) PER A RATOLÍ:
    if (!['split', 'range_map', 'merge'].contains(state.activeTool)) return;
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(const Duration(milliseconds: 40), () {
      final notifier = ref.read(gpxEditorProvider.notifier);
      // ⚡ REPARACIÓ CRÍTICA: Llegim l'estat real d'aquest frame instantani
      final liveState = ref.read(gpxEditorProvider);

      if (liveState.activeTool == 'range_map') {
        // 🌐 WEB/RATOLÍ: Enviem les coordenades reals del punter al teu motor de ràfega
        notifier.updateRangeSelectionLiveFromReticle(
          targetCoords.latitude,
          targetCoords.longitude,
          currentZoom,
        );
      } else {
        // Executa el snapping clàssic per a Split i Merge
        notifier.calculateSnapping(
          targetCoords.latitude,
          targetCoords.longitude,
          currentZoom,
        );
      }

      // Sincronitza l'estat d'espera i força el repintat a la GPU de MapLibre
      notifier.setMapIdle(true);
      paintLiveOverlays(ref.read(gpxEditorProvider));
    });
  }

  Future<LatLng?> _getVisibleReticleLatLng() async {
    if (_controller == null) {
      return null;
    }

    final renderBox =
        _staticMapKey.currentContext?.findRenderObject() as RenderBox?;

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
    final liveState = ref.read(gpxEditorProvider);
    final liveTool = liveState.activeTool;
    final bool isGeometryAddMode =
        liveTool == 'edit_geometry' && liveState.geometryEditMode == 'add';
    final bool isGeometryDeleteMode =
        liveTool == 'edit_geometry' && liveState.geometryEditMode == 'delete';
    final bool isGeometryMoveMode =
        liveTool == 'edit_geometry' && liveState.geometryEditMode == 'move';
    final bool isGeometrySnapMode =
        isGeometryAddMode || isGeometryDeleteMode || isGeometryMoveMode;

    if (liveTool == 'edit_geometry' && !isGeometrySnapMode) {
      // En APK evitem refrescar nodes mentre es fa pan per reduir flicker;
      // es recalculen de manera estable a _handleCameraIdle().
      if (_isMobileApp) return;

      if (_throttleTimer?.isActive ?? false) return;
      _throttleTimer = Timer(const Duration(milliseconds: 80), () {
        unawaited(_updateGeometryNodesOverlay());
      });
      return;
    }

    if (isGeometrySnapMode && _isMobileApp) {
      if (!_isDraggingMap) {
        _isDraggingMap = true;
        ref.read(gpxEditorProvider.notifier).setMapIdle(false);
      }

      if (_throttleTimer?.isActive ?? false) return;
      _throttleTimer = Timer(const Duration(milliseconds: 50), () {
        if (isGeometryAddMode) {
          ref
              .read(gpxEditorProvider.notifier)
              .calculateAddNodeSnap(
                pos.target.latitude,
                pos.target.longitude,
                pos.zoom,
              );
        } else if (isGeometryDeleteMode) {
          ref
              .read(gpxEditorProvider.notifier)
              .calculateDeleteNodeSnap(
                pos.target.latitude,
                pos.target.longitude,
                pos.zoom,
              );
        } else {
          final notifier = ref.read(gpxEditorProvider.notifier);
          if (liveState.geometryMoveNodeIndex == null) {
            notifier.calculateMoveNodeSnap(
              pos.target.latitude,
              pos.target.longitude,
              pos.zoom,
            );
          } else {
            notifier.moveSelectedNodeTo(
              pos.target.latitude,
              pos.target.longitude,
            );
          }
        }
        unawaited(_updateGeometryNodesOverlay());
        paintLiveOverlays(ref.read(gpxEditorProvider));
      });
      return;
    }

    if (liveTool == 'edit_geometry') return;

    if (!_isMobileApp) return;

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

    // 🌟 PROTECCIÓ I FILTRE: Si és 'range_chart' (LongPress des del gràfic) o qualsevol altra eina,
    // l'usuari pot fer pan de fons de manera 100% lliure sense disparar el throttle ni recalculats de retícula.
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

    if (state.activeTool == 'edit_geometry') {
      await _updateGeometryNodesOverlay();
      if (state.geometryEditMode != 'add' &&
          state.geometryEditMode != 'delete' &&
          state.geometryEditMode != 'move') {
        return;
      }

      _isDraggingMap = false;
      if (state.geometryEditMode == 'add') {
        ref
            .read(gpxEditorProvider.notifier)
            .calculateAddNodeSnap(
              pos.target.latitude,
              pos.target.longitude,
              pos.zoom,
            );
      } else if (state.geometryEditMode == 'delete') {
        ref
            .read(gpxEditorProvider.notifier)
            .calculateDeleteNodeSnap(
              pos.target.latitude,
              pos.target.longitude,
              pos.zoom,
            );
      } else {
        final notifier = ref.read(gpxEditorProvider.notifier);
        if (state.geometryMoveNodeIndex == null) {
          notifier.calculateMoveNodeSnap(
            pos.target.latitude,
            pos.target.longitude,
            pos.zoom,
          );
        } else {
          notifier.moveSelectedNodeTo(
            pos.target.latitude,
            pos.target.longitude,
          );
        }
      }
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      paintLiveOverlays(ref.read(gpxEditorProvider));
      return;
    }

    // 📐 REPARACIÓ CRÍTICA RANGE_MAP: El mapa s'atura, s'activa l'idle i es mostra el botó flotant natiu de Senda
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

    // 🌟 PROTECCIÓ I FILTRE EN REPÒS: Si venim del mode gràfica ('range_chart'), sortim nets
    // sense executar cap càlcul de snapping residual per evitar deformat de capes o blinking.
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

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final p in track.points) {
      if (p.latitude == null || p.longitude == null) continue;

      minLat = math.min(minLat, p.latitude!);
      maxLat = math.max(maxLat, p.latitude!);
      minLng = math.min(minLng, p.longitude!);
      maxLng = math.max(maxLng, p.longitude!);
    }

    if (!minLat.isFinite) return;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 50,
        top: 50,
        right: 50,
        bottom: 50,
      ),
    );
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

      await _applyImportedTracks(parsed);
    } catch (e) {
      debugPrint("Error analitzant el fitxer a l'APK mòbil o Web: $e");
    } finally {
      if (mounted) setState(() => _isReverseAnimating = false);
    }
  }

  Future<void> _consumePendingExternalGpxPath() async {
    if (!mounted || kIsWeb || _isImportingExternalFile) return;

    try {
      final String? pendingPath = await _fileOpenIntentChannel
          .invokeMethod<String>('consumePendingGpxPath');
      if (pendingPath == null || pendingPath.isEmpty) return;

      await _importGpxFromExternalPath(pendingPath);
    } catch (e) {
      debugPrint("Error recuperant GPX extern des del SO: $e");
    }
  }

  Future<void> _importGpxFromExternalPath(String path) async {
    if (_isImportingExternalFile) return;

    final lowerPath = path.toLowerCase();
    if (!lowerPath.endsWith('.gpx')) return;

    _isImportingExternalFile = true;
    if (mounted) {
      setState(() => _isReverseAnimating = true);
    }

    try {
      final content = await File(path).readAsString();
      if (content.trim().isEmpty) return;

      final String fileName = path.split(Platform.pathSeparator).last;
      final TrackModel parsed = await compute(
        _parseGpxOnBackgroundIsolate,
        {'content': content, 'fileName': fileName},
      );

      await _applyImportedTracks([parsed]);
    } catch (e) {
      debugPrint("Error important GPX extern des del SO: $e");
    } finally {
      _isImportingExternalFile = false;
      if (mounted) {
        setState(() => _isReverseAnimating = false);
      }
    }
  }

  Future<void> _applyImportedTracks(List<TrackModel> parsed) async {
    if (parsed.isEmpty) return;

    ref.read(gpxEditorProvider.notifier).addImportedTracks(parsed);
    await _paintTracksWrapper(ref.read(gpxEditorProvider).tracks);

    await _focusTrack(
      ref.read(gpxEditorProvider).selectedTrackId,
      ref.read(gpxEditorProvider).tracks,
    );
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
