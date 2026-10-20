import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/core/utils/track_stats_calculator.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/models/track_model.dart';

class TrackStatsPanel extends ConsumerWidget {
  const TrackStatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(gpxEditorProvider);

    final activeTrackId = editorState.selectedTrackId;
    final trackIndex = editorState.tracks.indexWhere(
      (t) => t.id == activeTrackId,
    );
    if (trackIndex == -1 || editorState.tracks.isEmpty)
      return const SizedBox.shrink();

    final track = editorState.tracks[trackIndex];

    List<TrackPointModel> pointsToProcess = track.points;

    final start = editorState.selectionStartIndex;
    final end = editorState.selectionEndIndex;
    final snappedIdx = editorState.snappedPointIndex;

    // Detectamos si el tramo está completamente cerrado y guardado de forma fija (Fase 3)
    final bool rangeIsFixed =
        start != null &&
        end != null &&
        end != -1 &&
        !editorState.isSelectingRange;

    final int? effectiveEndIndex = (end != null && end != -1)
        ? end
        : snappedIdx;

    // Detectamos si estamos procesando el track completo o un tramo efímero/fijo
    if (editorState.activeTool == 'range_map') {
      if (rangeIsFixed && start != null && effectiveEndIndex != null) {
        pointsToProcess = track.points.sublist(start, effectiveEndIndex + 1);
      } else if (start != null &&
          snappedIdx != null &&
          (editorState.isSelectingRange || end == null || end == -1)) {
        int lo = start < snappedIdx ? start : snappedIdx;
        int hi = start < snappedIdx ? snappedIdx : start;
        pointsToProcess = track.points.sublist(lo, hi + 1);
      }
    } else if (editorState.activeTool == 'split' && snappedIdx != null) {
      pointsToProcess = track.points.sublist(0, snappedIdx + 1);
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

    return Container(
      // Ajuste drástico del padding para compactar la altura
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: AppColors.editorPrimary),
      child: Row(
        children: [
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
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
      color: Colors.white54,
    );
  }
}
