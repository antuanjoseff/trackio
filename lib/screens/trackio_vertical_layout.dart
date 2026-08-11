import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
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
    final bool isMobileApp =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    final bool isDisabled = selectedTrackId == null;
    final bool isMobile = MediaQuery.of(context).size.width <= 800;
    final bool hideMainToolbar = liveActiveTool == 'edit_geometry';
    // En app mòbil, l'eina de geometria es gestiona només amb la toolbar dedicada.
    final bool showMobileGeometryTools =
        isMobile &&
        liveActiveTool == 'edit_geometry' &&
        !isDisabled &&
        !isMobileApp;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              mapModule,

              if (!isMobile)
                Positioned(
                  top: 4,
                  right: 12,
                  child: SafeArea(
                    top: true,
                    bottom: false,
                    left: false,
                    right: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).appBarTheme.backgroundColor ??
                            AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(-2, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _btn(
                            context,
                            icon: Icon(
                              isMobile
                                  ? Icons.menu_rounded
                                  : Icons.view_sidebar,
                              color: AppColors.starTrekRed,
                            ),
                            tooltip: "Sidebar",
                            onPressed: () {
                              if (isMobile) {
                                Scaffold.of(context).openDrawer();
                              } else {
                                ref
                                    .read(gpxEditorProvider.notifier)
                                    .toggleSidebar();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (isMobile && !hideMainToolbar)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showMobileGeometryTools) ...[
                            _btn(
                              context,
                              isActive: geometryMode == 'add',
                              icon: Icon(
                                Icons.add_circle,
                                color: AppColors.starTrekRed,
                                size: 20,
                              ),
                              tooltip: t.addNode,
                              onPressed: () => ref
                                  .read(gpxEditorProvider.notifier)
                                  .setGeometryEditMode('add'),
                            ),
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              isActive: geometryMode == 'delete',
                              icon: Icon(
                                Icons.remove_circle,
                                color: AppColors.starTrekRed,
                                size: 20,
                              ),
                              tooltip: t.deleteNode,
                              onPressed: () => ref
                                  .read(gpxEditorProvider.notifier)
                                  .setGeometryEditMode('delete'),
                            ),
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              isActive: geometryMode == 'move',
                              icon: Icon(
                                Icons.open_with,
                                color: AppColors.starTrekRed,
                                size: 20,
                              ),
                              tooltip: t.moveNode,
                              onPressed: () => ref
                                  .read(gpxEditorProvider.notifier)
                                  .setGeometryEditMode('move'),
                            ),
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              icon: Icon(
                                Icons.undo,
                                color: canUndoGeometry
                                    ? AppColors.starTrekRed
                                    : Colors.grey.shade400,
                                size: 20,
                              ),
                              tooltip: t.undoGeometryEdit,
                              onPressed: canUndoGeometry
                                  ? () => ref
                                        .read(gpxEditorProvider.notifier)
                                        .undoLastGeometryEdit()
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.starTrekRed,
                                size: 20,
                              ),
                              tooltip: t.cancel,
                              onPressed: () => ref
                                  .read(gpxEditorProvider.notifier)
                                  .setActiveTool('none'),
                            ),
                          ] else ...[
                            _btn(
                              context,
                              icon: TrackioLargeIcon(
                                child: TrackioIcons.reverseDirection(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : AppColors.starTrekRed,
                                ),
                              ),
                              tooltip: t.toolInverse,
                              onPressed: isDisabled
                                  ? null
                                  : () => onReverseTrack(ref),
                            ),
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              isActive: liveActiveTool == 'split',
                              icon: TrackioLargeIcon(
                                child: TrackioIcons.cutGpx(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : AppColors.starTrekRed,
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
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              isActive: liveActiveTool == 'merge',
                              icon: TrackioLargeIcon(
                                child: TrackioIcons.joinGpx(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : AppColors.starTrekRed,
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
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              isActive: liveActiveTool == 'range_map',
                              icon: TrackioLargeIcon(
                                child: TrackRangeSelection(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : AppColors.starTrekRed,
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
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              isActive: liveActiveTool == 'add_waypoint',
                              icon: TrackioLargeIcon(
                                child: TrackioIcons.addWaypoint(
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : AppColors.starTrekRed,
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
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              isActive: liveActiveTool == 'draw',
                              icon: Icon(
                                Icons.gesture_rounded,
                                color: AppColors.starTrekRed,
                                size: 20,
                              ),
                              tooltip: t.toolDraw,
                              onPressed: () => ref
                                  .read(gpxEditorProvider.notifier)
                                  .setActiveTool(
                                    liveActiveTool == 'draw' ? 'none' : 'draw',
                                  ),
                            ),
                            const SizedBox(width: 6),
                            _btn(
                              context,
                              isActive: liveActiveTool == 'edit_geometry',
                              icon: Icon(
                                Icons.hub_rounded,
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : AppColors.starTrekRed,
                                size: 20,
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
                  ),
                )
              else if (!isMobile && !hideMainToolbar)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showMobileGeometryTools) ...[
                          _btn(
                            context,
                            isActive: geometryMode == 'add',
                            icon: Icon(
                              Icons.add_circle,
                              color: geometryMode == 'add'
                                  ? AppColors.starTrekRed
                                  : AppColors.starTrekRed,
                              size: 20,
                            ),
                            tooltip: t.addNode,
                            onPressed: () => ref
                                .read(gpxEditorProvider.notifier)
                                .setGeometryEditMode('add'),
                          ),
                          const SizedBox(height: 6),
                          _btn(
                            context,
                            isActive: geometryMode == 'delete',
                            icon: Icon(
                              Icons.remove_circle,
                              color: geometryMode == 'delete'
                                  ? AppColors.starTrekRed
                                  : AppColors.starTrekRed,
                              size: 20,
                            ),
                            tooltip: t.deleteNode,
                            onPressed: () => ref
                                .read(gpxEditorProvider.notifier)
                                .setGeometryEditMode('delete'),
                          ),
                          const SizedBox(height: 6),
                          _btn(
                            context,
                            isActive: geometryMode == 'move',
                            icon: Icon(
                              Icons.open_with,
                              color: geometryMode == 'move'
                                  ? AppColors.starTrekRed
                                  : AppColors.starTrekRed,
                              size: 20,
                            ),
                            tooltip: t.moveNode,
                            onPressed: () => ref
                                .read(gpxEditorProvider.notifier)
                                .setGeometryEditMode('move'),
                          ),
                          const SizedBox(height: 6),
                          _btn(
                            context,
                            icon: Icon(
                              Icons.undo,
                              color: canUndoGeometry
                                  ? AppColors.starTrekRed
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                            tooltip: t.undoGeometryEdit,
                            onPressed: canUndoGeometry
                                ? () => ref
                                      .read(gpxEditorProvider.notifier)
                                      .undoLastGeometryEdit()
                                : null,
                          ),
                          const SizedBox(height: 6),
                          _btn(
                            context,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.starTrekRed,
                              size: 20,
                            ),
                            tooltip: t.cancel,
                            onPressed: () => ref
                                .read(gpxEditorProvider.notifier)
                                .setActiveTool('none'),
                          ),
                        ] else ...[
                          _btn(
                            context,
                            icon: TrackioLargeIcon(
                              child: TrackioIcons.reverseDirection(
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : AppColors.starTrekRed,
                              ),
                            ),
                            tooltip: t.toolInverse,
                            onPressed: isDisabled
                                ? null
                                : () => onReverseTrack(ref),
                          ),
                          const SizedBox(height: 6),

                          _btn(
                            context,
                            isActive: liveActiveTool == 'split',
                            icon: TrackioLargeIcon(
                              child: TrackioIcons.cutGpx(
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : (liveActiveTool == 'split'
                                          ? AppColors.starTrekRed
                                          : AppColors.starTrekRed),
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
                          const SizedBox(height: 6),

                          _btn(
                            context,
                            isActive: liveActiveTool == 'merge',
                            icon: TrackioLargeIcon(
                              child: TrackioIcons.joinGpx(
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : (liveActiveTool == 'merge'
                                          ? AppColors.starTrekRed
                                          : AppColors.starTrekRed),
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
                          const SizedBox(height: 6),

                          _btn(
                            context,
                            isActive: liveActiveTool == 'range_map',
                            icon: TrackioLargeIcon(
                              child: TrackRangeSelection(
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : (liveActiveTool == 'range_map'
                                          ? AppColors.starTrekRed
                                          : AppColors.starTrekRed),
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
                          const SizedBox(height: 6),

                          _btn(
                            context,
                            isActive: liveActiveTool == 'add_waypoint',
                            icon: TrackioLargeIcon(
                              child: TrackioIcons.addWaypoint(
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : (liveActiveTool == 'add_waypoint'
                                          ? AppColors.starTrekRed
                                          : AppColors.starTrekRed),
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
                          const SizedBox(height: 6),

                          _btn(
                            context,
                            isActive: liveActiveTool == 'draw',
                            icon: Icon(
                              Icons.gesture_rounded,
                              color: liveActiveTool == 'draw'
                                  ? AppColors.starTrekRed
                                  : AppColors.starTrekRed,
                              size: 20,
                            ),
                            tooltip: t.toolDraw,
                            onPressed: () => ref
                                .read(gpxEditorProvider.notifier)
                                .setActiveTool(
                                  liveActiveTool == 'draw' ? 'none' : 'draw',
                                ),
                          ),
                          const SizedBox(height: 6),

                          _btn(
                            context,
                            isActive: liveActiveTool == 'edit_geometry',
                            icon: Icon(
                              Icons.hub_rounded,
                              color: isDisabled
                                  ? Colors.grey.shade400
                                  : (liveActiveTool == 'edit_geometry'
                                        ? AppColors.starTrekRed
                                        : AppColors.starTrekRed),
                              size: 20,
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

  Widget _btn(
    BuildContext context, {
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    final bool isDisabled = onPressed == null;
    final Color baseSurface = Theme.of(context).colorScheme.surface;
    final Widget effectiveIcon = isActive
        ? ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: icon,
          )
        : icon;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isActive ? AppColors.starTrekRed : baseSurface.withOpacity(0.84),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? AppColors.starTrekRed
              : AppColors.starTrekRed.withOpacity(0.35),
          width: isActive ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isActive ? 0.2 : 0.1),
            blurRadius: isActive ? 8 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: isDisabled ? 0.45 : 1,
        child: IconButton(
          tooltip: tooltip,
          icon: effectiveIcon,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 20,
        ),
      ),
    );
  }
}
