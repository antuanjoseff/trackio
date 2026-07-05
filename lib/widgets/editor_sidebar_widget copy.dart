import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/vars/track_colors.dart';
import 'package:trackio/widgets/color_palette_dialog.dart';
import 'package:web/web.dart' as web;

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
    // 🌟 REPARAT: Escoltem la llista de tracks en viu de Riverpod de forma directa
    final tracks = ref.watch(gpxEditorProvider.select((s) => s.tracks));

    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );

    // Esborra completament les línies velles de 'liveTracks.isNotEmpty ? ...'
    // que feien que la llista es congelés en quedar-se buida.

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

                          // ⬅️ ESQUERRA (LEADING EN ROW EXTÈS): TIRADOR + COLOR + VISIBILITAT
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Tirador de reordenació original
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(
                                  Icons.more_vert,
                                  size: 22,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),

                              // COLOR PICKER (A l'esquerra del nom)
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
                              const SizedBox(width: 4),

                              // CHECKBOX VISIBILITAT (A l'esquerra del nom)
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

                          // 🏷️ CENTRE: NOM DEL TRACK INTENS (S'ajusta sol al buit restant)
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

                          // ➡️ Dreta (Trailing): El teu codi original sense condicions de loading
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 📥 ICONA DE DESCARREGA
                              IconButton(
                                icon: const Icon(
                                  Icons.download,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: "Exportar GPX",

                                onPressed: () {
                                  // 1. Generem el contingut del text GPX/XML a través del teu Notifier
                                  final gpxString = ref
                                      .read(gpxEditorProvider.notifier)
                                      .generateGpxString(track);

                                  // 2. LA DRECURA NETEJA SENSE LLIBRERIES: Convertim el text a Base64
                                  // Això és ideal per a fitxers de text pla com el XML de GPX
                                  final bytes = utf8.encode(gpxString);
                                  final base64String = base64.encode(bytes);

                                  // Creem una URL de dades directa que el navegador web entén de forma nativa
                                  final dataUrl =
                                      'data:application/gpx+xml;charset=utf-8;base64,$base64String';

                                  // 3. INJECTEM L'ELEMENT HTML VISUAL DE FORMA ULTRA COMPACTA
                                  // Creem un element d'ancoratge invisible, li assignem la URL i simulem el click
                                  web.HTMLAnchorElement()
                                    ..href = dataUrl
                                    ..setAttribute(
                                      'download',
                                      '${track.name}.gpx',
                                    )
                                    ..click();

                                  debugPrint(
                                    "💾 Fitxer ${track.name}.gpx descarregat nàticament via Base64.",
                                  );
                                },
                              ),
                              const SizedBox(width: 12),

                              // 🗑️ ICONA DE CANCEL·LACIÓ / PAPERERA
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade600,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: "Eliminar track",
                                onPressed: () async {
                                  ref
                                      .read(gpxEditorProvider.notifier)
                                      .deleteTrack(track.id);
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

    // Extraiem el track seleccionat per saber si els botons han d'estar actius o blocats
    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );

    // Comprovem si les eines han d'estar completament deshabilitades
    final bool isDisabled = selectedTrackId == null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // ↩️ INVERTIR TRACK
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: isDisabled ? null : () => onReverseTrack(ref),
                icon: TrackioIcons.reverseDirection(
                  color: isDisabled ? Colors.grey : Colors.blue.shade700,
                ),
                label: Text(
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
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
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
                icon: TrackioIcons.cutGpx(
                  color: isDisabled
                      ? Colors.grey
                      : (liveActiveTool == 'split'
                            ? Colors.purple.shade800
                            : Colors.purple),
                ),
                label: Text(
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
            backgroundColor: liveActiveTool == 'merge'
                ? Colors.teal.shade50
                : null,
          ),
          icon: TrackioIcons.joinGpx(
            color: isDisabled
                ? Colors.grey
                : (liveActiveTool == 'merge'
                      ? Colors.teal.shade800
                      : Colors.teal),
          ),
          label: Text(liveActiveTool == 'merge' ? "Aturar Unió" : t.toolMerge),
          onPressed: isDisabled
              ? null
              : () => ref
                    .read(gpxEditorProvider.notifier)
                    .setActiveTool(
                      liveActiveTool == 'merge' ? 'none' : 'merge',
                    ),
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
          icon: TrackioIcons.selectAndExtract(
            color: isDisabled
                ? Colors.grey
                : (liveActiveTool == 'range_map'
                      ? Colors.orange.shade800
                      : Colors.orange),
          ),
          label: Text(
            liveActiveTool == 'range_map' ? "Aturar Tram" : "Seleccionar Tram",
          ),
          onPressed: isDisabled
              ? null
              : () => ref
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
            backgroundColor: liveShowChart ? Colors.blue.shade50 : null,
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
        const SizedBox(height: 8),

        // 📍 BOTÓ ÚNIC GLOBAL PER AL MODE WAYPOINT (TRACK ACTIU)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
            backgroundColor: liveActiveTool == 'add_waypoint'
                ? Colors.blue.shade700
                : null,
            foregroundColor: liveActiveTool == 'add_waypoint'
                ? Colors.white
                : null,
          ),
          icon: TrackioIcons.addWaypoint(
            color: isDisabled
                ? Colors.grey
                : (liveActiveTool == 'add_waypoint'
                      ? Colors.white
                      : Colors.blue.shade800),
          ),
          label: Text(
            liveActiveTool == 'add_waypoint'
                ? "Aturar Waypoint"
                : "Afegir Waypoint",
          ),
          onPressed: isDisabled
              ? null
              : () {
                  if (liveActiveTool == 'add_waypoint') {
                    ref.read(gpxEditorProvider.notifier).setActiveTool('none');
                  } else {
                    ref
                        .read(gpxEditorProvider.notifier)
                        .setActiveTool('add_waypoint');
                  }
                },
        ),

        // 🔒 INFORMA AL L'USUARI SI NO HI HA RES SELECCIONAT
        if (isDisabled) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Selecciona un track de la llista per utilitzar les eines.",
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// 🎨 COMPOSICIÓ D'ICONES VECTORIALS PER A LA MARCA TRACKIO
class TrackioIcons {
  static Widget reverseDirection({required Color color, double size = 16}) {
    return Icon(Icons.sync_alt_rounded, color: color, size: size);
  }

  static Widget cutGpx({required Color color, double size = 16}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.timeline_rounded,
          color: color.withOpacity(0.35),
          size: size,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Icon(
            Icons.content_cut_rounded,
            color: color,
            size: size * 0.75,
          ),
        ),
      ],
    );
  }

  static Widget joinGpx({required Color color, double size = 18}) {
    return Icon(Icons.add_link_rounded, color: color, size: size);
  }

  static Widget selectAndExtract({required Color color, double size = 18}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Icona de selecció rectangular/marquesina vàlida en Flutter
        Icon(
          Icons.check_box_outline_blank_rounded,
          color: color.withOpacity(0.4),
          size: size,
        ),
        Icon(Icons.insights_rounded, color: color, size: size * 0.75),
      ],
    );
  }

  static Widget addWaypoint({required Color color, double size = 18}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.location_on_outlined, color: color, size: size),
        Positioned(
          top: size * 0.15,
          child: Icon(Icons.add, color: color, size: size * 0.45),
        ),
      ],
    );
  }
}
