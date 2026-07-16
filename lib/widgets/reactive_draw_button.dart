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

    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final pointsCount = ref.watch(
      gpxEditorProvider.select((s) => s.drawingPoints.length),
    );

    if (activeTool != 'draw') return const SizedBox.shrink();

    return Positioned(
      top: 16,
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
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.close),
                  label: Text(t.cancel),
                  onPressed: () {
                    final screenState = context
                        .findAncestorStateOfType<MainEditorScreenState>();
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
                const SizedBox(width: 8),

                if (!hasMouse) ...[
                  // 🌟 2️⃣ RECUPERAT: BOTÓ BLAU CENTRAL PER FIXAR PUNTS EN VIU
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle),
                    label: Text(t.selectDrawPoint), // "Fixar punt al mapa"
                    onPressed: () {
                      final screenState = context
                          .findAncestorStateOfType<MainEditorScreenState>();

                      // Comprovació de seguretat del controlador públic
                      if (screenState == null || screenState.controller == null)
                        return;

                      // Netegem el focus per evitar conflictes amb la tecla Enter global
                      FocusScope.of(context).unfocus();

                      // Capturem la coordenada del centre de la pantalla
                      final center =
                          screenState.controller!.cameraPosition?.target;
                      if (center != null) {
                        // Pugem el punt a Riverpod (l'alçada es calcula a la cua)
                        ref
                            .read(gpxEditorProvider.notifier)
                            .addPointToNewTrack(
                              center.latitude,
                              center.longitude,
                            );

                        // Forcem el repintat de la línia elàstica taronja
                        screenState.paintLiveOverlays(
                          ref.read(gpxEditorProvider),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
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
                          final screenState = context
                              .findAncestorStateOfType<MainEditorScreenState>();
                          if (screenState != null) {
                            screenState.paintLiveOverlays(
                              ref.read(gpxEditorProvider),
                            );
                          }
                        }
                      : null,
                ),
                const SizedBox(width: 8),

                // 4️⃣ BOTÓ DESAR RUTA
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
                      ? () async {
                          final screenState = context
                              .findAncestorStateOfType<MainEditorScreenState>();
                          if (screenState == null) return;

                          final messenger = ScaffoldMessenger.of(context);
                          final state = ref.read(gpxEditorProvider);

                          final stats = _calculateDrawingStats(
                            state.drawingPoints,
                          );

                          final String defaultName =
                              "${t.drawnRouteDefaultName} ${DateTime.now().hour}:${DateTime.now().minute}";

                          // Obrim el diàleg passant els strings obtinguts de la meva funció auxiliar
                          final Map<String, dynamic>? result =
                              await askTrackNameDialog(
                                context: context,
                                defaultName: defaultName,
                                displayDistance: stats.distanceText,
                                displayElevation: stats.elevationText,
                              );

                          if (result == null) return;

                          final String trackName = result['name'] as String;

                          // Guardem la ruta a Riverpod
                          ref
                              .read(gpxEditorProvider.notifier)
                              .saveDrawnTrack(trackName);

                          if (context.mounted) {
                            final finalState = ref.read(gpxEditorProvider);

                            if (screenState.controller != null) {
                              await screenState.controller!.setGeoJsonSource(
                                "source_range",
                                const {
                                  "type": "FeatureCollection",
                                  "features": [],
                                },
                              );
                              await screenState.controller!.setGeoJsonSource(
                                "source_snapped_point",
                                const {
                                  "type": "FeatureCollection",
                                  "features": [],
                                },
                              );
                            }

                            await screenState.paintTracks(
                              finalState.tracks,
                              finalState.selectedTrackId,
                            );
                          }

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                "${t.routeSavedSuccess}: $trackName",
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
