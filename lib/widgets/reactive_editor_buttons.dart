import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/core/utils/dialogs.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/screens/main_editor_screen.dart';

const double _floatingButtonsBottom = 16.0;

// ==========================================
// ✂️ BOTÓ SPLIT
// ==========================================
class ReactiveSplitButton extends ConsumerWidget {
  const ReactiveSplitButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSnappedPoint = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPoint != null),
    );

    if (activeTool != 'split' || !isMapIdle || !hasSnappedPoint)
      return const SizedBox.shrink();

    return Positioned(
      bottom: _floatingButtonsBottom,
      left: 0,
      right: 0,
      child: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starTrekRed,
            foregroundColor: Colors.white,
            elevation: 6,
          ),
          icon: const Icon(Icons.content_cut),
          label: Text(t.selectSplitPoint),
          onPressed: () async {
            final screenState = context
                .findAncestorStateOfType<MainEditorScreenState>();
            if (screenState == null) return;

            ref.read(gpxEditorProvider.notifier).executeTrackSplit();
            final stateDespresDelTall = ref.read(gpxEditorProvider);

            await screenState.paintTracks(
              stateDespresDelTall.tracks,
              stateDespresDelTall.selectedTrackId,
            );

            if (screenState.controller != null) {
              await screenState.controller!.setGeoJsonSource("source_range", {
                "type": "FeatureCollection",
                "features": [],
              });
            }
            ref.read(gpxEditorProvider.notifier).setActiveTool('none');
          },
        ),
      ),
    );
  }
}

// ==========================================
// 📊 BOTÓ RANGE (TRAMS)
// ==========================================
class ReactiveRangeButton extends ConsumerWidget {
  const ReactiveRangeButton({super.key});

  // 🎨 DINS DEL TEU GINY DEL BOTÓ FLOTANT DE RANG
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final isSelectingRange = ref.watch(
      gpxEditorProvider.select((s) => s.isSelectingRange),
    );

    // 🌟 REPARACIÓ: El botó només s'ha d'aixecar si l'eina del mapa està activa i el mapa s'ha aturat
    if (activeTool != 'range_map' || !isMapIdle) {
      return const SizedBox.shrink(); // S'amaga transparentment si es mou o és una altra eina
    }

    return Positioned(
      bottom: _floatingButtonsBottom,
      left: 32,
      right: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelectingRange
              ? AppColors.starTrekRed
              : AppColors.starTrekGreen,
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          final notifier = ref.read(gpxEditorProvider.notifier);
          if (!isSelectingRange) {
            notifier.fixRangeStartIndex();
          } else {
            notifier.fixRangeEndIndex();
          }
        },
        child: Text(isSelectingRange ? "Fixar Final" : "Fixar Inici"),
      ),
    );
  }
}

// ==========================================
// 🤝 BOTÓ MERGE (UNIR)
// ==========================================
class ReactiveMergeButton extends ConsumerWidget {
  const ReactiveMergeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasPreview = ref.watch(
      gpxEditorProvider.select((s) => s.previewTrackId != null),
    );

    if (activeTool != 'merge' || !isMapIdle || !hasPreview)
      return const SizedBox.shrink();

    return Positioned(
      bottom: _floatingButtonsBottom,
      left: 0,
      right: 0,
      child: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starTrekRed,
            foregroundColor: Colors.white,
            elevation: 6,
          ),
          icon: const Icon(Icons.call_merge),
          label: Text(t.confirmTracksMerge),
          onPressed: () {
            final screenState = context
                .findAncestorStateOfType<MainEditorScreenState>();
            if (screenState == null) return;

            if (screenState.controller != null) {
              screenState.controller!.setGeoJsonSource("source_range", const {
                "type": "FeatureCollection",
                "features": [],
              });
            }
            ref.read(gpxEditorProvider.notifier).executeTracksMerge();
          },
        ),
      ),
    );
  }
}

