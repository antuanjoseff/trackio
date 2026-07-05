import 'package:isar/isar.dart';

/// 📍 MODELO EMBEBIDO PARA LOS PUNTOS DE LA LÍNEA DE RUTA
@embedded
@Name('TP')
class TrackPointModel {
  double? latitude;
  double? longitude;
  double? elevation;
  DateTime? timestamp;

  TrackPointModel({
    this.latitude,
    this.longitude,
    this.elevation,
    this.timestamp,
  });

  TrackPointModel copyWith({
    double? latitude,
    double? longitude,
    double? elevation,
    DateTime? timestamp,
  }) {
    return TrackPointModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevation: elevation ?? this.elevation,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// 📍 MODELO EMBEBIDO PARA LOS WAYPOINTS / FITES
@embedded
@Name('WP')
class WaypointModel {
  double? latitude;
  double? longitude;
  double? elevation;
  String? name;
  String? comment;

  WaypointModel({
    this.latitude,
    this.longitude,
    this.elevation,
    this.name,
    this.comment,
  });

  WaypointModel copyWith({
    double? latitude,
    double? longitude,
    double? elevation,
    String? name,
    String? comment,
  }) {
    return WaypointModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevation: elevation ?? this.elevation,
      name: name ?? this.name,
      comment: comment ?? this.comment,
    );
  }
}

/// 📍 MODELO PRINCIPAL DE TRACK (MULTIPLATAFORMA WEB/MÓVIL)
@collection
class TrackModel {
  // Isar requiere que Id sea un entero asignable.
  Id id;

  String name;
  bool isVisible;
  String hexColor;
  DateTime? importedAt;
  List<TrackPointModel> points;
  List<WaypointModel> waypoints;

  /// 🌟 CONSTRUCTOR PRINCIPAL REPARADO:
  /// Añadimos 'id' opcional. Si se pasa, Isar y Riverpod lo respetan.
  /// Si no se pasa, genera automáticamente el código de tiempo seguro.
  TrackModel({
    this.name = '',
    this.isVisible = true,
    this.hexColor = '#007AFF',
    this.importedAt,
    List<TrackPointModel>? points,
    List<WaypointModel>? waypoints,
    int? id, // 👈 Parámetro nominal reintroducido con éxito
  }) : id = id ?? (DateTime.now().microsecondsSinceEpoch & 0x1FFFFFFFFFFFFF),
       points = points ?? const [],
       waypoints = waypoints ?? const [] {
    this.importedAt = importedAt ?? DateTime.now();
  }

  /// Helper alternativo que mantiene compatibilidad si tu app lo llamaba en otras pantallas
  factory TrackModel.create({
    required String name,
    bool isVisible = true,
    String hexColor = '#007AFF',
    DateTime? importedAt,
    List<TrackPointModel>? points,
    List<WaypointModel>? waypoints,
    int? id,
  }) {
    return TrackModel(
      id: id,
      name: name,
      isVisible: isVisible,
      hexColor: hexColor,
      importedAt: importedAt,
      points: points,
      waypoints: waypoints,
    );
  }

  /// Copia el objeto de forma inmutable sin romper referencias ni perder el ID
  TrackModel copyWith({
    String? name,
    bool? isVisible,
    String? hexColor,
    DateTime? importedAt,
    List<TrackPointModel>? points,
    List<WaypointModel>? waypoints,
  }) {
    return TrackModel(
      id: this.id, // Forzamos a mantener el ID original al clonar capas
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      hexColor: hexColor ?? this.hexColor,
      importedAt: importedAt ?? this.importedAt,
      points: points ?? List<TrackPointModel>.from(this.points),
      waypoints: waypoints ?? List<WaypointModel>.from(this.waypoints),
    );
  }
}
