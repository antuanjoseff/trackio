import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/vars/track_colors.dart';
import 'package:trackio/widgets/color_palette_dialog.dart';

// El pont condicional per a l'exportació de fitxers GPX en multiplataforma
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
    final bool isMobile = MediaQuery.of(context).size.width <= 800;

    return SizedBox.expand(
      child: Container(
        color: AppColors.editorSidebarBackground,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botó d'importar rutes exclusiu de la Web (Al mòbil es fa per l'AppBar o Drawer)
              if (!isMobile) ...[
                InkWell(
                  onTap: onImportPressed,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.importGpx.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.8,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Icon(
                          Icons.add_circle_outline,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Llistat dinàmic adaptatiu amb shrinkWrap intel·ligent
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
      ),
    );
  }

  Widget _buildTracksListView(
    WidgetRef ref,
    List<TrackModel> tracks,
    int? selectedTrackId,
    bool isMobile,
    BuildContext context,
  ) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          t.noTracksLoaded,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: !isMobile,
      physics: isMobile
          ? const AlwaysScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
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

        return Container(
          key: ValueKey("track_row_${track.id}"),
          margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 2.0),
          decoration: BoxDecoration(
            color: AppColors.editorTrackCardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.appBarBackground
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? trackBaseColor.withOpacity(0.12)
                    : Colors.black.withOpacity(0.02),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 12.0, right: 4.0),
                  title: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: trackBaseColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          track.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 13.5,
                            color: track.isVisible
                                ? Colors.grey.shade900
                                : Colors.grey.shade400,
                            decoration: track.isVisible
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  onTap: () => ref
                      .read(gpxEditorProvider.notifier)
                      .selectTrack(track.id),
                ),
                Divider(height: 1, thickness: 0.5, color: Colors.grey.shade100),
                Container(
                  color: isSelected ? Colors.grey.shade50 : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
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
                                horizontal: 8.0,
                                vertical: 6.0,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    track.isVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 17,
                                    color: track.isVisible
                                        ? trackBaseColor
                                        : Colors.grey.shade400,
                                  ),
                                  if (!isMobile) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      track.isVisible ? t.visible : t.hidden,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: () => showDialog(
                              context: context,
                              useRootNavigator: false,
                              barrierColor: Colors.black.withOpacity(0.02),
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
                                horizontal: 8.0,
                                vertical: 6.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: trackBaseColor,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isMobile) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      t.color,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.file_download_outlined,
                              size: 18,
                            ),
                            color: Colors.grey.shade600,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(),
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
                          if (isMobile) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.share_outlined, size: 18),
                              color: Colors.grey.shade600,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(),
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
                          ],
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            color: isSelected
                                ? Colors.red.shade400
                                : Colors.grey.shade400,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(),
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
        );
      },
    );
  }
}
