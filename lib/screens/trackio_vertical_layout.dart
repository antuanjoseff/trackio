import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/widgets/elevation_chart_panel.dart';
import 'package:trackio/widgets/range_track_selection.dart';
import 'package:trackio/widgets/track_stats_panel.dart';
import 'package:trackio/widgets/trackio_icons.dart';
import 'package:trackio/widgets/trackio_large_icon.dart';

class TrackioVerticalLayout extends ConsumerWidget {
  const TrackioVerticalLayout({
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
    final liveActiveTool = ref.watch(
      gpxEditorProvider.select((s) => s.activeTool),
    );
    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );
    final geometryMode = ref.watch(
      gpxEditorProvider.select((s) => s.geometryEditMode),
    );
    final canUndoGeometry = ref.watch(
      gpxEditorProvider.select((s) => s.geometryCanUndo),
    );
    final currentFullState = ref.watch(gpxEditorProvider);

    final bool isDisabled = selectedTrackId == null;
    final bool isMobile = MediaQuery.of(context).size.width <= 800;
    final bool showMobileGeometryTools =
        isMobile && liveActiveTool == 'edit_geometry' && !isDisabled;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              mapModule,

              Positioned(
                top: 16,
                left: 16,
                child: Builder(
                  builder: (context) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: "Sidebar",
                      icon: Icon(
                        isMobile ? Icons.menu_rounded : Icons.view_sidebar,
                        color: Colors.blue.shade700,
                      ),
                      onPressed: () {
                        if (isMobile) {
                          Scaffold.of(context).openDrawer();
                        } else {
                          ref.read(gpxEditorProvider.notifier).toggleSidebar();
                        }
                      },
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showMobileGeometryTools) ...[
                      _btn(
                        isActive: geometryMode == 'add',
                        icon: Icon(
                          Icons.add_circle,
                          color: geometryMode == 'add'
                              ? Colors.green.shade700
                              : Colors.green,
                          size: 28,
                        ),
                        tooltip: t.addNode,
                        onPressed: () => ref
                            .read(gpxEditorProvider.notifier)
                            .setGeometryEditMode('add'),
                      ),
                      const SizedBox(height: 10),
                      _btn(
                        isActive: geometryMode == 'delete',
                        icon: Icon(
                          Icons.remove_circle,
                          color: geometryMode == 'delete'
                              ? Colors.red.shade700
                              : Colors.red,
                          size: 28,
                        ),
                        tooltip: t.deleteNode,
                        onPressed: () => ref
                            .read(gpxEditorProvider.notifier)
                            .setGeometryEditMode('delete'),
                      ),
                      const SizedBox(height: 10),
                      _btn(
                        isActive: geometryMode == 'move',
                        icon: Icon(
                          Icons.open_with,
                          color: geometryMode == 'move'
                              ? Colors.blue.shade700
                              : Colors.blue,
                          size: 28,
                        ),
                        tooltip: t.moveNode,
                        onPressed: () => ref
                            .read(gpxEditorProvider.notifier)
                            .setGeometryEditMode('move'),
                      ),
                      const SizedBox(height: 10),
                      _btn(
                        icon: Icon(
                          Icons.undo,
                          color: canUndoGeometry
                              ? Colors.orange.shade700
                              : Colors.grey.shade400,
                          size: 28,
                        ),
                        tooltip: t.undoGeometryEdit,
                        onPressed: canUndoGeometry
                            ? () => ref
                                  .read(gpxEditorProvider.notifier)
                                  .undoLastGeometryEdit()
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _btn(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                        tooltip: t.cancel,
                        onPressed: () => ref
                            .read(gpxEditorProvider.notifier)
                            .setActiveTool('none'),
                      ),
                    ] else ...[
                      _btn(
                        icon: TrackioLargeIcon(
                          child: TrackioIcons.reverseDirection(
                            color: isDisabled
                                ? Colors.grey.shade400
                                : Colors.blue,
                          ),
                        ),
                        tooltip: t.toolInverse,
                        onPressed: isDisabled
                            ? null
                            : () => onReverseTrack(ref),
                      ),
                      const SizedBox(height: 10),

                      _btn(
                        isActive: liveActiveTool == 'split',
                        icon: TrackioLargeIcon(
                          child: TrackioIcons.cutGpx(
                            color: isDisabled
                                ? Colors.grey.shade400
                                : (liveActiveTool == 'split'
                                      ? Colors.purple.shade700
                                      : Colors.purple),
                          ),
                        ),
                        tooltip: t.toolSplit,
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
                      const SizedBox(height: 10),

                      _btn(
                        isActive: liveActiveTool == 'merge',
                        icon: TrackioLargeIcon(
                          child: TrackioIcons.joinGpx(
                            color: isDisabled
                                ? Colors.grey.shade400
                                : (liveActiveTool == 'merge'
                                      ? Colors.teal.shade700
                                      : Colors.teal),
                          ),
                        ),
                        tooltip: t.toolMerge,
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
                      const SizedBox(height: 10),

                      _btn(
                        isActive: liveActiveTool == 'range_map',
                        icon: TrackioLargeIcon(
                          child: TrackRangeSelection(
                            color: isDisabled
                                ? Colors.grey.shade400
                                : (liveActiveTool == 'range_map'
                                      ? Colors.orange.shade700
                                      : Colors.orange),
                          ),
                        ),
                        tooltip: t.selectRange,
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
                      const SizedBox(height: 10),

                      _btn(
                        isActive: liveActiveTool == 'add_waypoint',
                        icon: TrackioLargeIcon(
                          child: TrackioIcons.addWaypoint(
                            color: isDisabled
                                ? Colors.grey.shade400
                                : (liveActiveTool == 'add_waypoint'
                                      ? Colors.indigo.shade700
                                      : Colors.indigo),
                          ),
                        ),
                        tooltip: t.addWaypoint,
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
                      const SizedBox(height: 10),

                      _btn(
                        isActive: liveActiveTool == 'draw',
                        icon: Icon(
                          Icons.gesture_rounded,
                          color: liveActiveTool == 'draw'
                              ? Colors.pinkAccent
                              : Colors.pink,
                          size: 28,
                        ),
                        tooltip: t.toolDraw,
                        onPressed: () => ref
                            .read(gpxEditorProvider.notifier)
                            .setActiveTool(
                              liveActiveTool == 'draw' ? 'none' : 'draw',
                            ),
                      ),
                      const SizedBox(height: 10),

                      _btn(
                        isActive: liveActiveTool == 'edit_geometry',
                        icon: Icon(
                          Icons.hub_rounded,
                          color: isDisabled
                              ? Colors.grey.shade400
                              : (liveActiveTool == 'edit_geometry'
                                    ? Colors.cyan.shade700
                                    : Colors.cyan),
                          size: 28,
                        ),
                        tooltip: t.toolEditGeometry,
                        onPressed: isDisabled
                            ? null
                            : () => ref
                                  .read(gpxEditorProvider.notifier)
                                  .setActiveTool(
                                    liveActiveTool == 'edit_geometry'
                                        ? 'none'
                                        : 'edit_geometry',
                                  ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        SafeArea(
          top: false,
          bottom: !showElevationChart,
          child: const TrackStatsPanel(),
        ),

        if (showElevationChart)
          SafeArea(
            top: false,
            bottom: true,
            child: ElevationChartPanel(
              editorState: currentFullState,
              height: 140,
              textFontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _btn({
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade50 : Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(color: Colors.blue.shade300, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: icon,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
