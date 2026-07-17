import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/vars/track_colors.dart';
import 'package:trackio/widgets/color_palette_dialog.dart';

// 🌟 EL PONT CONDICIONAL QUE SOLUCIONA L'ERROR DE L'APK D'ANDROID:
import 'package:trackio/services/gpx_exporter_stub.dart'
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

          // 📜 LLISTA REORDENABLE DE TRACKS TOTALMENT ADAPTADA PER EVITAR COLUMNES VERTICALS
          Expanded(
            child: tracks.isEmpty
                ? Center(child: Text(t.noTracksLoaded))
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
                      final Color trackBaseColor = TrackColors.fromHex(
                        track.hexColor,
                      );

                      return AnimatedContainer(
                        key: ValueKey("track_row_${track.id}"),
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.grey.shade100
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.grey.shade300
                                : Colors.transparent,
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: isSelected
                                      ? trackBaseColor
                                      : Colors.transparent,
                                  width: 4.0,
                                ),
                              ),
                            ),
                            child: ListTile(
                              selected: isSelected,
                              selectedColor: Colors.black,
                              dense: true,
                              contentPadding: const EdgeInsets.only(
                                left: 6,
                                right: 8,
                                top: 2,
                                bottom: 2,
                              ),

                              // 🌟 SECCIÓ ESQUERRA COMPACTADA: En mòbils reduïm espais per donar aire al nom
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 18,
                                      color: isSelected
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(width: 2),

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
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: trackBaseColor,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(
                                              30,
                                            ), // Ara és dinàmic i legal amb un enter!
                                            blurRadius: 2,
                                            offset: const Offset(
                                              0,
                                              1,
                                            ), // El const es queda només a l'Offset que és fix
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),

                                  // CHECKBOX VISIBILITAT
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Checkbox(
                                      value: track.isVisible,
                                      activeColor: trackBaseColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
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
                                  ),
                                ],
                              ),

                              // 🌟 EL CANVI CRÍTIC: Emboliquem el títol perquè es pinti en línia horitzontal àmplia
                              title: Text(
                                track.name,
                                maxLines:
                                    1, // Forçem una sola línia per a una estètica polida
                                overflow: TextOverflow
                                    .ellipsis, // Si és hiperllarg, posa punts suspensius
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                  color: track.isVisible
                                      ? (isSelected
                                            ? Colors.black
                                            : Colors.black87)
                                      : Colors.grey.shade400,
                                  decoration: track.isVisible
                                      ? TextDecoration.none
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.file_download_outlined,
                                      color: isSelected
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade500,
                                      size: 18,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: t.exportGpx,
                                    onPressed: () {
                                      final gpxString = ref
                                          .read(gpxEditorProvider.notifier)
                                          .generateGpxString(track);

                                      // Crida multiplataforma segura al pont condicional
                                      GpxExporter.exportTrackGpx(
                                        track.name,
                                        gpxString,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: isSelected
                                          ? Colors.red.shade600
                                          : Colors.grey.shade400,
                                      size: 18,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: t.deleteTrack,
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.timeline_rounded,
          color: color.withAlpha(89), // 🌟 MODIFICAT: 0.35 * 255 = ~89 en Alpha
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
