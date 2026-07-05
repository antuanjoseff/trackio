import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🔥 Afegit per a la reactivitat
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart'; // 🔥 Afegit
import 'package:trackio/widgets/elevation_chart_widget.dart';

// ↕️ PANELL COMPLETAMENT REACTIU I AUTÒNOM
class ElevationChartPanel extends ConsumerWidget {
  // 👈 Canviat de StatelessWidget a ConsumerWidget
  final GpxEditorState
  editorState; // Mantenim el paràmetre per compatibilitat amb el pare [1.1]
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
    // 👈 Afegit WidgetRef ref
    // 🔒 EL RADAR EN VIU: Llegim la llista de tracks i el seleccionat en viu de Riverpod.
    // Així, quan importis o tallis un track, el gràfic es repintarà a l'acte a la pantalla [1.1].
    final liveTracks = ref.watch(gpxEditorProvider.select((s) => s.tracks));
    final liveSelectedTrackId = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId),
    );

    // Si la llista viva té dades, prioritzem sempre Riverpod per sobre del paràmetre passat [1.1]
    final tracks = liveTracks.isNotEmpty ? liveTracks : editorState.tracks;
    final selectedTrackId = liveTracks.isNotEmpty
        ? liveSelectedTrackId
        : editorState.selectedTrackId;

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
              // Busquem el track seleccionat dins de la llista viva actualitzada [1.1]
              track: tracks.firstWhere(
                (t) => t.id == selectedTrackId,
                orElse: () => tracks.first,
              ),
            ),
    );
  }
}
