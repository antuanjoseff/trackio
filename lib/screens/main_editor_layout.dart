import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/screens/trackio_horizontal_layout.dart';
import 'package:trackio/screens/trackio_vertical_layout.dart';
import 'package:trackio/widgets/editor_sidebar_widget.dart';
import 'package:trackio/widgets/elevation_chart_panel.dart';
import 'package:trackio/widgets/range_track_selection.dart';
import 'package:trackio/widgets/track_stats_panel.dart';
import 'package:trackio/widgets/reactive_editor_buttons.dart';
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
    debugPrint(
      "Trackio media.query viewinsets bottom: ${MediaQuery.of(context).viewInsets.bottom}",
    );
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
    final liveShowSidebar = ref.watch(
      gpxEditorProvider.select((s) => s.showSidebar),
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
                                  color: Colors.grey,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.redAccent,
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
                  leading: Center(
                    child: Container(
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: t.importTracks,
                        icon: const Icon(
                          Icons.upload,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: onImportPressed,
                      ),
                    ),
                  ),
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
                              : Colors.blue,
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
                          color: Colors.purple.shade700,
                          size: 20,
                        ),
                        icon: TrackioIcons.cutGpx(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : Colors.purple,
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
                          color: Colors.teal.shade700,
                        ),
                        icon: TrackioIcons.joinGpx(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : Colors.teal,
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
                                    liveActiveTool == 'merge'
                                        ? 'none'
                                        : 'merge',
                                  ),
                      ),

                      // 📐 4. SELECCIONAR TRAM
                      _buildFloatingButton(
                        isActive: liveActiveTool == 'range_map',
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

                      // 📍 5. AFEGIR WAYPOINT
                      IconButton(
                        tooltip: t.addWaypoint,
                        isSelected: liveActiveTool == 'add_waypoint',
                        selectedIcon: TrackioIcons.addWaypoint(
                          color: Colors.indigo.shade700,
                        ),
                        icon: TrackioIcons.addWaypoint(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : Colors.indigo,
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

                      // 🎨 5.2. EINA DIBUIXAR RUTA DE ZERO
                      IconButton(
                        tooltip: t.toolDraw,
                        isSelected: liveActiveTool == 'draw',
                        selectedIcon: const Icon(
                          Icons.gesture_rounded,
                          color: Colors.pinkAccent,
                          size: 20,
                        ),
                        icon: const Icon(
                          Icons.gesture_rounded,
                          color: Colors.pink,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: liveActiveTool == 'draw'
                              ? Colors.pink.shade50
                              : null,
                        ),
                        onPressed: () => ref
                            .read(gpxEditorProvider.notifier)
                            .setActiveTool(
                              liveActiveTool == 'draw' ? 'none' : 'draw',
                            ),
                      ),

                      const VerticalDivider(
                        indent: 12,
                        endIndent: 12,
                        width: 16,
                      ),
                    ],

                    // ↕️ 6. GRÀFIC D'ELEVACIONS
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
                      style: IconButton.styleFrom(
                        backgroundColor: liveShowChart
                            ? Colors.blue.shade50
                            : null,
                      ),
                      onPressed: () => ref
                          .read(gpxEditorProvider.notifier)
                          .toggleElevationChart(),
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

  Widget _buildFloatingButton({
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
