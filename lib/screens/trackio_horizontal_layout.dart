import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/widgets/track_stats_panel.dart';
import 'package:trackio/widgets/elevation_chart_panel.dart';
import 'package:trackio/widgets/trackio_icons.dart';
import 'package:trackio/widgets/trackio_large_icon.dart';
import 'package:trackio/widgets/range_track_selection.dart';
import 'package:trackio/widgets/editor_sidebar_widget.dart';

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
    required this.onSidebarReorderDragStateChanged,
  });

  final AppLocalizations t;
  final GpxEditorState editorState;
  final Widget mapModule;
  final bool showElevationChart;
  final Future<void> Function(List<TrackModel>) onPaintTracks;
  final Future<void> Function(WidgetRef) onReverseTrack;
  final VoidCallback onImportPressed;
  final ValueChanged<bool> onSidebarReorderDragStateChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selectors optimitzats de Riverpod
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
    final liveShowChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );
    final liveShowSidebar = ref.watch(
      gpxEditorProvider.select((s) => s.showSidebar),
    );

    final bool isDisabled = selectedTrackId == null;
    final bool isMobile = MediaQuery.of(context).size.width <= 800;
    final bool showMobileGeometryTools =
        liveActiveTool == 'edit_geometry' && !isDisabled;

    // =========================================================================
    // 📱 1. INTERFÍCIE NATIVA PER A MÒBILS (Es manté el Row rígit de sempre)
    // =========================================================================
    if (isMobile) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // El mapa ocupa el fons de la columna mòbil
                      Positioned.fill(child: mapModule),

                      // Columna Esquerra Flotant (Mòbil)
                      Positioned(
                        top: 4,
                        left: 12,
                        child: SafeArea(
                          top: true,
                          bottom: false,
                          left: true,
                          right: false,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).appBarTheme.backgroundColor ??
                                  AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCompactBtn(
                                  context,
                                  isActive: false,
                                  icon: const Icon(
                                    Icons.menu_rounded,
                                    color: AppColors.starTrekRed,
                                  ),
                                  tooltip: "Menú",
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                ),
                                const SizedBox(height: 6),
                                _buildCompactBtn(
                                  context,
                                  icon: const Icon(
                                    Icons.upload,
                                    color: AppColors.starTrekRed,
                                  ),
                                  tooltip: t.importTracks,
                                  onPressed: onImportPressed,
                                ),
                                const SizedBox(height: 6),
                                _buildCompactBtn(
                                  context,
                                  isActive: liveShowChart,
                                  icon: Icon(
                                    liveShowChart
                                        ? Icons.insert_chart
                                        : Icons.insert_chart_outlined,
                                    color: liveShowChart
                                        ? AppColors.starTrekRed
                                        : Colors.grey.shade600,
                                  ),
                                  tooltip: t.elevationProfile,
                                  onPressed: () => ref
                                      .read(gpxEditorProvider.notifier)
                                      .toggleElevationChart(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Columna Dreta d'Eines (Exclusiva de Mòbils)
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
                                  Theme.of(
                                    context,
                                  ).appBarTheme.backgroundColor ??
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
                                if (showMobileGeometryTools) ...[
                                  _buildCompactBtn(
                                    context,
                                    isActive: geometryMode == 'add',
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: AppColors.starTrekRed,
                                    ),
                                    tooltip: t.addNode,
                                    onPressed: () => ref
                                        .read(gpxEditorProvider.notifier)
                                        .setGeometryEditMode('add'),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildCompactBtn(
                                    context,
                                    isActive: geometryMode == 'delete',
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: geometryMode == 'delete'
                                          ? Colors.red.shade700
                                          : Colors.red,
                                    ),
                                    tooltip: t.deleteNode,
                                    onPressed: () => ref
                                        .read(gpxEditorProvider.notifier)
                                        .setGeometryEditMode('delete'),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildCompactBtn(
                                    context,
                                    isActive: geometryMode == 'move',
                                    icon: Icon(
                                      Icons.open_with,
                                      color: AppColors.starTrekRed,
                                    ),
                                    tooltip: t.moveNode,
                                    onPressed: () => ref
                                        .read(gpxEditorProvider.notifier)
                                        .setGeometryEditMode('move'),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildCompactBtn(
                                    context,
                                    icon: Icon(
                                      Icons.undo,
                                      color: canUndoGeometry
                                          ? AppColors.starTrekRed
                                          : Colors.grey.shade400,
                                    ),
                                    tooltip: t.undoGeometryEdit,
                                    onPressed: canUndoGeometry
                                        ? () => ref
                                              .read(gpxEditorProvider.notifier)
                                              .undoLastGeometryEdit()
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildCompactBtn(
                                    context,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.starTrekRed,
                                    ),
                                    tooltip: t.cancel,
                                    onPressed: () => ref
                                        .read(gpxEditorProvider.notifier)
                                        .setActiveTool('none'),
                                  ),
                                ] else ...[
                                  // 1. INVERTIR DIRECCIÓ
                                  _buildCompactBtn(
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
                                  // 2. TALLAR (SPLIT)
                                  _buildCompactBtn(
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
                                  // 3. UNIR (MERGE)
                                  _buildCompactBtn(
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
                                  // 4. SELECCIONAR TRAM (RANGE)
                                  _buildCompactBtn(
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

                                  // 5. AFEGIR WAYPOINT
                                  _buildCompactBtn(
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

                                  // 6. DIBUIXAR DE ZERO
                                  _buildCompactBtn(
                                    context,
                                    isActive: liveActiveTool == 'draw',
                                    icon: TrackioLargeIcon(
                                      child: Icon(
                                        Icons.gesture_rounded,
                                        color: liveActiveTool == 'draw'
                                            ? AppColors.starTrekRed
                                            : AppColors.starTrekRed,
                                      ),
                                    ),
                                    tooltip: t.toolDraw,
                                    onPressed: () => ref
                                        .read(gpxEditorProvider.notifier)
                                        .setActiveTool(
                                          liveActiveTool == 'draw'
                                              ? 'none'
                                              : 'draw',
                                        ),
                                  ),
                                  const SizedBox(height: 6),

                                  // 7. EDITAR GEOMETRIA
                                  _buildCompactBtn(
                                    context,
                                    isActive: liveActiveTool == 'edit_geometry',
                                    icon: Icon(
                                      Icons.hub_rounded,
                                      color: isDisabled
                                          ? Colors.grey.shade400
                                          : (liveActiveTool == 'edit_geometry'
                                                ? AppColors.starTrekRed
                                                : AppColors.starTrekRed),
                                    ),
                                    tooltip: t.toolEditGeometry,
                                    onPressed: isDisabled
                                        ? null
                                        : () => ref
                                              .read(gpxEditorProvider.notifier)
                                              .setActiveTool(
                                                liveActiveTool ==
                                                        'edit_geometry'
                                                    ? 'none'
                                                    : 'edit_geometry',
                                              ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Elements inferiors de l'APK de mòbil
          const TrackStatsPanel(),
          if (showElevationChart)
            ElevationChartPanel(editorState: editorState, height: 110),
        ],
      );
    }

    // =========================================================================
    // 🌐 2. INTERFÍCIE PREMIUM PER A WEB (Disseny elàstic Stack amb fons de mapa complet)
    // =========================================================================
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Capa base sota de tot: El mapa ocupa el 100% de la finestra web
              Positioned.fill(child: mapModule),

              // Targeta Flotant del Sidebar (Amb marges nens i cantonades suaus)
              if (liveShowSidebar)
                Positioned(
                  top: 12,
                  bottom: 12,
                  left: 12,
                  child: Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: AppColors.starTrekGold,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SafeArea(
                        top: false,
                        bottom: true,
                        child: EditorSidebarWidget(
                          state: editorState,
                          t: t,
                          onPaintTracks: onPaintTracks,
                          onReverseTrack: onReverseTrack,
                          onImportPressed: onImportPressed,
                          onReorderDragStateChanged:
                              onSidebarReorderDragStateChanged,
                        ),
                      ),
                    ),
                  ),
                ),

              // Botó flotant del Menú Web (S'alinea automàticament a la vora del menú)
              Positioned(
                top: 12,
                left: liveShowSidebar ? 344 : 12,
                child: SafeArea(
                  top: true,
                  child: _buildCompactBtn(
                    context,
                    isActive: liveShowSidebar,
                    icon: Icon(
                      liveShowSidebar
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                      color: AppColors.starTrekRed,
                    ),
                    tooltip: "Menú",
                    onPressed: () =>
                        ref.read(gpxEditorProvider.notifier).toggleSidebar(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Barra inferior d'estadístiques neta per a la Web
        const TrackStatsPanel(),

        // Perfil d'elevacions de la Web (Ample complet discret)
        if (showElevationChart)
          ElevationChartPanel(editorState: editorState, height: 140),
      ],
    );
  }

  // 📐 BOTONS D'ALTA DENSITAT ESTRUCUTURALS
  Widget _buildCompactBtn(
    BuildContext context, {
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).appBarTheme.backgroundColor
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: icon,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 20,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
