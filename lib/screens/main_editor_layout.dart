import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_state.dart';
import 'package:trackio/widgets/editor_sidebar_widget.dart';
import 'package:trackio/widgets/elevation_chart_panel.dart';
import 'package:trackio/widgets/track_stats_panel.dart'; // 🌟 1. IMPORTAMOS TU NUEVO PANEL DE DATOS

class MainEditorLayout extends StatelessWidget {
  const MainEditorLayout({
    super.key,
    required this.t,
    required this.editorState,
    required this.mapModule,
    required this.showElevationChart,
    required this.isReverseAnimating,
    required this.onPaintTracks,
    required this.onReverseTrack,
    required this.onImportPressed,
  });

  final AppLocalizations t;
  final GpxEditorState editorState;
  final Widget mapModule;
  final bool showElevationChart;
  final bool isReverseAnimating;
  final Future<void> Function(List<TrackModel>) onPaintTracks;
  final Future<void> Function(WidgetRef) onReverseTrack;
  final VoidCallback onImportPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(t.appTitle)),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  children: [
                    Container(
                      width: constraints.maxWidth * 0.25,
                      color: Colors.grey.shade100,
                      child: EditorSidebarWidget(
                        state: editorState,
                        t: t,
                        onPaintTracks: onPaintTracks,
                        onReverseTrack: onReverseTrack,
                        onImportPressed: onImportPressed,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: mapModule),

                          // 🎯 2. VISTA ESCRITORIO: Inyectamos el panel de datos justo por encima del gráfico
                          const TrackStatsPanel(),

                          if (showElevationChart)
                            ElevationChartPanel(
                              editorState: editorState,
                              height: 180,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Expanded(child: mapModule),

                    // 🎯 3. VISTA MÓVIL: Inyectamos el mismo panel aquí también por encima del gráfico
                    const TrackStatsPanel(),

                    if (showElevationChart)
                      ElevationChartPanel(
                        editorState: editorState,
                        height: 140,
                        textFontSize: 12,
                      ),
                  ],
                );
              }
            },
          ),
        ),
        if (isReverseAnimating)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.blue),
                      const SizedBox(width: 16),
                      Text(
                        t.processingGpxFile,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
