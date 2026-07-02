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
      ref.read(gpxEditorProvider.notifier).addImportedTracks(parsedTracks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final editorState = ref.watch(gpxEditorProvider);

    // Escoltem canvis d'estat i forcem el dibuix del rang un cop Flutter ha acabat el frame
    ref.listen(
      gpxEditorProvider.select(
        (s) => [s.selectionStartIndex, s.selectionEndIndex, s.isSelectingRange],
      ),
      (previous, next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateRange(ref);
        });
      },
    );

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
                trackCameraPosition: true,
                styleString: "assets/map/style.json",
                initialCameraPosition: const CameraPosition(
                  target: LatLng(41.98311, 2.82493),
                  zoom: 13.0,
                ),
                onStyleLoadedCallback: () {
                  // Executem de manera directa l'ordre sequencial net de la pila gràfica de dalt
                  ref
                      .read(gpxEditorProvider.notifier)
                      .selectTrackAndFocus(editorState.selectedTrackId);
                },
                onMapCreated: (MapLibreMapController controller) {
                  ref
                      .read(gpxEditorProvider.notifier)
                      .setMapController(controller);
                },
                onCameraMove: (pos) => _onCameraMove(pos, ref),
                onCameraIdle: () => _onCameraIdle(ref),
              ),

              if (isRangeMapMode && !editorState.forceHideReticle)
                const Center(child: _FixedReticleWidget()),

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
                        if (editorState.snappedPointIndex == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Apunta amb la retícula a un punt del track",
                              ),
                            ),
                          );
                          return;
                        }
                        ref
                            .read(gpxEditorProvider.notifier)
                            .handleMapPointSelection();

                        _updateRange(ref);
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
                          },
                        ),
                        onTap: () => ref
                            .read(gpxEditorProvider.notifier)
                            .selectTrackAndFocus(track.id),
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
                      onPressed: () => ref
                          .read(gpxEditorProvider.notifier)
                          .reverseCurrentTrack(),
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
    final controller = state.mapController;
    if (controller == null) return;

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

    // 1️⃣ ACTUALITZACIÓ NATIVA DEL CERCLE BLAU (SNAPPED POINT)
    if (state.activeTool == 'range_map' && state.snappedPoint != null) {
      final sPoint = state.snappedPoint!;
      if (sPoint.longitude != null && sPoint.latitude != null) {
        final Map<String, dynamic> pointGeoJson = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {},
              "geometry": {
                "type": "Point",
                "coordinates": [sPoint.longitude!, sPoint.latitude!],
              },
            },
          ],
        };
        try {
          controller.setGeoJsonSource("source_snapped_point", pointGeoJson);
        } catch (_) {}
      }
    } else {
      try {
        controller.setGeoJsonSource("source_snapped_point", emptyCollection);
      } catch (_) {}
    }

    // 2️⃣ ACTUALITZACIÓ NATIVA DE LA LÍNIA DEL TRAM (RANG TARONJA)
    if (start == null ||
        end == null ||
        end < 0 ||
        start >= points.length ||
        end >= points.length) {
      try {
        controller.setGeoJsonSource("source_range", emptyCollection);
      } catch (_) {}
      return;
    }

    final int lo = start < end ? start : end;
    final int hi = start < end ? end : start;

    final List<List<double>> segment = [];
    for (int i = lo; i <= hi; i++) {
      final p = points[i];
      if (p.longitude != null && p.latitude != null) {
        segment.add([p.longitude!, p.latitude!]);
      }
    }

    final Map<String, dynamic> cleanGeoJson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {"type": "LineString", "coordinates": segment},
        },
      ],
    };

    try {
      controller.setGeoJsonSource("source_range", cleanGeoJson);
    } catch (e) {
      debugPrint("Error crític enviant GeoJSON a MapLibre: $e");
    }
  }

  void _onCameraMove(CameraPosition pos, WidgetRef ref) {
    final notifier = ref.read(gpxEditorProvider.notifier);
    final state = ref.read(gpxEditorProvider);

    if (state.activeTool != 'range_map') return;

    notifier.setMapIdle(false);

    // 🚀 THROTTLE PUR: Si el temporitzador ja està actiu, el deixem passar.
    // Així executem el snapping exactament cada 60ms (~16 FPS) de manera sostinguda,
    // evitant congelar la pantalla però actualitzant el rang "en viu" mentre mous el mapa.
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(const Duration(milliseconds: 60), () {
      // Passem la latitud, longitud i el ZOOM actual (pos.zoom)
      notifier.calculateSnapping(
        pos.target.latitude,
        pos.target.longitude,
        pos.zoom,
      );
      _updateRange(ref);
    });
  }

  void _onCameraIdle(WidgetRef ref) {
    final state = ref.read(gpxEditorProvider);
    if (state.activeTool == 'range_map') {
      final pos = state.mapController?.cameraPosition;
      if (pos != null) {
        // En aturar-se el mapa completament, calculem l'snap definitiu amb precisió de zoom
        ref
            .read(gpxEditorProvider.notifier)
            .calculateSnapping(
              pos.target.latitude,
              pos.target.longitude,
              pos.zoom,
            );
      }
      ref.read(gpxEditorProvider.notifier).setMapIdle(true);
      _updateRange(ref); // Assegurem que el rang queda perfectament clavat
    }
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
