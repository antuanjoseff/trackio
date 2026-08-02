import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/utils/dialogs.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/screens/main_editor_screen.dart';

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

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 60),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
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
      bottom: 16,
      left: 32,
      right: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelectingRange
              ? Colors.red.shade600
              : Colors.green.shade600,
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

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 60),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
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
    final showElevationChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );

    if (activeTool != 'add_waypoint' || !isMapIdle || !hasSelectedTrack)
      return const SizedBox.shrink();

    return Positioned(
      bottom: showElevationChart ? 200 : 24,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton.extended(
          backgroundColor: Colors.blueAccent.shade700,
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

            final messenger = ScaffoldMessenger.of(context);
            ref
                .read(gpxEditorProvider.notifier)
                .addWaypointToSelectedTrack(name: name, comment: "");

            // 🌟 Dins de widgets/reactive_editor_buttons.dart -> ReactiveWaypointButton:
            if (context.mounted) {
              final updated = ref.read(gpxEditorProvider);

              // 🔄 CORREGIT: Li passem la llista de tracks I TAMBÉ el selectedTrackId
              await screenState.paintTracks(
                updated.tracks,
                updated.selectedTrackId,
              );
            }

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
    final showElevationChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );

    if (activeTool != 'edit_geometry' ||
        geometryMode != 'add' ||
        !isMapIdle ||
        !hasSnap ||
        !hasInsertIndex) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: showElevationChart ? 200 : 24,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton.extended(
          backgroundColor: Colors.green.shade700,
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
              color: Colors.white.withOpacity(0.96),
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
                        ? Colors.green.shade50
                        : null,
                  ),
                  onPressed: () => ref
                      .read(gpxEditorProvider.notifier)
                      .setGeometryEditMode('add'),
                  icon: Icon(
                    Icons.add_circle,
                    color: geometryMode == 'add'
                        ? Colors.green.shade700
                        : Colors.green,
                  ),
                ),
                IconButton(
                  tooltip: t.deleteNode,
                  style: IconButton.styleFrom(
                    backgroundColor: geometryMode == 'delete'
                        ? Colors.red.shade50
                        : null,
                  ),
                  onPressed: () => ref
                      .read(gpxEditorProvider.notifier)
                      .setGeometryEditMode('delete'),
                  icon: Icon(
                    Icons.remove_circle,
                    color: geometryMode == 'delete'
                        ? Colors.red.shade700
                        : Colors.red,
                  ),
                ),
                IconButton(
                  tooltip: t.moveNode,
                  style: IconButton.styleFrom(
                    backgroundColor: geometryMode == 'move'
                        ? Colors.blue.shade50
                        : null,
                  ),
                  onPressed: () => ref
                      .read(gpxEditorProvider.notifier)
                      .setGeometryEditMode('move'),
                  icon: Icon(
                    Icons.open_with,
                    color: geometryMode == 'move'
                        ? Colors.blue.shade700
                        : Colors.blue,
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
