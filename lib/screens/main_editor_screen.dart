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

class MainEditorScreen extends ConsumerWidget {
  const MainEditorScreen({super.key});

  /// 🛠️ OBJETO DE ESTILO OSM NATIVO PARA MAPLIBRE GL
  /// Define la fuente raster oficial de OpenStreetMap para renderizar a 60 fps.
  static String get _osmStyleJson {
    final Map<String, dynamic> style = {
      "version": 8,
      "sources": {
        "osm-raster-tiles": {
          "type": "raster",
          "tiles": ["https://openstreetmap.org{z}/{x}/{y}.png"],
          "tileSize": 256,
          "attribution": "© OpenStreetMap contributors",
        },
      },
      "layers": [
        {
          "id": "osm-raster-layer",
          "type": "raster",
          "source": "osm-raster-tiles",
          "minzoom": 0,
          "maxzoom": 19,
        },
      ],
    };
    return jsonEncode(style);
  }

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
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final editorState = ref.watch(gpxEditorProvider);

    final bool isToolActive =
        editorState.activeTool == 'split' || editorState.activeTool == 'merge';
    final bool isCuttingMode = editorState.activeTool == 'split';

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

          // 🏗️ MÓDULO DEL MAPA (STACK)
          final Widget mapModule = Stack(
            children: [
              MapLibreMap(
                // 🆕 CARGA DE OSM: Inyectamos la cadena JSON del mapa base
                styleString: "assets/map/style.json",
                initialCameraPosition: const CameraPosition(
                  target: LatLng(41.98311, 2.82493),
                  zoom: 13.0,
                ),
                onStyleLoadedCallback: () {
                  debugPrint(
                    "🗺️ [TRACKIO] El mapa está totalmente cargado y listo para recibir capas.",
                  );
                  ref
                      .read(gpxEditorProvider.notifier)
                      .selectTrackAndFocus(editorState.selectedTrackId);
                },
                onMapCreated: (MapLibreMapController controller) {
                  ref
                      .read(gpxEditorProvider.notifier)
                      .setMapController(controller);
                },
                onCameraMove: (CameraPosition position) {
                  if (isToolActive) {
                    ref.read(gpxEditorProvider.notifier).setMapIdle(false);
                    ref
                        .read(gpxEditorProvider.notifier)
                        .calculateSnapping(
                          position.target.latitude,
                          position.target.longitude,
                        );
                  }
                },
                onCameraIdle: () {
                  if (isToolActive) {
                    ref.read(gpxEditorProvider.notifier).setMapIdle(true);
                  }
                },
              ),
              if (isToolActive) const Center(child: _FixedReticleWidget()),
              if (isToolActive &&
                  editorState.isMapIdle &&
                  editorState.snappedPoint != null)
                Positioned(
                  top: constraints.maxHeight / 2 + 30,
                  left:
                      (isDesktop
                              ? (constraints.maxWidth * 0.75)
                              : constraints.maxWidth) /
                          2 -
                      75,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isCuttingMode
                          ? Colors.red.shade700
                          : Colors.blue.shade700,
                      elevation: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: Icon(isCuttingMode ? Icons.content_cut : Icons.link),
                    label: Text(isCuttingMode ? t.confirmSplit : "Unir rutas"),
                    onPressed: () {
                      if (isCuttingMode) {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .splitCurrentTrack();
                      } else {
                        final int? secondTrackId = ref
                            .read(gpxEditorProvider)
                            .snappedPointIndex;
                        if (secondTrackId != null) {
                          ref
                              .read(gpxEditorProvider.notifier)
                              .mergeTracks(secondTrackId);
                        }
                      }
                    },
                  ),
                ),
            ],
          );

          if (isDesktop) {
            return Row(
              children: [
                Container(
                  width: constraints.maxWidth * 0.25,
                  color: Colors.grey.shade100,
                  child: _buildLayersSidebar(context, ref, editorState, t),
                ),
                Navigator.of(context).canPop() ||
                        true // Evita que se queje la estructura flex
                    ? Expanded(
                        child: Column(
                          children: [
                            Expanded(child: mapModule),
                            Container(
                              height: 180,
                              color: Colors.white,
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
                                        (t) =>
                                            t.id == editorState.selectedTrackId,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            );
          } else {
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: mapModule),
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
                              track: editorState.tracks.firstWhere(
                                (t) => t.id == editorState.selectedTrackId,
                              ),
                            ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 160,
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
