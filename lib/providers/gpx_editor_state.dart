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

  // ↕️ NUEVO: Control de visibilidad del panel inferior (Toggle)
  final bool showElevationChart;

  // 📏 NUEVO: Índices de acotación del tramo seleccionado (sublistas de puntos)
  final int? selectionStartIndex;
  final int? selectionEndIndex;

  // 🎯 NUEVO: Banderas de control fino para la retícula en mapa
  final bool isSelectingRange; // true si ya fijó el punto 1 y busca el punto 2
  final bool
  forceHideReticle; // true para esconder la mira automáticamente al cerrar el tramo

  final int? previewTrackId; // ID del track proper a la retícula
  final List<TrackPointModel>? previewPoints;

  // ⏳ NUEVO: Control reactivo de tracks que se están procesando individualmente en segundo plano
  final List<int> loadingTrackIds;

  GpxEditorState({
    required this.tracks,
    this.selectedTrackId,
    this.snappedPoint,
    this.snappedPointIndex,
    this.isMapIdle = false,
    this.activeTool = 'none',

    this.showElevationChart = true, // El gráfico se muestra abierto por defecto
    this.selectionStartIndex,
    this.selectionEndIndex,
    this.isSelectingRange = false,
    this.forceHideReticle = false,
    this.previewTrackId,
    this.previewPoints,
    this.loadingTrackIds = const [], // 🌟 Buit per defecte al néixer
  });

  // Estado inicial limpio al arrancar la aplicación
  factory GpxEditorState.initial() {
    return GpxEditorState(tracks: [], loadingTrackIds: const []);
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
    Object? previewTrackId = _noChange,
    Object? previewPoints = _noChange,
    List<int>? loadingTrackIds, // 🌟 Nova propietat inmutable al copyWith
  }) {
    final int? nextSelectionEndIndex;
    if (identical(selectionEndIndex, _noChange)) {
      nextSelectionEndIndex = this.selectionEndIndex;
    } else {
      final int? provided = selectionEndIndex as int?;
      nextSelectionEndIndex = provided == -1 ? null : provided;
    }

    // 🔒 PROTECCIÓ DE TIPUS: Blindem el selectedTrackId perquè sigui SEMPRE un int numèric net
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
      selectedTrackId:
          nextSelectedTrackId, // 👈 Guardat amb èxit i format correcte
      snappedPoint: identical(snappedPoint, _noChange)
          ? this.snappedPoint
          : snappedPoint as TrackPointModel?,
      snappedPointIndex: identical(snappedPointIndex, _noChange)
          ? this.snappedPointIndex
          : snappedPointIndex as int?,
      isMapIdle: isMapIdle ?? this.isMapIdle,
      activeTool: activeTool ?? this.activeTool,
      showElevationChart: showElevationChart ?? this.showElevationChart,
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
      loadingTrackIds:
          loadingTrackIds ?? this.loadingTrackIds, // 👈 Assignació neta
    );
  }
}
