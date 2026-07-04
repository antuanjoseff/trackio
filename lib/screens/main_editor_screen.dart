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
import 'package:trackio/widgets/elevation_chart_widget.dart';

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

  Future<void> _importGpxFiles(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['gpx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final List<TrackModel> parsedTracks = [];
    for (final file in result.files) {
      String gpxContent = "";
      if (file.bytes != null) {
        gpxContent = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final File ioFile = File(file.path!);
        gpxContent = await ioFile.readAsString();
      }

      if (gpxContent.isNotEmpty) {
        try {
          final TrackModel track = GpxParser.parse(gpxContent, file.name);
          parsedTracks.add(track);
        } catch (e) {
          debugPrint("Error parseando el archivo ${file.name}: $e");
        }
      }
    }

    if (parsedTracks.isNotEmpty) {
      // ref.read(gpxEditorProvider.notifier).addImportedTracks(parsedTracks);
      ref.read(gpxEditorProvider.notifier).addImportedTracks(parsedTracks);
      _paintTracks(ref.read(gpxEditorProvider).tracks);
    }
  }

  bool _listenersRegistered = false;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final editorState = ref.watch(gpxEditorProvider);

    // if (!_listenersRegistered) {
    //   _listenersRegistered = true;

    //   // Listener del range (això ja estava bé)
    //   ref.listen<GpxEditorState>(gpxEditorProvider, (previous, next) {
    //     print("🟦 listener → repintant tracks: ${next.tracks.length}");
    //     WidgetsBinding.instance.addPostFrameCallback((_) {
    //       _paintTracks(next.tracks);
    //     });
    //   });
    // }

    final bool isRangeMapMode = editorState.activeTool == 'range_map';

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: t.importGpx,
            onPressed: () => _importGpxFiles(context, ref),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 800;

          final Widget mapModule = Stack(
            children: [
              MapLibreMap(
                styleString: "assets/map/style.json",
                initialCameraPosition: const CameraPosition(
                  target: LatLng(41.98311, 2.82493),
                  zoom: 13.0,
                ),

                onMapCreated: (c) {
                  _controller = c;
                },

                onStyleLoadedCallback: () async {
                  // 1) Primer pintar els tracks → queden a sota
                  await _paintTracks(ref.read(gpxEditorProvider).tracks);

                  // 2) Després crear les capes globals → queden a sobre
                  await _createGlobalLayers();

                  // 3) Finalment centrar la càmera
                  await _focusTrack(
                    ref.read(gpxEditorProvider).selectedTrackId,
                    ref.read(gpxEditorProvider).tracks,
                  );
                },

                onCameraMove: (pos) {
                  final editor = ref.read(gpxEditorProvider);
                  if (editor.activeTool != 'range_map') return;

                  if (_throttleTimer?.isActive ?? false) return;

                  _throttleTimer = Timer(const Duration(milliseconds: 60), () {
                    ref
                        .read(gpxEditorProvider.notifier)
                        .calculateSnapping(
                          pos.target.latitude,
                          pos.target.longitude,
                          pos.zoom,
                        );

                    _paintRange(ref.read(gpxEditorProvider));
                  });
                },

                onCameraIdle: () {
                  final editor = ref.read(gpxEditorProvider);
                  if (editor.activeTool != 'range_map') return;

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
                  _updateRange(ref);
                },
              ),

              // RETÍCULA
              if (isRangeMapMode && !editorState.forceHideReticle)
                const Center(child: _FixedReticleWidget()),

              // BOTÓ CONFIRMAR PUNT
              if (isRangeMapMode &&
                  editorState.isMapIdle &&
                  editorState.snappedPoint != null)
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, 60),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange.shade700,
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text("Confirmar punt"),
                      onPressed: () {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .handleMapPointSelection();
                        _paintRange(ref.read(gpxEditorProvider));
                      },
                    ),
                  ),
                ),
            ],
          );
          if (isDesktop) {
            return Row(
              children: [
                // Barra lateral fixa a l'esquerra
                Container(
                  width: constraints.maxWidth * 0.25,
                  color: Colors.grey.shade100,
                  child: _buildLayersSidebar(context, ref, editorState, t),
                ),

                // Zona principal de treball (Mapa + Gràfic contextual)
                Expanded(
                  child: Column(
                    children: [
                      // El mapa ocupa tot l'espai restant de forma dinàmica
                      Expanded(child: mapModule),

                      if (editorState.showElevationChart)
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                          ),
                          child:
                              editorState.selectedTrackId == null ||
                                  editorState.tracks.isEmpty
                              ? const Center(
                                  child: Text(
                                    "Selecciona un track per veure el perfil d'altituds",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ElevationChartWidget(
                                  track: editorState.tracks.firstWhere(
                                    (t) => t.id == editorState.selectedTrackId,
                                    orElse: () => editorState.tracks.first,
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // LAYOUT MÒBIL CORREGIT
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: mapModule),

                    // 🔥 AFEGIR TAMBÉ AQUÍ LA CONDICIÓ DEL TOGGLE
                    if (editorState.showElevationChart)
                      Container(
                        height: 140,
                        color: Colors.white,
                        child:
                            editorState.selectedTrackId == null ||
                                editorState.tracks.isEmpty
                            ? const Center(
                                child: Text(
                                  "Selecciona un track",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ElevationChartWidget(
                                // 🔒 PROTECCIÓ AFÈGIDA: Evita el crash en mòbils utilitzant l'orElse
                                track: editorState.tracks.firstWhere(
                                  (t) => t.id == editorState.selectedTrackId,
                                  orElse: () => editorState.tracks.first,
                                ),
                              ),
                      ),
                  ],
                ),
                Positioned(
                  // dynamic bottom: Si el gràfic està obert, pugem el botó perquè no el tapi
                  bottom: editorState.showElevationChart ? 160 : 20,
                  right: 16,
                  child: FloatingActionButton(
                    child: const Icon(Icons.layers),
                    onPressed: () =>
                        _showMobileBottomSheet(context, ref, editorState, t),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildLayersSidebar(
    BuildContext context,
    WidgetRef ref,
    GpxEditorState state,
    AppLocalizations t,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _importGpxFiles(context, ref),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 4.0,
                horizontal: 2.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.importGpx.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const Icon(
                    Icons.add_circle_outline,
                    size: 16,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: state.tracks.isEmpty
                ? const Center(child: Text("Sense tracks carregats"))
                : ListView.builder(
                    itemCount: state.tracks.length,
                    itemBuilder: (context, index) {
                      final track = state.tracks[index];
                      final bool isSelected = track.id == state.selectedTrackId;
                      return ListTile(
                        selected: isSelected,
                        leading: GestureDetector(
                          onTap: () {
                            final randomColors = [
                              '#FF3B30',
                              '#34C759',
                              '#FF9500',
                              '#AF52DE',
                              '#007AFF',
                            ];
                            final newColor =
                                randomColors[DateTime.now().millisecond %
                                    randomColors.length];
                            ref
                                .read(gpxEditorProvider.notifier)
                                .updateTrackColor(track.id, newColor);
                            _paintTracks(ref.read(gpxEditorProvider).tracks);
                          },
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(
                                int.parse(
                                  track.hexColor.replaceAll('#', '0xFF'),
                                ),
                              ),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                        title: Text(
                          track.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: track.isVisible
                                ? Colors.black87
                                : Colors.grey.shade400,
                            decoration: track.isVisible
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        trailing: Checkbox(
                          value: track.isVisible,
                          activeColor: Color(
                            int.parse(track.hexColor.replaceAll('#', '0xFF')),
                          ),
                          onChanged: (bool? val) {
                            ref
                                .read(gpxEditorProvider.notifier)
                                .toggleTrackVisibility(track.id);
                            _paintTracks(ref.read(gpxEditorProvider).tracks);
                          },
                        ),
                        onTap: () async {
                          // només estat
                          ref
                              .read(gpxEditorProvider.notifier)
                              .selectTrack(track.id);

                          // mapa (UI)
                          await _focusTrack(
                            track.id,
                            ref.read(gpxEditorProvider).tracks,
                          );
                        },
                      );
                    },
                  ),
          ),
          const Divider(),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => _reverseSelectedTrackWithAnimation(ref),
                      child: Text(
                        t.toolInverse,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => ref
                          .read(gpxEditorProvider.notifier)
                          .setActiveTool(
                            state.activeTool == 'split' ? 'none' : 'split',
                          ),
                      child: Text(
                        state.activeTool == 'split' ? "Aturar" : t.toolSplit,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
                icon: const Icon(Icons.link),
                label: Text(
                  state.activeTool == 'merge' ? "Aturar Unió" : t.toolMerge,
                ),
                onPressed: () => ref
                    .read(gpxEditorProvider.notifier)
                    .setActiveTool(
                      state.activeTool == 'merge' ? 'none' : 'merge',
                    ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  backgroundColor: state.activeTool == 'range_map'
                      ? Colors.orange.shade50
                      : null,
                ),
                icon: const Icon(Icons.analytics_outlined),
                label: Text(
                  state.activeTool == 'range_map'
                      ? "Aturar Tram"
                      : "Seleccionar Tram",
                ),
                onPressed: () {
                  ref
                      .read(gpxEditorProvider.notifier)
                      .setActiveTool(
                        state.activeTool == 'range_map' ? 'none' : 'range_map',
                      );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                ),
                icon: Icon(
                  state.showElevationChart
                      ? Icons.expand_more
                      : Icons.expand_less,
                ),
                label: Text(
                  state.showElevationChart
                      ? "Amagar perfil d'altituds"
                      : "Mostrar perfil d'altituds",
                ),
                onPressed: () =>
                    ref.read(gpxEditorProvider.notifier).toggleElevationChart(),
              ),
            ],
          ),
        ],
      ),
    );
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
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          padding: const EdgeInsets.all(16.0),
          child: _buildLayersSidebar(context, ref, state, t),
        );
      },
    );
  }

  void _updateRange(WidgetRef ref) {
    final state = ref.read(gpxEditorProvider);
    if (_controller == null) return;

    final trackId = state.selectedTrackId;
    if (trackId == null) return;

    final track = state.tracks.firstWhere((t) => t.id == trackId);
    final points = track.points;

    final int? start = state.selectionStartIndex;
    final bool isSelecting = state.isSelectingRange;
    final int? end = isSelecting
        ? state.snappedPointIndex
        : state.selectionEndIndex;

    const Map<String, dynamic> emptyCollection = {
      "type": "FeatureCollection",
      "features": [],
    };

    // SNAPPED POINT
    if (state.activeTool == 'range_map' && state.snappedPoint != null) {
      final p = state.snappedPoint!;
      if (p.longitude != null && p.latitude != null) {
        final geo = {
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
        _controller!.setGeoJsonSource("source_snapped_point", geo);
      }
    } else {
      _controller!.setGeoJsonSource("source_snapped_point", emptyCollection);
    }

    // RANGE LINE
    if (start == null ||
        end == null ||
        end < 0 ||
        start >= points.length ||
        end >= points.length) {
      _controller!.setGeoJsonSource("source_range", emptyCollection);
      return;
    }

    final lo = start < end ? start : end;
    final hi = start < end ? end : start;

    final segment = <List<double>>[];
    for (int i = lo; i <= hi; i++) {
      final p = points[i];
      if (p.longitude != null && p.latitude != null) {
        segment.add([p.longitude!, p.latitude!]);
      }
    }

    final geo = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": segment},
        },
      ],
    };

    _controller!.setGeoJsonSource("source_range", geo);
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

    // Nombre de frames de l’animació (configurable)
    const int framesCount = 60;
    final Duration perFrameDelay =
        reverseAnimationDuration ~/ framesCount; // ~1s total

    final progressive = <List<double>>[];

    // Si hi ha molts punts, en saltem alguns per mantenir 1s
    final int step = (validCoords.length / framesCount).ceil();

    for (int i = 0; i < validCoords.length; i += step) {
      if (!mounted || _controller == null) return;

      progressive.add(validCoords[i]);

      final geojson = {
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
      };

      await _controller!.setGeoJsonSource(sourceId, geojson);
      await Future.delayed(perFrameDelay);
    }

    // Al final, assegurem que totes les coordenades queden dibuixades
    final finalGeojson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": validCoords},
        },
      ],
    };
    await _controller!.setGeoJsonSource(sourceId, finalGeojson);
  }

  Future<void> _reverseSelectedTrackWithAnimation(WidgetRef ref) async {
    if (_controller == null || _isReverseAnimating) return;

    final before = ref.read(gpxEditorProvider);
    final selectedTrackId = before.selectedTrackId;
    if (selectedTrackId == null) return;

    _isReverseAnimating = true;
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
      _isReverseAnimating = false;
      setState(() {});
    }
  }

  Future<void> _createGlobalLayers() async {
    if (_controller == null) return;

    await _controller!.addSource(
      "source_range",
      const GeojsonSourceProperties(
        data: {"type": "FeatureCollection", "features": []},
      ),
    );

    await _controller!.addLineLayer(
      "source_range",
      "layer_range_white",
      const LineLayerProperties(lineColor: "#FFFFFF", lineWidth: 7.0),
    );

    await _controller!.addLineLayer(
      "source_range",
      "layer_range_orange",
      const LineLayerProperties(
        lineColor: "#FF8800",
        lineWidth: 3.5,
        lineDasharray: [2, 2],
      ),
    );

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
        circleRadius: 8.0,
        circleStrokeColor: "#FFFFFF",
        circleStrokeWidth: 2.0,
      ),
    );
  }

  Future<void> _paintTracks(List<TrackModel> tracks) async {
    if (_controller == null) return;

    print("🟦 _paintTracks() → rebuts ${tracks.length} tracks");

    for (final track in tracks) {
      print(
        "   ↳ TRACK id=${track.id} visible=${track.isVisible} punts=${track.points.length}",
      );

      final sourceId = "source_${track.id}";
      final layerId = "layer_${track.id}";

      print("      · sourceId=$sourceId layerId=$layerId");

      final coords = track.points
          .where((p) => p.latitude != null && p.longitude != null)
          .map((p) => [p.longitude!, p.latitude!])
          .toList();

      print("      · coords vàlids=${coords.length}");

      final geojson = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {"type": "LineString", "coordinates": coords},
          },
        ],
      };

      try {
        print("      · removeLayer($layerId)");
        await _controller!.removeLayer(layerId);
      } catch (_) {
        print("      · removeLayer → no existia");
      }

      try {
        print("      · removeSource($sourceId)");
        await _controller!.removeSource(sourceId);
      } catch (_) {
        print("      · removeSource → no existia");
      }

      print("      · addSource($sourceId)");
      await _controller!.addSource(
        sourceId,
        GeojsonSourceProperties(data: geojson),
      );

      print("      · addLineLayer($layerId)");
      await _controller!.addLineLayer(
        sourceId,
        layerId,
        LineLayerProperties(
          lineColor: track.hexColor,
          lineWidth: 4.0,
          lineOpacity: track.isVisible ? 1.0 : 0.0,
        ),
        belowLayerId: "layer_range_white",
      );

      print("      ✔ LAYER CREAT: $layerId");
    }
  }

  Future<void> _paintRange(GpxEditorState state) async {
    if (_controller == null) return;

    final trackId = state.selectedTrackId;
    if (trackId == null) {
      await _controller!.setGeoJsonSource("source_range", {
        "type": "FeatureCollection",
        "features": [],
      });
      return;
    }

    final track = state.tracks.firstWhere((t) => t.id == trackId);
    final start = state.selectionStartIndex;
    final end = state.isSelectingRange
        ? state.snappedPointIndex
        : state.selectionEndIndex;

    if (start == null || end == null || end < 0) {
      await _controller!.setGeoJsonSource("source_range", {
        "type": "FeatureCollection",
        "features": [],
      });
      return;
    }

    final lo = start < end ? start : end;
    final hi = start < end ? end : start;

    final segment = <List<double>>[];
    for (int i = lo; i <= hi; i++) {
      final p = track.points[i];
      if (p.latitude != null && p.longitude != null) {
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
    if (_controller == null || trackId == null) return;

    final track = tracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => tracks.first,
    );
    if (track.points.isEmpty) return;

    double sumLat = 0;
    double sumLng = 0;
    int n = 0;

    for (final p in track.points) {
      if (p.latitude != null && p.longitude != null) {
        sumLat += p.latitude!;
        sumLng += p.longitude!;
        n++;
      }
    }

    if (n == 0) return;

    await _controller!.animateCamera(
      CameraUpdate.newLatLng(LatLng(sumLat / n, sumLng / n)),
    );
  }
}

class _FixedReticleWidget extends StatelessWidget {
  const _FixedReticleWidget();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black87, width: 1.5),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
