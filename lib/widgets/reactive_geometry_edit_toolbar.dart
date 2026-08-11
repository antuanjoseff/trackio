import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/screens/main_editor_screen.dart';

class ReactiveGeometryEditToolbar extends ConsumerWidget {
  const ReactiveGeometryEditToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final hasSelectedTrack = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId != null),
    );
    final geometryMode = ref.watch(
      gpxEditorProvider.select((s) => s.geometryEditMode),
    );
    final canUndoGeometry = ref.watch(
      gpxEditorProvider.select((s) => s.geometryCanUndo),
    );
    if (activeTool != 'edit_geometry' || !hasSelectedTrack) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).appBarTheme.backgroundColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: t.addNode,
                  style: IconButton.styleFrom(
                    backgroundColor: geometryMode == 'add'
                        ? AppColors.starTrekRed.withOpacity(0.16)
                        : null,
                  ),
                  onPressed: () => ref
                      .read(gpxEditorProvider.notifier)
                      .setGeometryEditMode('add'),
                  icon: Icon(Icons.add_circle, color: AppColors.starTrekRed),
                ),
                IconButton(
                  tooltip: t.deleteNode,
                  style: IconButton.styleFrom(
                    backgroundColor: geometryMode == 'delete'
                        ? AppColors.starTrekRed.withOpacity(0.16)
                        : null,
                  ),
                  onPressed: () => ref
                      .read(gpxEditorProvider.notifier)
                      .setGeometryEditMode('delete'),
                  icon: Icon(Icons.remove_circle, color: AppColors.starTrekRed),
                ),
                IconButton(
                  tooltip: t.moveNode,
                  style: IconButton.styleFrom(
                    backgroundColor: geometryMode == 'move'
                        ? AppColors.starTrekRed.withOpacity(0.16)
                        : null,
                  ),
                  onPressed: () => ref
                      .read(gpxEditorProvider.notifier)
                      .setGeometryEditMode('move'),
                  icon: Icon(Icons.open_with, color: AppColors.starTrekRed),
                ),
                IconButton(
                  tooltip: t.undoGeometryEdit,
                  onPressed: canUndoGeometry
                      ? () {
                          ref
                              .read(gpxEditorProvider.notifier)
                              .undoLastGeometryEdit();
                          final screenState = context
                              .findAncestorStateOfType<MainEditorScreenState>();
                          if (screenState != null) {
                            screenState.paintLiveOverlays(
                              ref.read(gpxEditorProvider),
                            );
                          }
                        }
                      : null,
                  icon: Icon(
                    Icons.undo,
                    color: canUndoGeometry
                        ? AppColors.starTrekRed
                        : Colors.grey.shade400,
                  ),
                ),
                IconButton(
                  tooltip: t.cancel,
                  onPressed: () => ref
                      .read(gpxEditorProvider.notifier)
                      .setActiveTool('none'),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.starTrekRed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
