import 'package:maplibre_gl/maplibre_gl.dart'; // 🆕 Importante
import 'package:trackio/models/track_model.dart';

class GpxEditorState {
  final List<TrackModel> tracks;
  final int? selectedTrackId;
  final TrackPointModel? snappedPoint;
  final int? snappedPointIndex;
  final bool isMapIdle;
  final String activeTool;

  // 🆕 NUEVA VARIABLE: El mando a distancia del mapa
  final MapLibreMapController? mapController;

  GpxEditorState({
    required this.tracks,
    this.selectedTrackId,
    this.snappedPoint,
    this.snappedPointIndex,
    this.isMapIdle = false,
    this.activeTool = 'none',
    this.mapController, // 🆕
  });

  factory GpxEditorState.initial() {
    return GpxEditorState(tracks: []);
  }

  GpxEditorState copyWith({
    List<TrackModel>? tracks,
    int? selectedTrackId,
    TrackPointModel? snappedPoint,
    int? snappedPointIndex,
    bool? isMapIdle,
    String? activeTool,
    MapLibreMapController? mapController, // 🆕
  }) {
    return GpxEditorState(
      tracks: tracks ?? this.tracks,
      selectedTrackId: selectedTrackId ?? this.selectedTrackId,
      snappedPoint: snappedPoint ?? this.snappedPoint,
      snappedPointIndex: snappedPointIndex ?? this.snappedPointIndex,
      isMapIdle: isMapIdle ?? this.isMapIdle,
      activeTool: activeTool ?? this.activeTool,
      mapController: mapController ?? this.mapController, // 🆕
    );
  }
}
