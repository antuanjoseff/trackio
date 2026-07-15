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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isMapIdle = ref.watch(gpxEditorProvider.select((s) => s.isMapIdle));
    final hasSnappedPoint = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPoint != null),
    );
    final isSelectingRange = ref.watch(
      gpxEditorProvider.select((s) => s.isSelectingRange),
    );
    final hasStart = ref.watch(
      gpxEditorProvider.select((s) => s.selectionStartIndex != null),
    );

    if (activeTool != 'range_map' || !isMapIdle || !hasSnappedPoint)
      return const SizedBox.shrink();

    String labelText = t.confirmRangeStartPoint;
    if (hasStart && isSelectingRange) labelText = t.confirmRangeEndPoint;
    if (hasStart && !isSelectingRange) labelText = t.selectNewRange;

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 60),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange.shade800,
            elevation: 6,
          ),
          icon: const Icon(Icons.add_location_alt),
          label: Text(labelText),
          onPressed: () =>
              ref.read(gpxEditorProvider.notifier).handleMapPointSelection(),
        ),
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
