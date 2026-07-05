import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trackio/models/track_model.dart';

/// 🧠 ESTADO INMUTABLE AVANCED DE TRACKIO
class GpxEditorState {
  static const Object _noChange = Object();

  final bool showSpeedInChart; // 🌟 Afegit correctament
  final List<TrackModel> tracks;
  final int? selectedTrackId;
  final TrackPointModel? snappedPoint;
  final int? snappedPointIndex;
  final bool isMapIdle;

  // Herramientas posibles: 'none', 'split', 'merge', 'inverse', 'range_chart', 'range_map', 'add_waypoint' 👈 NUEVA
  final String activeTool;

  final bool showElevationChart;
  final int? selectionStartIndex;
  final int? selectionEndIndex;
  final bool isSelectingRange;
  final bool forceHideReticle;

  final int? previewTrackId;
  final List<TrackPointModel>? previewPoints;
  final List<int> loadingTrackIds;

  // 📍 NUEVO: Guarda la posición actual de la retícula central cuando la herramienta está activa
  final LatLng? waypointCameraPosition;

  GpxEditorState({
    required this.tracks,
    this.selectedTrackId,
    this.snappedPoint,
    this.snappedPointIndex,
    this.isMapIdle = false,
    this.activeTool = 'none',
    this.showElevationChart = true,
    this.showSpeedInChart = true, // 🌟 Inicialitzador
    this.selectionStartIndex,
    this.selectionEndIndex,
    this.isSelectingRange = false,
    this.forceHideReticle = false,
    this.previewTrackId,
    this.previewPoints,
    this.loadingTrackIds = const [],
    this.waypointCameraPosition,
  });

  factory GpxEditorState.initial() {
    return GpxEditorState(tracks: [], loadingTrackIds: const []);
  }

  GpxEditorState copyWith({
    List<TrackModel>? tracks,
    Object? selectedTrackId = _noChange,
    Object? snappedPoint = _noChange,
    Object? snappedPointIndex = _noChange,
    bool? isMapIdle,
    String? activeTool,
    Object? mapController = _noChange,
    bool? showElevationChart,
    bool? showSpeedInChart, // 🌟 1. AFEGIT COM A PARÀMETRE OPTIONAL
    Object? selectionStartIndex = _noChange,
    Object? selectionEndIndex = _noChange,
    bool? isSelectingRange,
    bool? forceHideReticle,
    Object? previewTrackId = _noChange,
    Object? previewPoints = _noChange,
    List<int>? loadingTrackIds,
    Object? waypointCameraPosition = _noChange,
  }) {
    final int? nextSelectionEndIndex;
    if (identical(selectionEndIndex, _noChange)) {
      nextSelectionEndIndex = this.selectionEndIndex;
    } else {
      final int? provided = selectionEndIndex as int?;
      nextSelectionEndIndex = provided == -1 ? null : provided;
    }

    final int? nextSelectedTrackId;
    if (identical(selectedTrackId, _noChange)) {
      nextSelectedTrackId = this.selectedTrackId;
    } else if (selectedTrackId == null) {
      nextSelectedTrackId = null;
    } else {
      nextSelectedTrackId = int.tryParse(selectedTrackId.toString());
    }

    return GpxEditorState(
      tracks: tracks ?? this.tracks,
      selectedTrackId: nextSelectedTrackId,
      snappedPoint: identical(snappedPoint, _noChange)
          ? this.snappedPoint
          : snappedPoint as TrackPointModel?,
      snappedPointIndex: identical(snappedPointIndex, _noChange)
          ? this.snappedPointIndex
          : snappedPointIndex as int?,
      isMapIdle: isMapIdle ?? this.isMapIdle,
      activeTool: activeTool ?? this.activeTool,
      showElevationChart: showElevationChart ?? this.showElevationChart,
      showSpeedInChart:
          showSpeedInChart ??
          this.showSpeedInChart, // 🌟 2. INJECTAT EN RETORNAR EL NOU ESTAT
      selectionStartIndex: identical(selectionStartIndex, _noChange)
          ? this.selectionStartIndex
          : selectionStartIndex as int?,
      selectionEndIndex: nextSelectionEndIndex,
      isSelectingRange: isSelectingRange ?? this.isSelectingRange,
      forceHideReticle: forceHideReticle ?? this.forceHideReticle,
      previewTrackId: identical(previewTrackId, _noChange)
          ? this.previewTrackId
          : previewTrackId as int?,
      previewPoints: identical(previewPoints, _noChange)
          ? this.previewPoints
          : previewPoints as List<TrackPointModel>?,
      loadingTrackIds: loadingTrackIds ?? this.loadingTrackIds,
      waypointCameraPosition: identical(waypointCameraPosition, _noChange)
          ? this.waypointCameraPosition
          : waypointCameraPosition as LatLng?,
    );
  }
}
