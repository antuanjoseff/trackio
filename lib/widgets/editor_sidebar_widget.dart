import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/vars/track_colors.dart';
import 'package:trackio/widgets/color_palette_dialog.dart';

// 🌟 EL PONT CONDICIONAL QUE SOLUCIONA L'ERROR DE L'APK D'ANDROID:
import 'package:trackio/services/gpx_exporter_io.dart'
    if (dart.library.js_interop) 'package:trackio/services/gpx_exporter_web.dart';

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
    final tracks = ref.watch(gpxEditorProvider.select((s) => s.tracks));
    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );

    // 🌟 NOVEDAT: Avaluem si estem a l'APK mòbil o pantalles compactes per estilitzar la fila
    final bool isMobile = MediaQuery.of(context).size.width <= 800;

    return Padding(
      padding: const EdgeInsets.all(
        12.0,
      ), // Una mica més estret als marges mòbils
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📥 BOTÓ IMPORTAR GPX (Només es mostra a la Web, ja que a l'APK va a dalt de l'AppBar)
          if (!isMobile) ...[
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
          ],

          // 📜 LLISTA REORDENABLE DE TRACKS ADAPTADA AMB FILA D'ACCIONS SECUNDÀRIES PER A MÒBILS
          Expanded(
            child: tracks.isEmpty
                ? Center(child: Text(t.noTracksLoaded))
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: tracks.length,
                    onReorder: (old, next) {
                      ref
                          .read(gpxEditorProvider.notifier)
                          .reorderTracks(old, next);
                    },
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final bool isSelected = track.id == selectedTrackId;
                      final Color trackBaseColor = TrackColors.fromHex(
                        track.hexColor,
                      );

                      return Card(
                        key: ValueKey("track_row_${track.id}"),
                        elevation: isSelected ? 2 : 0,
                        margin: const EdgeInsets.symmetric(
                          vertical: 6.0,
                          horizontal: 4.0,
                        ),
                        color: isSelected ? Colors.grey.shade50 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.grey.shade300
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: isSelected
                                      ? trackBaseColor
                                      : Colors.grey.shade300,
                                  width: 5.0,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🔝 LÍNIA 1: NOM DEL TRACK I DRAG HANDLE (Accessible i net)
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    track.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                      color: track.isVisible
                                          ? Colors.black87
                                          : Colors.grey.shade400,
                                      decoration: track.isVisible
                                          ? TextDecoration.none
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  trailing: ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        8.0,
                                      ), // Àrea de toc gran per moure
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        size: 20,
                                        color: isSelected
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  onTap: () => ref
                                      .read(gpxEditorProvider.notifier)
                                      .selectTrack(track.id),
                                ),

                                const Divider(height: 1, thickness: 0.5),

                                // 🛠️ LÍNIA 2: BARRA D'EINES INFERIOR AMB HITBOX COMDES (48px d'alçada mínima per a dits)
                                Container(
                                  color: isSelected
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade50,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 2.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Grup d'estat (Visibilitat i Color)
                                      Row(
                                        children: [
                                          // 👁️ CHECKBOX VISIBILITAT (Ampliat)
                                          InkWell(
                                            onTap: () => ref
                                                .read(
                                                  gpxEditorProvider.notifier,
                                                )
                                                .toggleTrackVisibility(
                                                  track.id,
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10.0,
                                                    vertical: 8.0,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    track.isVisible
                                                        ? Icons
                                                              .visibility_outlined
                                                        : Icons
                                                              .visibility_off_outlined,
                                                    size: 18,
                                                    color: track.isVisible
                                                        ? trackBaseColor
                                                        : Colors.grey,
                                                  ),
                                                  if (!isMobile)
                                                    const SizedBox(width: 4),
                                                  if (!isMobile)
                                                    Text(
                                                      track.isVisible
                                                          ? t.visible
                                                          : t.hidden,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),

                                          // 🎨 SELECTOR DE COLOR (Àrea ampliada amb cercle gran per no fallar el tap)
                                          InkWell(
                                            onTap: () => showDialog(
                                              context: context,
                                              // 🔥 PROTECCIÓ ANDROID: Evita saltar al context de navegació de l'arrel de l'app
                                              useRootNavigator: false,
                                              // 🔥 PROTECCIÓ GRÀFICA: Opacitat mínima del fons per estalviar-li recàlculs i sobrecàrrega a la GPU
                                              barrierColor: Colors.black
                                                  .withOpacity(0.01),
                                              builder: (_) =>
                                                  ColorPaletteDialog(
                                                    onColorSelected: (hex) {
                                                      ref
                                                          .read(
                                                            gpxEditorProvider
                                                                .notifier,
                                                          )
                                                          .updateTrackColor(
                                                            track.id,
                                                            hex,
                                                          );
                                                    },
                                                  ),
                                            ),

                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12.0,
                                                    vertical: 8.0,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width:
                                                        16, // Abans era 12, ara és molt més fàcil de premer
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: trackBaseColor,
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
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    t.color ?? "Color",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Grup d'accions (ComparitExportar i Esborrar)
                                      // Grup d'accions (Exportar, Compartir i Esborrar)
                                      Row(
                                        children: [
                                          // 💾 DESCARREGAR DIRECTE (Guarda a Descàrregues / Localment)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.file_download_outlined,
                                              size: 20,
                                            ),
                                            color: isSelected
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade600,
                                            tooltip: t.downloadGpx,
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 44,
                                            ),
                                            onPressed: () async {
                                              final gpxString = ref
                                                  .read(
                                                    gpxEditorProvider.notifier,
                                                  )
                                                  .generateGpxString(track);

                                              // Crida al mètode amb paràmetres nominals i traducció
                                              await GpxExporter.downloadTrackGpx(
                                                name: track.name,
                                                content: gpxString,
                                                dialogTitle:
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.saveGpxDialogTitle,
                                              );
                                            },
                                          ),

                                          // 📤 COMPARTIR (El teu mètode original de share_plus)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.share_outlined,
                                              size: 20,
                                            ),
                                            color: isSelected
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade600,
                                            tooltip: t.shareGpx,
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 44,
                                            ),
                                            onPressed: () async {
                                              final gpxString = ref
                                                  .read(
                                                    gpxEditorProvider.notifier,
                                                  )
                                                  .generateGpxString(track);

                                              // Crida al mètode de compartir modern i multillenguatge
                                              await GpxExporter.exportTrackGpx(
                                                name: track.name,
                                                content: gpxString,
                                                shareSubject: AppLocalizations.of(
                                                  context,
                                                )!.shareGpxSubject, // 👈 El teu text traduït (Ex: "Exportar ruta")
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 4),

                                          // 🗑️ ESBORRAR
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                            ),
                                            color: isSelected
                                                ? Colors.red.shade600
                                                : Colors.grey.shade500,
                                            tooltip: t.deleteTrack,
                                            constraints: const BoxConstraints(
                                              minWidth: 44,
                                              minHeight: 44,
                                            ),
                                            onPressed: () {
                                              ref
                                                  .read(
                                                    gpxEditorProvider.notifier,
                                                  )
                                                  .deleteTrack(track.id);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 🌟 EL CANVI DE BOTONS INFERIORS:
          // Si som a l'APK mòbil (isMobile), la llista de botons inferiors de dalt d'aquesta línia
          // S'ELIMINA PER COMPLET, evitant duplicats amb les noves icones flotants verticals!
          if (!isMobile) ...[
            const Divider(),
            _SidebarToolsPanel(t: t, onReverseTrack: onReverseTrack),
          ],
        ],
      ),
    );
  }
}

