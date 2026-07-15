import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/widgets/elevation_chart_widget.dart';

// ↕️ PANELL COMPLETAMENT REACTIU I AUTÒNOM
class ElevationChartPanel extends ConsumerWidget {
  final GpxEditorState editorState;
  final double height;
  final double textFontSize;

  const ElevationChartPanel({
    super.key,
    required this.editorState,
    required this.height,
    this.textFontSize = 14,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;

    // 🔒 EL RADAR EN VIU: Escoltem els estats i la nova eina activa de Riverpod
    final liveTracks = ref.watch(gpxEditorProvider.select((s) => s.tracks));
    final liveSelectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));

    // 🌟 REPARACIÓ CRÍTICA: Escoltem activament els nodes i la retícula en viu de Riverpod
    // per forçar que el gràfic es redibuixi de forma asíncrona a cada moviment del mapa
    final liveDrawingPoints = ref.watch(
      gpxEditorProvider.select((s) => s.drawingPoints),
    );
    final liveDrawingLivePoint = ref.watch(
      gpxEditorProvider.select((s) => s.drawingLivePoint),
    );

    final tracks = liveTracks.isNotEmpty ? liveTracks : editorState.tracks;
    final selectedTrackId = liveTracks.isNotEmpty
        ? liveSelectedTrackId
        : editorState.selectedTrackId;

    // 🌟 1. BIFURCACIÓ PER AL MÒDUL DIBUIXAR (DISSENY ASSISTIT EN VIU)
    if (activeTool == 'draw') {
      // 🔄 Unifiquem en viu la llista reactiva aprofitant els 'watch' de dalt
      final List<TrackPointModel> drawingPointsInLive = [];
      if (liveDrawingPoints.isNotEmpty) {
        drawingPointsInLive.addAll(liveDrawingPoints);
      }
      if (liveDrawingLivePoint != null) {
        drawingPointsInLive.add(liveDrawingLivePoint);
      }

      if (drawingPointsInLive.isEmpty) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Center(
            child: Text(
              t.selectTrackToViewElevationProfile,
              style: TextStyle(color: Colors.grey, fontSize: textFontSize),
            ),
          ),
        );
      }

      // 🔄 CREEM EL TRACK PROVISIONAL EN MEMÒRIA:
      final virtualDrawnTrack = TrackModel(
        id: -999,
        name: t.drawnRouteDefaultName,
        points: drawingPointsInLive,
        hexColor: "#E91E63",
        isVisible: true,
        waypoints: const [],
      );

      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: ElevationChartWidget(track: virtualDrawnTrack),
      );
    }

    // 🌟 2. CODI ORIGINAL DE TOTA LA VIDA PER A LES ALTRESEINES (SENSE ALTERACIONS)
    final bool hasNoSelection = selectedTrackId == null || tracks.isEmpty;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: hasNoSelection
          ? Center(
              child: Text(
                t.selectTrackToViewElevationProfile,
                style: TextStyle(color: Colors.grey, fontSize: textFontSize),
              ),
            )
          : ElevationChartWidget(
              track: tracks.firstWhere(
                (t) => t.id == selectedTrackId,
                orElse: () => tracks.first,
              ),
            ),
    );
  }
}
