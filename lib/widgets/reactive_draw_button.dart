import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/utils/dialogs.dart';
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
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1️⃣ BOTÓ CANCEL·LAR
                if (useCompactMode)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: t.cancel,
                    onPressed: () {
                      ref.read(gpxEditorProvider.notifier).cancelDrawing();
                      if (screenState?.controller != null) {
                        screenState!.controller!.setGeoJsonSource(
                          "source_range",
                          const {"type": "FeatureCollection", "features": []},
                        );
                        screenState.controller!.setGeoJsonSource(
                          "source_snapped_point",
                          const {"type": "FeatureCollection", "features": []},
                        );
                      }
                    },
                  )
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.close),
                    label: Text(t.cancel),
                    onPressed: () {
                      ref.read(gpxEditorProvider.notifier).cancelDrawing();
                      if (screenState?.controller != null) {
                        screenState!.controller!.setGeoJsonSource(
                          "source_range",
                          const {"type": "FeatureCollection", "features": []},
                        );
                        screenState.controller!.setGeoJsonSource(
                          "source_snapped_point",
                          const {"type": "FeatureCollection", "features": []},
                        );
                      }
                    },
                  ),

                if (useCompactMode)
                  const SizedBox(width: 4)
                else
                  const SizedBox(width: 8),

                // 🌟 2️⃣ BOTÓ BLAU CENTRAL PER FIXAR PUNTS EN VIU (Exclusiu per a mòbils/APK)
                if (!hasMouse) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Icon(Icons.add_circle, size: 20),
                    onPressed: () {
                      FocusScope.of(context).unfocus();

                      final notifier = ref.read(gpxEditorProvider.notifier);
                      final drawState = ref.read(gpxEditorProvider);
                      final stateActive =
                          screenState ??
                          context
                              .findAncestorStateOfType<MainEditorScreenState>();

                      final livePoint = drawState.drawingLivePoint;
                      if (livePoint?.latitude != null &&
                          livePoint?.longitude != null) {
                        notifier.addPointToNewTrack(
                          livePoint!.latitude!,
                          livePoint.longitude!,
                        );
                        return;
                      }

                      final center =
                          stateActive?.controller?.cameraPosition?.target;
                      if (center == null) return;

                      notifier.addPointToNewTrack(
                        center.latitude,
                        center.longitude,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],

                // 3️⃣ BOTÓ DESFER (UNDO)
                IconButton(
                  tooltip: t.undo,
                  icon: Icon(
                    Icons.undo,
                    color: pointsCount > 0
                        ? Colors.orange.shade800
                        : Colors.grey.shade400,
                  ),
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
                ),

                if (useCompactMode)
                  const SizedBox(width: 4)
                else
                  const SizedBox(width: 8),

                // 4️⃣ BOTÓ DESAR RUTA
                if (useCompactMode)
                  Badge(
                    label: Text('$pointsCount'),
                    backgroundColor: Colors.green.shade800,
                    isLabelVisible: pointsCount > 0,
                    child: IconButton(
                      icon: Icon(
                        Icons.check_circle,
                        color: pointsCount > 0
                            ? Colors.green.shade700
                            : Colors.grey.shade400,
                        size: 24,
                      ),
                      tooltip: t.confirmDrawSave,
                      onPressed: pointsCount > 0
                          ? () => _handleOnSave(context, ref, t, screenState)
                          : null,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: Text('${t.confirmDrawSave} ($pointsCount)'),
                    onPressed: pointsCount > 0
                        ? () => _handleOnSave(context, ref, t, screenState)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 💾 Lògica del diàleg i el desament adaptatiu (Reemplaça tota la secció asíncrona vella)
  void _handleOnSave(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    MainEditorScreenState? screenState,
  ) async {
    if (screenState == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(gpxEditorProvider);

    // Executem les teves línies de distàncies i altituds reals
    final stats = _calculateDrawingStats(state.drawingPoints);
    final String defaultName =
        "${t.drawnRouteDefaultName} ${DateTime.now().hour}:${DateTime.now().minute}";

    // Obrim el teu diàleg passant els strings obtinguts de la teva funció auxiliar
    final Map<String, dynamic>? result = await askTrackNameDialog(
      context: context,
      defaultName: defaultName,
      displayDistance: stats.distanceText,
      displayElevation: stats.elevationText,
    );

    if (result == null) return;
    final String trackName = result['name'] as String;

    // Guardem oficialment la ruta a Riverpod
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
    List<TrackPointModel> points,
  ) {
    double totalMeters = 0.0;
    double positiveElevation = 0.0;

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

        if (p1.elevation != null && p2.elevation != null) {
          final double diff = p2.elevation! - p1.elevation!;
          if (diff > 0) positiveElevation += diff;
        }
      }
    }

    final double distanceKm = totalMeters / 1000;
    return (
      distanceText: "${distanceKm.toStringAsFixed(2)} km",
      elevationText: "${positiveElevation.toStringAsFixed(0)} m",
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
