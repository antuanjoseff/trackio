import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Selectors optimitzats de Riverpod
    final liveActiveTool = ref.watch(
      gpxEditorProvider.select((s) => s.activeTool),
    );
    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );
    final liveShowChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );
    final liveShowSidebar = ref.watch(
      gpxEditorProvider.select((s) => s.showSidebar),
    );

    final bool isDisabled = selectedTrackId == null;
    final bool isMobile = MediaQuery.of(context).size.width <= 800;

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
                              color: Colors.white.withOpacity(0.95),
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
                                  isActive: false,
                                  icon: const Icon(
                                    Icons.menu_rounded,
                                    color: Colors.blue,
                                  ),
                                  tooltip: "Menú",
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                ),
                                const SizedBox(height: 6),
                                _buildCompactBtn(
                                  icon: const Icon(
                                    Icons.upload,
                                    color: Colors.blue,
                                  ),
                                  tooltip: t.importTracks,
                                  onPressed: onImportPressed,
                                ),
                                const SizedBox(height: 6),
                                _buildCompactBtn(
                                  isActive: liveShowChart,
                                  icon: Icon(
                                    liveShowChart
                                        ? Icons.insert_chart
                                        : Icons.insert_chart_outlined,
                                    color: liveShowChart
                                        ? Colors.blue
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
                              color: Colors.white.withOpacity(0.95),
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
                                // 1. INVERTIR DIRECCIÓ
                                _buildCompactBtn(
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
                                const SizedBox(height: 6),
                                // 2. TALLAR (SPLIT)
                                _buildCompactBtn(
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
                                const SizedBox(height: 6),
                                // 3. UNIR (MERGE)
                                _buildCompactBtn(
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
                                const SizedBox(height: 6),
                                // 4. SELECCIONAR TRAM (RANGE)
                                _buildCompactBtn(
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
                                const SizedBox(height: 6),

                                // 5. AFEGIR WAYPOINT
                                _buildCompactBtn(
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
                                const SizedBox(height: 6),

                                // 6. DIBUIXAR DE ZERO
                                _buildCompactBtn(
                                  isActive: liveActiveTool == 'draw',
                                  icon: TrackioLargeIcon(
                                    child: Icon(
                                      Icons.gesture_rounded,
                                      color: liveActiveTool == 'draw'
                                          ? Colors.pinkAccent
                                          : Colors.pink,
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
                      color: Colors.white,
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: _buildCompactBtn(
                      isActive: liveShowSidebar,
                      icon: Icon(
                        liveShowSidebar
                            ? Icons.view_sidebar
                            : Icons.view_sidebar_outlined,
                        color: Colors.blue.shade700,
                      ),
                      tooltip: "Menú",
                      onPressed: () =>
                          ref.read(gpxEditorProvider.notifier).toggleSidebar(),
                    ),
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
  Widget _buildCompactBtn({
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade50 : Colors.transparent,
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
