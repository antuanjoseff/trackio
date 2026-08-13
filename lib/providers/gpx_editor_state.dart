import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trackio/models/track_model.dart';

/// 🧠 ESTADO INMUTABLE AVANCED DE TRACKIO
class GpxEditorState {
  static const Object _noChange = Object();

  final bool showSpeedInChart;
  final List<TrackModel> tracks;
  final int? selectedTrackId;
  final TrackPointModel? snappedPoint;
  final int? snappedPointIndex;
  final bool isMapIdle;
  final bool showSidebar;

  // Herramientas posibles: 'none', 'split', 'merge', 'inverse', 'range_chart', 'range_map', 'add_waypoint', 'draw', 'edit_geometry'
  final String activeTool;

  final bool showElevationChart;
  final int? selectionStartIndex;
  final int? selectionEndIndex;
  final bool isSelectingRange;
  final bool forceHideReticle;

  final int? previewTrackId;
  final List<TrackPointModel>? previewPoints;
  final List<int> loadingTrackIds;

  final LatLng? waypointCameraPosition;

  // 🌟 Edició de geometria
  final String? geometryEditMode; // 'add' | 'delete' | 'move'
  final int? geometryInsertIndex;
  final int? geometryMoveNodeIndex;
  final bool geometryCanUndo;
  final bool canUndoAction;

  // 🌟 Dibuix interactiu
  final List<TrackPointModel> drawingPoints;
  final TrackPointModel? drawingLivePoint;

  // 🌟 NOUS CAMPS PER AL GRÀFIC (agulles i rang)
  final int? chartNeedleIndex;
  final int? chartRangeStartIndex;
  final int? chartRangeEndIndex;
  final String chartSelectionMode;

  GpxEditorState({
    required this.tracks,
    this.selectedTrackId,
    this.snappedPoint,
    this.snappedPointIndex,
    this.isMapIdle = false,
    this.activeTool = 'none',
    this.showElevationChart = false,
    this.showSpeedInChart = true,
    this.selectionStartIndex,
    this.selectionEndIndex,
    this.isSelectingRange = false,
    this.forceHideReticle = false,
    this.previewTrackId,
    this.previewPoints,
    this.loadingTrackIds = const [],
    this.waypointCameraPosition,
    this.geometryEditMode,
    this.geometryInsertIndex,
    this.geometryMoveNodeIndex,
    this.geometryCanUndo = false,
    this.canUndoAction = false,
    this.showSidebar = true,
    this.drawingPoints = const [],
    this.drawingLivePoint,

    // 🌟 NOUS CAMPS
    this.chartNeedleIndex,
    this.chartRangeStartIndex,
    this.chartRangeEndIndex,
    this.chartSelectionMode = 'simple',
  });

  factory GpxEditorState.initial() {
    return GpxEditorState(
      tracks: [],
      loadingTrackIds: const [],
      showSidebar: false,
    );
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
    bool? showSpeedInChart,
    Object? selectionStartIndex = _noChange,
    Object? selectionEndIndex = _noChange,
    bool? isSelectingRange,
    bool? forceHideReticle,
    Object? previewTrackId = _noChange,
    Object? previewPoints = _noChange,
    List<int>? loadingTrackIds,
    Object? waypointCameraPosition = _noChange,
    Object? geometryEditMode = _noChange,
    Object? geometryInsertIndex = _noChange,
    Object? geometryMoveNodeIndex = _noChange,
    bool? geometryCanUndo,
    bool? canUndoAction,
    bool? showSidebar,
    List<TrackPointModel>? drawingPoints,
    Object? drawingLivePoint = _noChange,

    // 🌟 NOUS PARÀMETRES
    Object? chartNeedleIndex = _noChange,
    Object? chartRangeStartIndex = _noChange,
    Object? chartRangeEndIndex = _noChange,
    Object? chartSelectionMode = _noChange,
  }) {
    final int? nextSelectionEndIndex = identical(selectionEndIndex, _noChange)
        ? this.selectionEndIndex
        : ((selectionEndIndex as int?) == -1 ? null : selectionEndIndex);

    final int? nextSelectedTrackId = identical(selectedTrackId, _noChange)
        ? this.selectedTrackId
        : (selectedTrackId == null
              ? null
              : int.tryParse(selectedTrackId.toString()));

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
      showSpeedInChart: showSpeedInChart ?? this.showSpeedInChart,
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
      geometryEditMode: identical(geometryEditMode, _noChange)
          ? this.geometryEditMode
          : geometryEditMode as String?,
      geometryInsertIndex: identical(geometryInsertIndex, _noChange)
          ? this.geometryInsertIndex
          : geometryInsertIndex as int?,
      geometryMoveNodeIndex: identical(geometryMoveNodeIndex, _noChange)
          ? this.geometryMoveNodeIndex
          : geometryMoveNodeIndex as int?,
      geometryCanUndo: geometryCanUndo ?? this.geometryCanUndo,
      canUndoAction: canUndoAction ?? this.canUndoAction,
      showSidebar: showSidebar ?? this.showSidebar,
      drawingPoints: drawingPoints ?? this.drawingPoints,
      drawingLivePoint: identical(drawingLivePoint, _noChange)
          ? this.drawingLivePoint
          : drawingLivePoint as TrackPointModel?,

      // 🌟 NOUS CAMPS
      chartNeedleIndex: identical(chartNeedleIndex, _noChange)
          ? this.chartNeedleIndex
          : chartNeedleIndex as int?,
      chartRangeStartIndex: identical(chartRangeStartIndex, _noChange)
          ? this.chartRangeStartIndex
          : chartRangeStartIndex as int?,
      chartRangeEndIndex: identical(chartRangeEndIndex, _noChange)
          ? this.chartRangeEndIndex
          : chartRangeEndIndex as int?,
      chartSelectionMode: identical(chartSelectionMode, _noChange)
          ? this.chartSelectionMode
          : chartSelectionMode as String,
    );
  }
}
