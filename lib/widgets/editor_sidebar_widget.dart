import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/vars/track_colors.dart';
import 'package:trackio/widgets/color_palette_dialog.dart';

class EditorSidebarWidget extends ConsumerWidget {
  final GpxEditorState state;
  final AppLocalizations t;
  final Future<void> Function(List<TrackModel>) onPaintTracks;
  final Future<void> Function(WidgetRef) onReverseTrack;
  final VoidCallback onImportPressed;

  const EditorSidebarWidget({
    super.key,
    required this.state,
    required this.t,
    required this.onPaintTracks,
    required this.onReverseTrack,
    required this.onImportPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escoltadors vius de Riverpod per forçar el repintat instantani en importar o tallar
    final liveTracks = ref.watch(gpxEditorProvider.select((s) => s.tracks));
    final liveSelectedId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );

    final tracks = liveTracks.isNotEmpty ? liveTracks : state.tracks;
    final selectedTrackId = liveTracks.isNotEmpty
        ? liveSelectedId
        : state.selectedTrackId;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📥 BOTÓ IMPORTAR GPX
          InkWell(
            onTap: onImportPressed,
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

          // 📜 LLISTA REORDENABLE DE TRACKS
          Expanded(
            child: tracks.isEmpty
                ? const Center(child: Text("Sense tracks carregats"))
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: tracks.length,
                    onReorder: (old, next) async {
                      ref
                          .read(gpxEditorProvider.notifier)
                          .reorderTracks(old, next);
                      await onPaintTracks(ref.read(gpxEditorProvider).tracks);
                    },
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final bool isSelected = track.id == selectedTrackId;

                      return Container(
                        key: ValueKey("track_row_${track.id}"),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                        ),
                        child: ListTile(
                          selected: isSelected,
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(
                              Icons.more_vert,
                              size: 22,
                              color: Colors.grey,
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // COLOR PICKER
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => ColorPaletteDialog(
                                    onColorSelected: (hex) async {
                                      ref
                                          .read(gpxEditorProvider.notifier)
                                          .updateTrackColor(track.id, hex);
                                      await onPaintTracks(
                                        ref.read(gpxEditorProvider).tracks,
                                      );
                                    },
                                  ),
                                ),
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: TrackColors.fromHex(track.hexColor),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // CHECKBOX VISIBILITAT
                              Checkbox(
                                value: track.isVisible,
                                activeColor: Color(
                                  int.parse(
                                    track.hexColor.replaceAll('#', '0xFF'),
                                  ),
                                ),
                                onChanged: (bool? val) async {
                                  ref
                                      .read(gpxEditorProvider.notifier)
                                      .toggleTrackVisibility(track.id);
                                  await onPaintTracks(
                                    ref.read(gpxEditorProvider).tracks,
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () => ref
                              .read(gpxEditorProvider.notifier)
                              .selectTrack(track.id),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),

          // 🛠️ INVOCACIÓ DEL NOU SUB-WIDGET DE BOTONS
          _SidebarToolsPanel(t: t, onReverseTrack: onReverseTrack),
        ],
      ),
    );
  }
}

// 🛠️ SUB-WIDGET EXTRET: Simplifica i redueix la mida de la barra lateral
class _SidebarToolsPanel extends ConsumerWidget {
  final AppLocalizations t;
  final Future<void> Function(WidgetRef) onReverseTrack;

  const _SidebarToolsPanel({required this.t, required this.onReverseTrack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escoltem l'eina activa de Riverpod per fer que els botons reaccionin de forma aïllada
    final liveActiveTool = ref.watch(
      gpxEditorProvider.select((s) => s.activeTool),
    );
    final liveShowChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // ↩️ INVERTIR TRACK
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: () => onReverseTrack(ref),
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
            // ✂️ TALLAR TRACK (SPLIT)
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: liveActiveTool == 'split'
                      ? Colors.purple.shade50
                      : null,
                ),
                onPressed: () => ref
                    .read(gpxEditorProvider.notifier)
                    .setActiveTool(
                      liveActiveTool == 'split' ? 'none' : 'split',
                    ),
                child: Text(
                  liveActiveTool == 'split' ? "Aturar" : t.toolSplit,
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
        // 🔗 UNIR TRACKS (MERGE)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
          ),
          icon: const Icon(Icons.link),
          label: Text(liveActiveTool == 'merge' ? "Aturar Unió" : t.toolMerge),
          onPressed: () => ref
              .read(gpxEditorProvider.notifier)
              .setActiveTool(liveActiveTool == 'merge' ? 'none' : 'merge'),
        ),
        const SizedBox(height: 8),
        // 📊 SELECCIONAR TRAM (RANGE MAP)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
            backgroundColor: liveActiveTool == 'range_map'
                ? Colors.orange.shade50
                : null,
          ),
          icon: const Icon(Icons.analytics_outlined),
          label: Text(
            liveActiveTool == 'range_map' ? "Aturar Tram" : "Seleccionar Tram",
          ),
          onPressed: () => ref
              .read(gpxEditorProvider.notifier)
              .setActiveTool(
                liveActiveTool == 'range_map' ? 'none' : 'range_map',
              ),
        ),
        const SizedBox(height: 8),
        // ↕️ TOGGLE GRÀFIC ELEVACIONS
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(36),
          ),
          icon: Icon(liveShowChart ? Icons.expand_more : Icons.expand_less),
          label: Text(
            liveShowChart
                ? "Amagar perfil d'altituds"
                : "Mostrar perfil d'altituds",
          ),
          onPressed: () =>
              ref.read(gpxEditorProvider.notifier).toggleElevationChart(),
        ),
      ],
    );
  }
}
