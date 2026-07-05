import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/utils/track_stats_calculator.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/models/track_model.dart';

class TrackStatsPanel extends ConsumerWidget {
  const TrackStatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final editorState = ref.watch(gpxEditorProvider);

    final activeTrackId = editorState.selectedTrackId;
    final trackIndex = editorState.tracks.indexWhere(
      (t) => t.id == activeTrackId,
    );
    if (trackIndex == -1 || editorState.tracks.isEmpty)
      return const SizedBox.shrink();

    final track = editorState.tracks[trackIndex];

    List<TrackPointModel> pointsToProcess = track.points;
    bool isSegment = false;

    final start = editorState.selectionStartIndex;
    final end = editorState.selectionEndIndex;
    final snappedIdx = editorState.snappedPointIndex;

    // Detectamos si el tramo está completamente cerrado y guardado de forma fija (Fase 3)
    final bool rangeIsFixed =
        start != null &&
        end != null &&
        end != -1 &&
        !editorState.isSelectingRange;

    // Detectamos de forma idéntica si procesamos el track completo o el tramo efímero/fijo
    if (editorState.activeTool == 'range_map') {
      if (rangeIsFixed) {
        pointsToProcess = track.points.sublist(start, end + 1);
        isSegment = true;
      } else if (start != null &&
          editorState.isSelectingRange &&
          snappedIdx != null) {
        int lo = start < snappedIdx ? start : snappedIdx;
        int hi = start < snappedIdx ? snappedIdx : start;
        pointsToProcess = track.points.sublist(lo, hi + 1);
        isSegment = true;
      }
    } else if (editorState.activeTool == 'split' && snappedIdx != null) {
      pointsToProcess = track.points.sublist(0, snappedIdx + 1);
      isSegment = true;
    }

    final stats = TrackStatsCalculator.compute(pointsToProcess);

    // Formateadores de texto ultra compactos
    final double dist = stats['distance'];
    final String distanceStr = "${(dist / 1000).toStringAsFixed(1)} km";

    final Duration time = stats['time'];
    final String timeStr = time.inSeconds > 0
        ? "${time.inHours.toString().padLeft(2, '0')}:${(time.inMinutes % 60).toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}"
        : "--:--:--";

    final double speed = stats['speed'];
    final double pace = stats['pace'];
    final String paceStr = pace > 0
        ? "${pace.floor()}:${((pace - pace.floor()) * 60).round().toString().padLeft(2, '0')} min/km"
        : "--:--";

    final String speedPaceStr = speed > 0
        ? "${speed.toStringAsFixed(1)} km/h ($paceStr)"
        : "--";

    // Condición exacta para saber si la etiqueta debe convertirse en el botón interactivo de acción
    final bool canAddTrack =
        isSegment && rangeIsFixed && editorState.activeTool == 'range_map';

    return Container(
      // Ajuste drástico del padding para compactar la altura
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        // Si es un tramo, se tiñe sutilmente de naranja para avisar al usuario
        color: isSegment
            ? Colors.orange.shade50.withOpacity(0.5)
            : Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // ⚡ BOTÓ INTEGRAT A L'ESQUERRA DEL TOT (Només si el gràfic està visible)
          if (editorState.showElevationChart) ...[
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: editorState.showSpeedInChart
                    ? t.hideSpeed
                    : t.showSpeed,
                style: IconButton.styleFrom(
                  backgroundColor: editorState.showSpeedInChart
                      ? Colors.teal.shade50
                      : Colors.grey.shade100,
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  editorState.showSpeedInChart
                      ? Icons.speed
                      : Icons.speed_outlined,
                  color: editorState.showSpeedInChart
                      ? Colors.teal.shade700
                      : Colors.grey.shade500,
                  size: 15,
                ),
                onPressed: () =>
                    ref.read(gpxEditorProvider.notifier).toggleSpeedChart(),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 🌟 ETIQUETA INTELIGENTE RECONVERTIDA: RUTA, TRAM o BOTÓN AFEGIR TRACK
          InkWell(
            onTap: canAddTrack
                ? () {
                    // 1. Creamos el nuevo track a nivel de estado global de forma síncrona
                    ref
                        .read(gpxEditorProvider.notifier)
                        .createTrackFromSelectedRange();

                    // 2. Avisamos al usuario con un feedback visual nativo
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.newTrackAddedFromSelectedSegment),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                : null, // Si es el track completo o tramo elástico, se comporta como etiqueta normal
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                horizontal: canAddTrack ? 8 : 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                // Se vuelve verde llamativo si está listo para ser guardado como un track nuevo
                color: canAddTrack
                    ? Colors.green.shade600
                    : (isSegment
                          ? Colors.orange.shade200
                          : Colors.blue.shade100),
                borderRadius: BorderRadius.circular(4),
                boxShadow: canAddTrack
                    ? [
                        const BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canAddTrack) ...[
                    const Icon(Icons.add, size: 10, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    canAddTrack
                        ? t.addTrack
                        : (isSegment ? t.segment : t.route),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      color: canAddTrack
                          ? Colors.white
                          : (isSegment
                                ? Colors.orange.shade900
                                : Colors.blue.shade900),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // FILA HORIZONTAL DE MÉTRICAS COMPACTAS
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _inlineStat(Icons.straighten, distanceStr),
                  _vDivider(),
                  _inlineStat(Icons.timer, timeStr),
                  _vDivider(),
                  _inlineStat(Icons.speed, speedPaceStr),
                  _vDivider(),
                  _inlineStat(
                    Icons.trending_up,
                    "+${stats['gain'].toStringAsFixed(0)}m / -${stats['loss'].toStringAsFixed(0)}m",
                  ),
                  _vDivider(),
                  _inlineStat(
                    Icons.landscape,
                    "🔼 ${stats['maxAlt'].toStringAsFixed(0)}m  🔽 ${stats['minAlt'].toStringAsFixed(0)}m",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para pintar el icono y el texto en paralelo, ahorrando espacio vertical
  Widget _inlineStat(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Separador vertical discreto entre métricas
  Widget _vDivider() {
    return Container(
      height: 12,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.grey.shade300,
    );
  }
}
