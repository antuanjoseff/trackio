import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/core/utils/dialogs.dart';
import 'package:trackio/core/utils/track_stats_calculator.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/screens/main_editor_screen.dart';

class ReactiveDrawButton extends ConsumerWidget {
  const ReactiveDrawButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final hasMouse = RendererBinding.instance.mouseTracker.mouseIsConnected;
    final double screenWidth = MediaQuery.of(context).size.width;

    // 📱 MODE COMPACTE AUTOMÀTIC: Icones pures sense text per a l'APK mòbil o pantalles estretes
    final bool useCompactMode = !hasMouse || screenWidth < 600;

    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final pointsCount = ref.watch(
      gpxEditorProvider.select((s) => s.drawingPoints.length),
    );

    if (activeTool != 'draw') return const SizedBox.shrink();

    // Intentem buscar el pare pel context visual (Funciona perfectament a la Web)
    final screenState = context
        .findAncestorStateOfType<MainEditorScreenState>();

    return Positioned(
      bottom: useCompactMode
          ? 16
          : null, // Al mòbil el tirem a BAIX perquè no col·lideixi amb les eines
      top: useCompactMode
          ? null
          : 16, // A la Web el deixem a DALT tal com estava originalment
      left: 16,
      right: 16,
      child: Center(
        // ⚡ LA SOLUCIÓ DEFINITIVA CONTRA LA FILTRACIÓ EN WEB:
        // El Listener intercepta el PointerDown del ratolí web abans que travessi cap avall,
        // garantint que els botons funcionin perfectament però que el mapa no rebi cap esdeveniment.
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (PointerDownEvent event) {
            // Absorbeix el senyal de hardware del ratolí a la Web per immunitzar el mapa de sota
          },
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
                    tooltip: t.cancel,
                    onPressed: () => _handleOnCancel(ref, screenState),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.appBarForeground,
                    ),
                  ),
                  if (!hasMouse)
                    IconButton(
                      tooltip: t.selectDrawPoint,
                      onPressed: () =>
                          _handleOnAddPoint(context, ref, screenState),
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppColors.appBarForeground,
                      ),
                    ),
                  IconButton(
                    tooltip: t.undo,
                    onPressed: pointsCount > 0
                        ? () {
                            ref
                                .read(gpxEditorProvider.notifier)
                                .removeLastDrawingPoint();
                            if (screenState != null) {
                              screenState.paintLiveOverlays(
                                ref.read(gpxEditorProvider),
                              );
                            }
                          }
                        : null,
                    icon: Icon(
                      Icons.undo,
                      color: pointsCount > 0
                          ? AppColors.appBarForeground
                          : Colors.grey.shade400,
                    ),
                  ),
                  Badge(
                    label: Text('$pointsCount'),
                    backgroundColor: AppColors.starTrekRed,
                    isLabelVisible: pointsCount > 0,
                    child: IconButton(
                      tooltip: t.confirmDrawSave,
                      onPressed: pointsCount > 0
                          ? () => _handleOnSave(context, ref, t, screenState)
                          : null,
                      icon: Icon(
                        Icons.check_circle,
                        color: pointsCount > 0
                            ? AppColors.appBarForeground
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleOnCancel(WidgetRef ref, MainEditorScreenState? screenState) {
    ref.read(gpxEditorProvider.notifier).cancelDrawing();
    if (screenState?.controller != null) {
      screenState!.controller!.setGeoJsonSource("source_range", const {
        "type": "FeatureCollection",
        "features": [],
      });
      screenState.controller!.setGeoJsonSource("source_snapped_point", const {
        "type": "FeatureCollection",
        "features": [],
      });
    }
  }

  void _handleOnAddPoint(
    BuildContext context,
    WidgetRef ref,
    MainEditorScreenState? screenState,
  ) {
    FocusScope.of(context).unfocus();

    final notifier = ref.read(gpxEditorProvider.notifier);
    final drawState = ref.read(gpxEditorProvider);
    final stateActive =
        screenState ?? context.findAncestorStateOfType<MainEditorScreenState>();

    final livePoint = drawState.drawingLivePoint;
    if (livePoint?.latitude != null && livePoint?.longitude != null) {
      notifier.addPointToNewTrack(livePoint!.latitude!, livePoint.longitude!);
      return;
    }

    final center = stateActive?.controller?.cameraPosition?.target;
    if (center == null) return;

    notifier.addPointToNewTrack(center.latitude, center.longitude);
  }

  // 💾 Lògica del diàleg i el desament adaptatiu
  void _handleOnSave(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    MainEditorScreenState? screenState,
  ) async {
    if (screenState == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(gpxEditorProvider);

    final stats = _calculateDrawingStats(state.drawingPoints);
    final String defaultName =
        "${t.drawnRouteDefaultName} ${DateTime.now().hour}:${DateTime.now().minute}";

    final Map<String, dynamic>? result = await askTrackNameDialog(
      context: context,
      defaultName: defaultName,
      displayDistance: stats.distanceText,
      displayElevation: stats.elevationText,
    );
    if (result == null) return;
    final String trackName = result['name'] as String;
    ref.read(gpxEditorProvider.notifier).saveDrawnTrack(trackName);
    if (context.mounted) {
      final finalState = ref.read(gpxEditorProvider);
      if (screenState.controller != null) {
        await screenState.controller!.setGeoJsonSource("source_range", const {
          "type": "FeatureCollection",
          "features": [],
        });
        await screenState.controller!.setGeoJsonSource(
          "source_snapped_point",
          const {"type": "FeatureCollection", "features": []},
        );
      }
      await screenState.paintTracks(
        finalState.tracks,
        finalState.selectedTrackId,
      );
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text("${t.routeSavedSuccess}: $trackName"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 📐 LES TEVES FÓRMULES MATEMÀTIQUES INTENSIVES ORIGINALES CONSERVADES EXACTAMENT IGUAL:
  ({String distanceText, String elevationText}) _calculateDrawingStats(
    List points,
  ) {
    double totalMeters = 0.0;
    final List<TrackPointModel> trackPoints = points.cast<TrackPointModel>();
    final stats = TrackStatsCalculator.compute(trackPoints);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1.latitude != null &&
          p1.longitude != null &&
          p2.latitude != null &&
          p2.longitude != null) {
        totalMeters += _haversineDistance(
          p1.latitude!,
          p1.longitude!,
          p2.latitude!,
          p2.longitude!,
        );
      }
    }
    final double distanceKm = totalMeters / 1000;
    return (
      distanceText: "${distanceKm.toStringAsFixed(2)} km",
      elevationText: "${(stats['gain'] as double).toStringAsFixed(0)} m",
    );
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double radius = 6371000;
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radius * c;
  }
}