class _SidebarToolsPanel extends ConsumerWidget {
  final AppLocalizations t;
  final Future<void> Function(WidgetRef) onReverseTrack;

  const _SidebarToolsPanel({required this.t, required this.onReverseTrack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveActiveTool = ref.watch(
      gpxEditorProvider.select((s) => s.activeTool),
    );
    final liveShowChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );
    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );
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
                  liveActiveTool == 'split' ? t.stop : t.toolSplit,
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
          label: Text(liveActiveTool == 'merge' ? t.stopMerge : t.toolMerge),
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
            liveActiveTool == 'range_map' ? t.stopRange : t.selectRange,
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
            liveShowChart ? t.hideElevationProfile : t.showElevationProfile,
          ),
          onPressed: () =>
              ref.read(gpxEditorProvider.notifier).toggleElevationChart(),
        ),
        const SizedBox(height: 8),

        // 📍 BOTÓ ÚNIC GLOBAL PER AL MODE WAYPOINT
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
            liveActiveTool == 'add_waypoint' ? t.stopWaypoint : t.addWaypoint,
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
                Expanded(
                  child: Text(
                    t.selectTrackToUseTools,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
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

class TrackioIcons {
  static Widget reverseDirection({required Color color, double size = 16}) {
    return Icon(Icons.sync_alt_rounded, color: color, size: size);
  }

  static Widget cutGpx({required Color color, double size = 16}) {
    return Icon(Icons.content_cut_rounded, color: color, size: size * 0.75);
  }

  static Widget joinGpx({required Color color, double size = 18}) {
    return Icon(Icons.add_link_rounded, color: color, size: size);
  }

  static Widget selectAndExtract({required Color color, double size = 18}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.check_box_outline_blank_rounded,
          color: color.withAlpha(102),
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
        Icon(
          Icons.location_on_outlined,
          color: color,
          size: size,
        ), // 🌟 REPARAT: Ara és una coma, no un punt i coma
        Positioned(
          // 🌟 REPARAT: S'ha afegit el parèntesi obert que faltava
          top: size * 0.15,
          child: Icon(Icons.add, color: color, size: size * 0.45),
        ),
      ],
    );
  }
}
