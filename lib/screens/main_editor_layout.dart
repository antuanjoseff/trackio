import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/screens/trackio_horizontal_layout.dart';
import 'package:trackio/screens/trackio_vertical_layout.dart';
import 'package:trackio/widgets/editor_sidebar_widget.dart';
import 'package:trackio/widgets/range_track_selection.dart';
import 'package:trackio/widgets/trackio_icons.dart';
import 'package:trackio/widgets/trackio_large_icon.dart'; // Mantén els teus imports reals d'icones

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
    required this.onSidebarReorderDragStateChanged,
    required this.onSidebarHoverChanged,
  });

  final AppLocalizations t;
  final GpxEditorState editorState;
  final Widget mapModule;
  final bool showElevationChart;
  final bool isReverseAnimating;
  final Future<void> Function(List<TrackModel>) onPaintTracks;
  final Future<void> Function(WidgetRef) onReverseTrack;
  final VoidCallback onImportPressed;
  final ValueChanged<bool> onSidebarReorderDragStateChanged;
  final ValueChanged<bool> onSidebarHoverChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determinació de plataforma segons l'amplada física de la pantalla
    final bool isMobile = MediaQuery.of(context).size.width <= 800;

    // Selectors atòmics optimitzats de Riverpod
    final liveActiveTool = ref.watch(
      gpxEditorProvider.select((s) => s.activeTool),
    );
    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );
    final liveShowChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );
    final canUndoAction = ref.watch(
      gpxEditorProvider.select((s) => s.canUndoAction),
    );
    final currentFullState = ref.watch(gpxEditorProvider);

    final bool isDisabled = selectedTrackId == null;
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false,
          // 📱 APARTAT MÒBIL: El sidebar es converteix en un menú lateral natiu (Drawer)
          drawer: isMobile
              ? Drawer(
                  width:
                      MediaQuery.of(context).size.width *
                      0.85, // Deixa veure una franja del mapa al costat
                  child: SafeArea(
                    child: Column(
                      children: [
                        // 🌟 LA NOVA X DE TANCAR AUTOMÀTICA INTEGRADA AL DRAWER MÒBIL
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8.0,
                            right: 8.0,
                            left: 16.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t.importTracks.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.starTrekRed,
                                  size: 22,
                                ),
                                tooltip: "Tancar",
                                onPressed: () => Navigator.pop(
                                  context,
                                ), // Tanca el Drawer nàtivament a l'APK
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Pintem la llista de tracks a sota de la X
                        Expanded(
                          child: EditorSidebarWidget(
                            state: currentFullState,
                            t: t,
                            onPaintTracks: onPaintTracks,
                            onReverseTrack: onReverseTrack,
                            onImportPressed: onImportPressed,
                            onReorderDragStateChanged:
                                onSidebarReorderDragStateChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          // 🚀 Si és mòbil i està de costat (Landscape), eliminem la barra nativa tornant null
          appBar: (isMobile && isLandscape)
              ? null
              : AppBar(
                  automaticallyImplyLeading: false,
                  titleSpacing: 12,
                  centerTitle: false,
                  leading: isMobile
                      ? Builder(
                          builder: (ctx) => Center(
                            child: IconButton(
                              tooltip: "Sidebar",
                              icon: const Icon(
                                Icons.menu_rounded,
                                color: AppColors.appBarForeground,
                                size: 20,
                              ),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                        )
                      : null,
                  title: Text(t.appTitle),
                  actions: [
                    // 🌐 ACCIONS FILTRADES: Si som a la Web (!isMobile) pintem totes les eines horitzontals
                    if (!isMobile) ...[
                      // 🔄 1. INVERTIR TRACK
                      IconButton(
                        tooltip: t.toolInverse,
                        icon: TrackioIcons.reverseDirection(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : AppColors.appBarForeground,
                        ),
                        onPressed: isDisabled
                            ? null
                            : () => onReverseTrack(ref),
                      ),

                      // ✂️ 2. TALLAR TRACK (SPLIT)
                      IconButton(
                        tooltip: t.toolSplit,
                        isSelected: liveActiveTool == 'split',
                        selectedIcon: TrackioIcons.cutGpx(
                          color: AppColors.mapToolActiveForeground,
                          size: 20,
                        ),
                        icon: TrackioIcons.cutGpx(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : AppColors.appBarForeground,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: liveActiveTool == 'split'
                              ? AppColors.mapToolActiveBackground
                              : null,
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

                      // 🔗 3. UNIR TRACKS (MERGE)
                      IconButton(
                        tooltip: t.toolMerge,
                        isSelected: liveActiveTool == 'merge',
                        selectedIcon: TrackioIcons.joinGpx(
                          color: AppColors.mapToolActiveForeground,
                        ),
                        icon: TrackioIcons.joinGpx(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : AppColors.appBarForeground,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: liveActiveTool == 'merge'
                              ? AppColors.mapToolActiveBackground
                              : null,
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

                      // 📐 4. SELECCIONAR TRAM
                      // ⚡ NOU CODI UNIFICAT (Igual a la resta):
                      IconButton(
                        tooltip: t.selectRange,
                        isSelected: liveActiveTool == 'range_map',
                        selectedIcon: TrackioLargeIcon(
                          child: TrackRangeSelection(
                            color: AppColors.mapToolActiveForeground,
                          ),
                        ),
                        icon: TrackioLargeIcon(
                          child: TrackRangeSelection(
                            color: isDisabled
                                ? Colors.grey.shade400
                                : AppColors.appBarForeground,
                          ),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: liveActiveTool == 'range_map'
                              ? AppColors.mapToolActiveBackground
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
                        tooltip: t.addWaypoint,
                        isSelected: liveActiveTool == 'add_waypoint',
                        selectedIcon: TrackioIcons.addWaypoint(
                          color: AppColors.mapToolActiveForeground,
                        ),
                        icon: TrackioIcons.addWaypoint(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : AppColors.appBarForeground,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: liveActiveTool == 'add_waypoint'
                              ? AppColors.mapToolActiveBackground
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

                      // 🎨 5.2. EINA DIBUIXAR RUTA DE ZERO
                      IconButton(
                        tooltip: t.toolDraw,
                        isSelected: liveActiveTool == 'draw',
                        selectedIcon: const Icon(
                          Icons.gesture_rounded,
                          color: AppColors.mapToolActiveForeground,
                          size: 20,
                        ),
                        icon: const Icon(
                          Icons.gesture_rounded,
                          color: AppColors.appBarForeground,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: liveActiveTool == 'draw'
                              ? AppColors.mapToolActiveBackground
                              : null,
                        ),
                        onPressed: () => ref
                            .read(gpxEditorProvider.notifier)
                            .setActiveTool(
                              liveActiveTool == 'draw' ? 'none' : 'draw',
                            ),
                      ),

                      // 🧩 5.3. EDITAR GEOMETRIA
                      IconButton(
                        tooltip: t.toolEditGeometry,
                        isSelected: liveActiveTool == 'edit_geometry',
                        selectedIcon: Icon(
                          Icons.hub_rounded,
                          color: AppColors.mapToolActiveForeground,
                        ),
                        icon: Icon(
                          Icons.hub_rounded,
                          color: isDisabled
                              ? Colors.grey.shade400
                              : AppColors.appBarForeground,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: liveActiveTool == 'edit_geometry'
                              ? AppColors.mapToolActiveBackground
                              : null,
                        ),
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

                      IconButton(
                        tooltip: t.undoGeometryEdit,
                        icon: Icon(
                          Icons.undo_rounded,
                          color: canUndoAction
                              ? AppColors.appBarForeground
                              : Colors.white54,
                        ),
                        onPressed: canUndoAction
                            ? () => ref
                                  .read(gpxEditorProvider.notifier)
                                  .undoLastAction()
                            : null,
                      ),

                      const VerticalDivider(
                        indent: 12,
                        endIndent: 12,
                        width: 16,
                        color: Colors.white,
                      ),
                    ],

                    // ↕️ 6. GRÀFIC D'ELEVACIONS (només a web)
                    if (!isMobile) ...[
                      IconButton(
                        tooltip: t.elevationProfile,
                        icon: Icon(
                          liveShowChart
                              ? Icons.insert_chart
                              : Icons.insert_chart_outlined,
                          color: liveShowChart
                              ? AppColors.mapToolActiveForeground
                              : Colors.white70,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: liveShowChart
                              ? AppColors.mapToolActiveBackground
                              : null,
                        ),
                        onPressed: () => ref
                            .read(gpxEditorProvider.notifier)
                            .toggleElevationChart(),
                      ),

                      const VerticalDivider(
                        indent: 12,
                        endIndent: 12,
                        width: 16,
                        color: Colors.white,
                      ),
                    ],

                    IconButton(
                      tooltip: t.importTracks,
                      icon: const Icon(
                        Icons.upload,
                        color: AppColors.appBarForeground,
                        size: 20,
                      ),
                      onPressed: onImportPressed,
                    ),

                    const SizedBox(width: 8),
                  ],
                ),
          body: OrientationBuilder(
            builder: (context, orientation) {
              if (orientation == Orientation.portrait) {
                return TrackioVerticalLayout(
                  t: t,
                  editorState: editorState,
                  mapModule: mapModule,
                  showElevationChart: showElevationChart,
                  isReverseAnimating: isReverseAnimating,
                  onPaintTracks: onPaintTracks,
                  onReverseTrack: onReverseTrack,
                  onImportPressed: onImportPressed,
                );
              } else {
                return TrackioHorizontalLayout(
                  t: t,
                  editorState: editorState,
                  mapModule: mapModule,
                  showElevationChart: showElevationChart,
                  onPaintTracks: onPaintTracks,
                  onReverseTrack: onReverseTrack,
                  onImportPressed: onImportPressed,
                  onSidebarReorderDragStateChanged:
                      onSidebarReorderDragStateChanged,
                  onSidebarHoverChanged: onSidebarHoverChanged,
                );
              }
            },
          ),
        ),

        // PANTALLA BORROSA DE PROCESSAMENT (Es queda intacta)
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
                      const CircularProgressIndicator(
                        color: AppColors.starTrekRed,
                      ),
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
