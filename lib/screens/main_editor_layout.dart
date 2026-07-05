import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/widgets/editor_sidebar_widget.dart';
import 'package:trackio/widgets/elevation_chart_panel.dart';
import 'package:trackio/widgets/track_stats_panel.dart'; // 🌟 1. IMPORTAMOS TU NUEVO PANEL DE DATOS

class MainEditorLayout extends ConsumerWidget {
  const MainEditorLayout({
    super.key,
    required this.t,
    required this.editorState,
    required this.mapModule,
    required this.showElevationChart,
    required this.isReverseAnimating,
    required this.onPaintTracks,
    required this.onReverseTrack,
    required this.onImportPressed,
  });

  final AppLocalizations t;
  final GpxEditorState editorState;
  final Widget mapModule;
  final bool showElevationChart;
  final bool isReverseAnimating;
  final Future<void> Function(List<TrackModel>) onPaintTracks;
  final Future<void> Function(WidgetRef) onReverseTrack;
  final VoidCallback onImportPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 LLEGIM ELS ESTATS PER REACCIONAR DINÀMICAMENT A LA APPBAR
    final liveActiveTool = ref.watch(
      gpxEditorProvider.select((s) => s.activeTool),
    );
    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );
    final liveShowChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );

    final bool isDisabled = selectedTrackId == null;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(t.appTitle),
            actions: [
              // 🔄 1. INVERTIR TRACK
              IconButton(
                tooltip: t.toolInverse,
                icon: TrackioIcons.reverseDirection(
                  color: isDisabled ? Colors.grey.shade400 : Colors.blue,
                ),
                onPressed: isDisabled ? null : () => onReverseTrack(ref),
              ),

              // ✂️ 2. TALLAR TRACK (SPLIT)
              IconButton(
                tooltip: t.toolSplit,
                isSelected: liveActiveTool == 'split',
                selectedIcon: TrackioIcons.cutGpx(
                  color: Colors.purple.shade700,
                  size: 20,
                ),
                icon: TrackioIcons.cutGpx(
                  color: isDisabled ? Colors.grey.shade400 : Colors.purple,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: liveActiveTool == 'split'
                      ? Colors.purple.shade50
                      : null,
                ),
                onPressed: isDisabled
                    ? null
                    : () => ref
                          .read(gpxEditorProvider.notifier)
                          .setActiveTool(
                            liveActiveTool == 'split' ? 'none' : 'split',
                          ),
              ),

              // 🔗 3. UNIR TRACKS (MERGE)
              IconButton(
                tooltip: t.toolMerge,
                isSelected: liveActiveTool == 'merge',
                selectedIcon: TrackioIcons.joinGpx(color: Colors.teal.shade700),
                icon: TrackioIcons.joinGpx(
                  color: isDisabled ? Colors.grey.shade400 : Colors.teal,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: liveActiveTool == 'merge'
                      ? Colors.teal.shade50
                      : null,
                ),
                onPressed: isDisabled
                    ? null
                    : () => ref
                          .read(gpxEditorProvider.notifier)
                          .setActiveTool(
                            liveActiveTool == 'merge' ? 'none' : 'merge',
                          ),
              ),

              // 📐 4. SELECCIONAR TRAM
              IconButton(
                tooltip: "Seleccionar Tram",
                isSelected: liveActiveTool == 'range_map',
                selectedIcon: TrackioIcons.selectAndExtract(
                  color: Colors.orange.shade700,
                ),
                icon: TrackioIcons.selectAndExtract(
                  color: isDisabled ? Colors.grey.shade400 : Colors.orange,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: liveActiveTool == 'range_map'
                      ? Colors.orange.shade50
                      : null,
                ),
                onPressed: isDisabled
                    ? null
                    : () => ref
                          .read(gpxEditorProvider.notifier)
                          .setActiveTool(
                            liveActiveTool == 'range_map'
                                ? 'none'
                                : 'range_map',
                          ),
              ),

              // 📍 5. AFEGIR WAYPOINT
              IconButton(
                tooltip: "Afegir Waypoint",
                isSelected: liveActiveTool == 'add_waypoint',
                selectedIcon: TrackioIcons.addWaypoint(
                  color: Colors.indigo.shade700,
                ),
                icon: TrackioIcons.addWaypoint(
                  color: isDisabled ? Colors.grey.shade400 : Colors.indigo,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: liveActiveTool == 'add_waypoint'
                      ? Colors.indigo.shade50
                      : null,
                ),
                onPressed: isDisabled
                    ? null
                    : () => ref
                          .read(gpxEditorProvider.notifier)
                          .setActiveTool(
                            liveActiveTool == 'add_waypoint'
                                ? 'none'
                                : 'add_waypoint',
                          ),
              ),

              const VerticalDivider(indent: 12, endIndent: 12, width: 16),

              // ↕️ 6. GRÀFIC D'ELEVACIONS (Aquest no es bloqueja si isDisabled és true)
              IconButton(
                tooltip: "Perfil d'altituds",
                icon: Icon(
                  liveShowChart
                      ? Icons.insert_chart
                      : Icons.insert_chart_outlined,
                  color: liveShowChart ? Colors.blue : Colors.grey.shade600,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: liveShowChart ? Colors.blue.shade50 : null,
                ),
                onPressed: () =>
                    ref.read(gpxEditorProvider.notifier).toggleElevationChart(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  children: [
                    Container(
                      width: constraints.maxWidth * 0.25,
                      color: Colors.grey.shade100,
                      child: EditorSidebarWidget(
                        state: editorState,
                        t: t,
                        onPaintTracks: onPaintTracks,
                        onReverseTrack: onReverseTrack,
                        onImportPressed: onImportPressed,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: mapModule),

                          // 🎯 2. VISTA ESCRITORIO: Inyectamos el panel de datos justo por encima del gráfico
                          const TrackStatsPanel(),

                          if (showElevationChart)
                            ElevationChartPanel(
                              editorState: editorState,
                              height: 180,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Expanded(child: mapModule),

                    // 🎯 3. VISTA MÓVIL: Inyectamos el mismo panel aquí también por encima del gráfico
                    const TrackStatsPanel(),

                    if (showElevationChart)
                      ElevationChartPanel(
                        editorState: editorState,
                        height: 140,
                        textFontSize: 12,
                      ),
                  ],
                );
              }
            },
          ),
        ),
        if (isReverseAnimating)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.blue),
                      const SizedBox(width: 16),
                      Text(
                        t.processingGpxFile,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
