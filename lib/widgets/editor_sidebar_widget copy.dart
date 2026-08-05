import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
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
  final ValueChanged<bool> onReorderDragStateChanged;

  const EditorSidebarWidget({
    super.key,
    required this.state,
    required this.t,
    required this.onPaintTracks,
    required this.onReverseTrack,
    required this.onImportPressed,
    required this.onReorderDragStateChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(gpxEditorProvider.select((s) => s.tracks));
    final selectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );

    // 🌟 NOVEDAT: Avaluem si estem a l'APK mòbil o pantalles compactes per estilitzar la fila
    final bool isMobile = MediaQuery.of(context).size.width <= 800;

    return Container(
      color: AppColors.starTrekGold,
      child: Padding(
        padding: const EdgeInsets.all(
          12.0,
        ), // Una mica més estret als marges mòbils
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:
              MainAxisSize.min, // Força el desplegament compacte vertical
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
                          color: Colors.white,
                        ),
                      ),
                      const Icon(
                        Icons.add_circle_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.white54),
            ],

            // 📜 LLISTA REORDENABLE DE TRACKS (⚡ DUAL: Mòbil s'estira, Web s'adapta al contingut)
            if (isMobile)
              Expanded(
                child: _buildTracksListView(
                  ref,
                  tracks,
                  selectedTrackId,
                  isMobile,
                  context,
                ),
              )
            else
              Flexible(
                child: _buildTracksListView(
                  ref,
                  tracks,
                  selectedTrackId,
                  isMobile,
                  context,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 📐 CONTENIDOR ÚNIC DE LA LLISTA AMB SHRINWRAP INTEL·LIGENT
  Widget _buildTracksListView(
    WidgetRef ref,
    List<TrackModel> tracks,
    int? selectedTrackId,
    bool isMobile,
    BuildContext context,
  ) {
    if (tracks.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 0.0 : 20.0),
        child: Center(
          child: Text(
            t.noTracksLoaded,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap:
          !isMobile, // 🌟 A la Web es tanca a la mida exacta de les files
      physics: isMobile ? const ScrollPhysics() : const ClampingScrollPhysics(),
      itemCount: tracks.length,
      onReorderStart: (_) => onReorderDragStateChanged(true),
      onReorderEnd: (_) => onReorderDragStateChanged(false),
      onReorder: (old, next) async {
        ref.read(gpxEditorProvider.notifier).reorderTracks(old, next);
        await onPaintTracks(ref.read(gpxEditorProvider).tracks);
      },
      itemBuilder: (context, index) {
        final track = tracks[index];
        final bool isSelected = track.id == selectedTrackId;
        final Color trackBaseColor = TrackColors.fromHex(track.hexColor);

        return Card(
          key: ValueKey("track_row_${track.id}"),
          elevation: isSelected ? 2 : 0,
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          color: isSelected ? Colors.grey.shade50 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? Colors.grey.shade300 : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isSelected ? trackBaseColor : Colors.grey.shade300,
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
                        padding: const EdgeInsets.all(8.0),
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

                  // 🛠️ LÍNIA 2: BARRA D'EINES INFERIOR AMB HITBOX COMDES
                  Container(
                    color: isSelected
                        ? Colors.grey.shade100
                        : Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Grup d'estat (Visibilitat i Color)
                        Row(
                          children: [
                            // 👁️ CHECKBOX VISIBILITAT (Ampliat)
                            InkWell(
                              onTap: () async {
                                ref
                                    .read(gpxEditorProvider.notifier)
                                    .toggleTrackVisibility(track.id);
                                await onPaintTracks(
                                  ref.read(gpxEditorProvider).tracks,
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      track.isVisible
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: track.isVisible
                                          ? trackBaseColor
                                          : Colors.grey,
                                    ),
                                    if (!isMobile) const SizedBox(width: 4),
                                    if (!isMobile)
                                      Text(
                                        track.isVisible ? t.visible : t.hidden,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // 🎨 SELECTOR DE COLOR
                            InkWell(
                              onTap: () => showDialog(
                                context: context,
                                useRootNavigator: false,
                                barrierColor: Colors.black.withOpacity(0.01),
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
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
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
                                      t.color,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Grup d'accions (Exportar, Compartir i Esborrar)
                        Row(
                          children: [
                            // 💾 DESCARREGAR DIRECTE
                            IconButton(
                              icon: const Icon(
                                Icons.file_download_outlined,
                                size: 20,
                              ),
                              color: isSelected
                                  ? AppColors.starTrekRed
                                  : Colors.grey.shade600,
                              tooltip: t.downloadGpx,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 44,
                              ),
                              onPressed: () async {
                                final gpxString = ref
                                    .read(gpxEditorProvider.notifier)
                                    .generateGpxString(track);
                                await GpxExporter.downloadTrackGpx(
                                  name: track.name,
                                  content: gpxString,
                                  dialogTitle: AppLocalizations.of(
                                    context,
                                  )!.saveGpxDialogTitle,
                                );
                              },
                            ),

                            // 📤 COMPARTIR
                            if (isMobile)
                              IconButton(
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 20,
                                ),
                                color: isSelected
                                    ? AppColors.starTrekRed
                                    : Colors.grey.shade600,
                                tooltip: t.shareGpx,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 44,
                                ),
                                onPressed: () async {
                                  final gpxString = ref
                                      .read(gpxEditorProvider.notifier)
                                      .generateGpxString(track);
                                  await GpxExporter.exportTrackGpx(
                                    name: track.name,
                                    content: gpxString,
                                    shareSubject: AppLocalizations.of(
                                      context,
                                    )!.shareGpxSubject,
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
                                  ? AppColors.starTrekRed
                                  : Colors.grey.shade500,
                              tooltip: t.deleteTrack,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
