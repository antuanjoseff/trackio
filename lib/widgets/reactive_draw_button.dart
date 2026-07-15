import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/utils/dialogs.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/screens/main_editor_screen.dart';

class ReactiveDrawButton extends ConsumerWidget {
  const ReactiveDrawButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;

    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final pointsCount = ref.watch(
      gpxEditorProvider.select((s) => s.drawingPoints.length),
    );

    // Només es mostra si l'eina activa és exactament 'draw'
    if (activeTool != 'draw') return const SizedBox.shrink();

    return Positioned(
      // 🌟 PAS A PAS 1: El fixem a dalt de tot del mapa per a una millor usabilitat
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

                // 🌟 PAS A PAS 2: EL BOTÓ CENTRAL CRÍTIC PER FIXAR COORDENADES
                // Llegeix el controlador públic de la pantalla principal i clava el node
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

                    // Comprovació de seguretat del controlador públic sense el guió baix
                    if (screenState == null || screenState.controller == null)
                      return;

                    // Capturem les coordenades en 2D exactes de la càmera de MapLibre
                    final center =
                        screenState.controller!.cameraPosition?.target;
                    if (center != null) {
                      // Pugem el node al llistat temporal de Riverpod (resolent la Z a la cua)
                      ref
                          .read(gpxEditorProvider.notifier)
                          .addPointToNewTrack(
                            center.latitude,
                            center.longitude,
                          );

                      // Forcem a la GPU a connectar immediatament la línia elàstica taronja
                      screenState.paintLiveOverlays(
                        ref.read(gpxEditorProvider),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),

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

                // 4️⃣ BOTÓ DESAR RUTA FINISHED
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
                          final String defaultName =
                              "${t.drawnRouteDefaultName} ${DateTime.now().hour}:${DateTime.now().minute}";

                          final String? trackName = await askTrackNameDialog(
                            context,
                            defaultName,
                          );

                          if (trackName == null) return;

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
}
