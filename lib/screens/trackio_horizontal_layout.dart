import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/widgets/editor_sidebar_widget.dart';
import 'package:trackio/widgets/track_stats_panel.dart';
import 'package:trackio/widgets/elevation_chart_panel.dart';
import 'package:trackio/widgets/trackio_large_icon.dart';
import 'package:trackio/widgets/range_track_selection.dart';

class TrackioHorizontalLayout extends ConsumerWidget {
  const TrackioHorizontalLayout({
    super.key,
    required this.t,
    required this.editorState,
    required this.mapModule,
    required this.showElevationChart,
    required this.onPaintTracks,
    required this.onReverseTrack,
    required this.onImportPressed,
  });

  final AppLocalizations t;
  final GpxEditorState editorState;
  final Widget mapModule;
  final bool showElevationChart;
  final Future<void> Function(List<TrackModel>) onPaintTracks;
  final Future<void> Function(WidgetRef) onReverseTrack;
  final VoidCallback onImportPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // El mapa ocupa tota la pantalla des del fons
              Positioned.fill(child: mapModule),

              // BOTONS FLOTANTS EN FILES SUPERIORS
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: true,
                  bottom: false,
                  left:
                      true, // Protecció dinàmica contra botons del SO esquerra
                  right: true, // Protecció dinàmica contra botons del SO dreta
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 🧠 CAPSULA BLANCA ESQUERRA (Màxima visibilitat per a Menú i Import)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.menu_rounded,
                                  color: Colors.blue.shade700,
                                  size: 26,
                                ),
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              ),
                              IconButton(
                                tooltip: t.importTracks,
                                icon: const Icon(
                                  Icons.upload,
                                  color: Colors.blue,
                                  size: 22,
                                ),
                                onPressed: onImportPressed,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Trackio",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),

                        // 🧠 CAPSULA BLANCA DRETA (Totes les eines aglutinades per editar)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: t.toolInverse,
                                icon: TrackioIcons.reverseDirection(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : Colors.blue,
                                ),
                                onPressed: isDisabled
                                    ? null
                                    : () => onReverseTrack(ref),
                              ),
                              IconButton(
                                tooltip: t.toolSplit,
                                icon: TrackioIcons.cutGpx(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : (liveActiveTool == 'split'
                                            ? Colors.purple.shade700
                                            : Colors.purple),
                                ),
                                onPressed: isDisabled
                                    ? null
                                    : () => ref
                                          .read(gpxEditorProvider.notifier)
                                          .setActiveTool(
                                            liveActiveTool == 'split'
                                                ? 'none'
                                                : 'split',
                                          ),
                              ),
                              IconButton(
                                tooltip: t.toolMerge,
                                icon: TrackioIcons.joinGpx(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : (liveActiveTool == 'merge'
                                            ? Colors.teal.shade700
                                            : Colors.teal),
                                ),
                                onPressed: isDisabled
                                    ? null
                                    : () => ref
                                          .read(gpxEditorProvider.notifier)
                                          .setActiveTool(
                                            liveActiveTool == 'merge'
                                                ? 'none'
                                                : 'merge',
                                          ),
                              ),
                              IconButton(
                                tooltip: t.selectRange,
                                icon: TrackioLargeIcon(
                                  scale: 1.0,
                                  child: TrackRangeSelection(
                                    color: isDisabled
                                        ? Colors.grey.shade400
                                        : (liveActiveTool == 'range_map'
                                              ? Colors.orange.shade700
                                              : Colors.orange),
                                  ),
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
                              IconButton(
                                tooltip: t.addWaypoint,
                                icon: TrackioIcons.addWaypoint(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : (liveActiveTool == 'add_waypoint'
                                            ? Colors.indigo.shade700
                                            : Colors.indigo),
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
                              IconButton(
                                tooltip: t.toolDraw,
                                icon: Icon(
                                  Icons.gesture_rounded,
                                  color: liveActiveTool == 'draw'
                                      ? Colors.pinkAccent
                                      : Colors.pink,
                                  size: 22,
                                ),
                                onPressed: () => ref
                                    .read(gpxEditorProvider.notifier)
                                    .setActiveTool(
                                      liveActiveTool == 'draw'
                                          ? 'none'
                                          : 'draw',
                                    ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: SizedBox(
                                  height: 24,
                                  child: VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: t.elevationProfile,
                                icon: Icon(
                                  liveShowChart
                                      ? Icons.insert_chart
                                      : Icons.insert_chart_outlined,
                                  color: liveShowChart
                                      ? Colors.blue
                                      : Colors.grey.shade600,
                                ),
                                onPressed: () => ref
                                    .read(gpxEditorProvider.notifier)
                                    .toggleElevationChart(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const TrackStatsPanel(),
        if (showElevationChart)
          ElevationChartPanel(editorState: editorState, height: 140),
      ],
    );
  }
}
