import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trackio/models/track_model.dart';

/// 🧠 ESTADO INMUTABLE AVANZADO DE TRACKIO
/// Centraliza el control de capas, herramientas vivas y la selección dual de tramos.
class GpxEditorState {
  static const Object _noChange = Object();

  final List<TrackModel> tracks;
  final int? selectedTrackId;
  final TrackPointModel? snappedPoint;
  final int? snappedPointIndex;
  final bool isMapIdle;

  // Herramientas posibles: 'none', 'split', 'merge', 'inverse', 'range_chart', 'range_map'
  final String activeTool;
  final MapLibreMapController? mapController;

  // ↕️ NUEVO: Control de visibilidad del panel inferior (Toggle)
  final bool showElevationChart;

  // 📏 NUEVO: Índices de acotación del tramo seleccionado (sublistas de puntos)
  final int? selectionStartIndex;
  final int? selectionEndIndex;

  // 🎯 NUEVO: Banderas de control fino para la retícula en mapa
  final bool isSelectingRange; // true si ya fijó el punto 1 y busca el punto 2
  final bool
  forceHideReticle; // true para esconder la mira automáticamente al cerrar el tramo

  GpxEditorState({
    required this.tracks,
    this.selectedTrackId,
    this.snappedPoint,
    this.snappedPointIndex,
    this.isMapIdle = false,
    this.activeTool = 'none',
    this.mapController,
    this.showElevationChart = true, // El gráfico se muestra abierto por defecto
    this.selectionStartIndex,
    this.selectionEndIndex,
    this.isSelectingRange = false,
    this.forceHideReticle = false,
  });

  // Estado inicial limpio al arrancar la aplicación
  factory GpxEditorState.initial() {
    return GpxEditorState(tracks: []);
  }

  // Método copyWith para mutar el estado inmutable de Riverpod sin destruir el resto de variables
  GpxEditorState copyWith({
    List<TrackModel>? tracks,
    Object? selectedTrackId = _noChange,
    Object? snappedPoint = _noChange,
    Object? snappedPointIndex = _noChange,
    bool? isMapIdle,
    String? activeTool,
    Object? mapController = _noChange,
    bool? showElevationChart,
    Object? selectionStartIndex = _noChange,
    Object? selectionEndIndex = _noChange,
    bool? isSelectingRange,
    bool? forceHideReticle,
  }) {
    final int? nextSelectionEndIndex;
    if (identical(selectionEndIndex, _noChange)) {
      nextSelectionEndIndex = this.selectionEndIndex;
    } else {
      final int? provided = selectionEndIndex as int?;
      nextSelectionEndIndex = provided == -1 ? null : provided;
    }

    return GpxEditorState(
      tracks: tracks ?? this.tracks,
      selectedTrackId: identical(selectedTrackId, _noChange)
          ? this.selectedTrackId
          : selectedTrackId as int?,
      snappedPoint: identical(snappedPoint, _noChange)
          ? this.snappedPoint
          : snappedPoint as TrackPointModel?,
      snappedPointIndex: identical(snappedPointIndex, _noChange)
          ? this.snappedPointIndex
          : snappedPointIndex as int?,
      isMapIdle: isMapIdle ?? this.isMapIdle,
      activeTool: activeTool ?? this.activeTool,
      mapController: identical(mapController, _noChange)
          ? this.mapController
          : mapController as MapLibreMapController?,
      showElevationChart: showElevationChart ?? this.showElevationChart,
      selectionStartIndex: identical(selectionStartIndex, _noChange)
          ? this.selectionStartIndex
          : selectionStartIndex as int?,
      selectionEndIndex: nextSelectionEndIndex,
      isSelectingRange: isSelectingRange ?? this.isSelectingRange,
      forceHideReticle: forceHideReticle ?? this.forceHideReticle,
    );
  }
}
