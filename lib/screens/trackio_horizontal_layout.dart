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
import 'package:trackio/widgets/editor_sidebar_widget.dart'; // 🌟 NOU IMPORT

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
    // 🌟 NOU SELECTOR: Escolta l'estat dinàmic del sidebar global
    final liveShowSidebar = ref.watch(
      gpxEditorProvider.select((s) => s.showSidebar),
    );

    final bool isDisabled = selectedTrackId == null;
    final bool isMobile = MediaQuery.of(context).size.width <= 800;

    return Column(
      children: [
        Expanded(
          // 🌐 EN WEB UNIM SIDEBAR I MAPA EN UNA FILA FLUIDA
          child: Row(
            children: [
              // ⚡ SIDEBAR NET PER A WEB: Si és Web i l'estat és true, s'acobla de forma fixa a la pantalla
              if (!isMobile && liveShowSidebar)
                Container(
                  width: 320, // Amplada de la barra lateral d'escriptori
                  color: Colors.white,
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

              // L'àrea del mapa i els seus botons flotants contextuals
              Expanded(
                child: Stack(
                  children: [
                    // 🗺️ FONS: El mòdul de mapa ocupa tota la pantalla disponible
                    Positioned.fill(child: mapModule),
                    // 👈 COLUMNA ESQUERRA: Dinàmica segons la plataforma
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
                              // 1. AQUEST SURT SEMPRE: Toggle sidebar en Web o Drawer en Mòbil
                              _buildCompactBtn(
                                isActive: !isMobile && liveShowSidebar,
                                icon: Icon(
                                  isMobile
                                      ? Icons.menu_rounded
                                      : (liveShowSidebar
                                            ? Icons.view_sidebar
                                            : Icons.view_sidebar_outlined),
                                  color: Colors.blue.shade700,
                                ),
                                tooltip: "Menú",
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

                              // 🌟 ELS SEGUENTS BOTONS NOMÉS SURTEN EN MÒBIL (S'amaguen completament en Web)
                              if (isMobile) ...[
                                const SizedBox(height: 6),
                                // 2. IMPORTAR GPX (Només mòbil)
                                _buildCompactBtn(
                                  icon: const Icon(
                                    Icons.upload,
                                    color: Colors.blue,
                                  ),
                                  tooltip: t.importTracks,
                                  onPressed: onImportPressed,
                                ),
                                const SizedBox(height: 6),
                                // 3. MOSTRAR GRÀFIC D'ELEVACIONS (Només mòbil)
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
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 👉 COLUMNA DRETA: Eines d'edició flotants (❌ NOMÉS VISIBLE EN MÒBILS per evitar duplicats)
                    if (isMobile)
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

        // Barra de dades inferior (Es manté intacta a baix de tot)
        const TrackStatsPanel(),

        // Gràfic d'elevacions comprimit en alçada per a telèfons de costat
        if (showElevationChart)
          ElevationChartPanel(
            editorState: editorState,
            height: isMobile ? 110 : 140,
          ),
      ],
    );
  }

  // 📐 BOTONS D'ALTA DENSITAT: Capsa forçada de 38x38 píxels sense padding residual
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
