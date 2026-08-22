import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/core/utils/modal_helper.dart';
import 'package:trackio/vars/track_colors.dart';
import 'package:trackio/widgets/color_palette_dialog.dart';
import 'package:trackio/widgets/edit_timestamps_dialog.dart';
import 'package:trackio/widgets/node_count_dialog.dart';
import 'package:trackio/widgets/rename_track_dialog.dart';
import 'package:trackio/widgets/track_properties_dialog.dart';

// El pont condicional per a l'exportació de fitxers GPX en multiplataforma
import 'package:trackio/services/gpx_exporter_io.dart'
    if (dart.library.js_interop) 'package:trackio/services/gpx_exporter_web.dart';

class EditorSidebarWidget extends ConsumerStatefulWidget {
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
  ConsumerState<EditorSidebarWidget> createState() =>
      _EditorSidebarWidgetState();
}

class _EditorSidebarWidgetState extends ConsumerState<EditorSidebarWidget> {
  // Tracks amb el bloc d'accions extra desplegat (trackId -> expanded)
  final Set<int> _expandedTrackIds = {};

  void _toggleExpanded(int trackId) {
    setState(() {
      if (!_expandedTrackIds.remove(trackId)) {
        _expandedTrackIds.add(trackId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: widget.onImportPressed,
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
                          widget.t.importGpx.toUpperCase(),
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
                    tracks,
                    selectedTrackId,
                    isMobile,
                    context,
                  ),
                )
              else
                Flexible(
                  child: _buildTracksListView(
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
    List<TrackModel> tracks,
    int? selectedTrackId,
    bool isMobile,
    BuildContext context,
  ) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          widget.t.noTracksLoaded,
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
      onReorderStart: (_) => widget.onReorderDragStateChanged(true),
      onReorderEnd: (_) => widget.onReorderDragStateChanged(false),
      onReorder: (old, next) async {
        ref.read(gpxEditorProvider.notifier).reorderTracks(old, next);
        await widget.onPaintTracks(ref.read(gpxEditorProvider).tracks);
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
                      // El cercle de color també obre la paleta per canviar el color
                      InkWell(
                        onTap: () => showModalGuarded(
                          context: context,
                          ref: ref,
                          barrierColor: Colors.black.withOpacity(0.02),
                          builder: (_) => ColorPaletteDialog(
                            onColorSelected: (hex) async {
                              ref
                                  .read(gpxEditorProvider.notifier)
                                  .updateTrackColor(track.id, hex);
                              await widget.onPaintTracks(
                                ref.read(gpxEditorProvider).tracks,
                              );
                            },
                          ),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: trackBaseColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 👁️ Alterna visibilitat del track directament des de la primera línia
                      InkWell(
                        onTap: () async {
                          ref
                              .read(gpxEditorProvider.notifier)
                              .toggleTrackVisibility(track.id);
                          await widget.onPaintTracks(
                            ref.read(gpxEditorProvider).tracks,
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Icon(
                          track.isVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 17,
                          color: track.isVisible
                              ? trackBaseColor
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                          // Text "més/menys" que desplega les accions extra
                          InkWell(
                            onTap: () => _toggleExpanded(track.id),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 6.0,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _expandedTrackIds.contains(track.id)
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 15,
                                    color: Colors.grey.shade500,
                                  ),
                                  Text(
                                    _expandedTrackIds.contains(track.id)
                                        ? widget.t.less
                                        : widget.t.more,
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
                              await widget.onPaintTracks(
                                ref.read(gpxEditorProvider).tracks,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Bloc desplegable amb les accions extra del track
                if (_expandedTrackIds.contains(track.id))
                  Container(
                    color: isSelected
                        ? Colors.grey.shade50
                        : Colors.transparent,
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      bottom: 6.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildExtraAction(
                          context: context,
                          icon: Icons.drive_file_rename_outline_rounded,
                          label: widget.t.renameTrack,
                          onTap: () => _showRenameTrackDialog(track),
                        ),
                        _buildExtraAction(
                          context: context,
                          icon: Icons.schedule_outlined,
                          label: widget.t.editTimestamps,
                          onTap: () => _showEditTimestampsDialog(track),
                        ),
                        _buildExtraAction(
                          context: context,
                          icon: Icons.commit_rounded,
                          label: widget.t.nodeCount,
                          onTap: () => _showNodeCountDialog(track),
                        ),
                        _buildExtraAction(
                          context: context,
                          icon: Icons.tune_rounded,
                          label: widget.t.properties,
                          onTap: () => _showTrackPropertiesDialog(track),
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

  /// Fila d'acció extra (icona + text) dins del bloc desplegable
  Widget _buildExtraAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTimestampsDialog(TrackModel track) async {
    final result = await showModalGuarded<(DateTime, DateTime)>(
      context: context,
      ref: ref,
      barrierColor: Colors.black.withOpacity(0.02),
      builder: (_) => EditTimestampsDialog(track: track, t: widget.t),
    );
    if (result != null) {
      ref
          .read(gpxEditorProvider.notifier)
          .updateTrackTimestamps(track.id, result.$1, result.$2);
    }
  }

  Future<void> _showRenameTrackDialog(TrackModel track) async {
    final String? newName = await showModalGuarded<String>(
      context: context,
      ref: ref,
      barrierColor: Colors.black.withOpacity(0.02),
      builder: (_) => RenameTrackDialog(track: track, t: widget.t),
    );
    if (newName != null) {
      ref.read(gpxEditorProvider.notifier).updateTrackName(track.id, newName);
    }
  }

  Future<void> _showNodeCountDialog(TrackModel track) async {
    final result = await showModalGuarded<(double, bool)>(
      context: context,
      ref: ref,
      barrierColor: Colors.black.withOpacity(0.02),
      builder: (_) => NodeCountDialog(track: track, t: widget.t),
    );
    if (result != null) {
      ref
          .read(gpxEditorProvider.notifier)
          .resampleTrackPoints(track.id, result.$1, byTime: result.$2);
      await widget.onPaintTracks(ref.read(gpxEditorProvider).tracks);
    }
  }

  void _showTrackPropertiesDialog(TrackModel track) {
    showModalGuarded(
      context: context,
      ref: ref,
      barrierColor: Colors.black.withOpacity(0.02),
      builder: (_) => TrackPropertiesDialog(track: track, t: widget.t),
    );
  }
}