// ==========================================
// 📍 BOTÓ WAYPOINT
// ==========================================
class ReactiveWaypointButton extends ConsumerWidget {
  const ReactiveWaypointButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSelectedTrack = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId != null),
    );

    if (activeTool != 'add_waypoint' || !isMapIdle || !hasSelectedTrack)
      return const SizedBox.shrink();

    return Positioned(
      bottom: _floatingButtonsBottom,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.starTrekRed,
          icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
          label: Text(
            t.addWaypoint,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () async {
            final screenState = context
                .findAncestorStateOfType<MainEditorScreenState>();
            if (screenState == null) return;

            final reticleCoords = await screenState
                .captureVisibleReticleLatLng();
            if (reticleCoords == null) return;

            final state = ref.read(gpxEditorProvider);
            final track = state.tracks.firstWhere(
              (t) => t.id == state.selectedTrackId,
            );
            final int n = track.waypoints.length + 1;
            final String defaultName = "Punt $n";

            final String? name = await askWaypointNameDialog(
              context,
              defaultName,
            );
            if (name == null || name.isEmpty) return;

            await screenState.addWaypointAtVisibleReticle(
              name: name,
              comment: "",
              target: reticleCoords,
            );
            final messenger = ScaffoldMessenger.of(context);

            messenger.showSnackBar(
              SnackBar(
                content: Text("Waypoint afegit: $name"),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReactiveAddNodeButton extends ConsumerWidget {
  const ReactiveAddNodeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final geometryMode = ref.watch(
      gpxEditorProvider.select((s) => s.geometryEditMode),
    );
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSnap = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPoint != null),
    );
    final hasInsertIndex = ref.watch(
      gpxEditorProvider.select((s) => s.geometryInsertIndex != null),
    );

    if (activeTool != 'edit_geometry' ||
        geometryMode != 'add' ||
        !isMapIdle ||
        !hasSnap ||
        !hasInsertIndex) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: _floatingButtonsBottom,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.starTrekRed,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: Text(
            t.confirmAddNode,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            ref.read(gpxEditorProvider.notifier).addNodeAtCurrentSnap();
            final screenState = context
                .findAncestorStateOfType<MainEditorScreenState>();
            if (screenState != null) {
              screenState.paintLiveOverlays(ref.read(gpxEditorProvider));
            }
          },
        ),
      ),
    );
  }
}

class ReactiveDeleteNodeButton extends ConsumerWidget {
  const ReactiveDeleteNodeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final geometryMode = ref.watch(
      gpxEditorProvider.select((s) => s.geometryEditMode),
    );
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSnap = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPoint != null),
    );

    if (activeTool != 'edit_geometry' ||
        geometryMode != 'delete' ||
        !isMapIdle ||
        !hasSnap) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: _floatingButtonsBottom,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.starTrekRed,
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
          label: Text(
            t.deleteNode,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            ref.read(gpxEditorProvider.notifier).deleteNodeAtCurrentSnap();
            final screenState = context
                .findAncestorStateOfType<MainEditorScreenState>();
            if (screenState != null) {
              screenState.paintLiveOverlays(ref.read(gpxEditorProvider));
            }
          },
        ),
      ),
    );
  }
}

class ReactiveMoveNodeButton extends ConsumerWidget {
  const ReactiveMoveNodeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final geometryMode = ref.watch(
      gpxEditorProvider.select((s) => s.geometryEditMode),
    );
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSnap = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPoint != null),
    );
    final selectedMoveNodeIndex = ref.watch(
      gpxEditorProvider.select((s) => s.geometryMoveNodeIndex),
    );

    if (activeTool != 'edit_geometry' ||
        geometryMode != 'move' ||
        !isMapIdle ||
        !hasSnap) {
      return const SizedBox.shrink();
    }

    final bool isNodeAlreadySelected = selectedMoveNodeIndex != null;

    return Positioned(
      bottom: _floatingButtonsBottom,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton.extended(
          backgroundColor: isNodeAlreadySelected
              ? AppColors.starTrekRed
              : AppColors.starTrekGold,
          icon: Icon(
            isNodeAlreadySelected
                ? Icons.check_circle_outline
                : Icons.open_with,
            color: Colors.white,
          ),
          label: Text(
            isNodeAlreadySelected ? t.confirmMoveNode : t.selectMoveNode,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            final notifier = ref.read(gpxEditorProvider.notifier);
            if (isNodeAlreadySelected) {
              notifier.confirmMoveNodePosition();
            } else {
              notifier.selectMoveNodeFromCurrentSnap();
            }

            final screenState = context
                .findAncestorStateOfType<MainEditorScreenState>();
            if (screenState != null) {
              screenState.paintLiveOverlays(ref.read(gpxEditorProvider));
            }
          },
        ),
      ),
    );
  }
}
