import 'package:isar/isar.dart';

/// 📍 MODELO EMBEBIDO PARA LOS PUNTOS DE LA LÍNEA DE RUTA
/// ⚡ CORRECCIÓN WEB: Forzamos un nombre de hash ultra corto seguro para JavaScript
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

  /// Permet clonar punts si en algun moment cal modificar metadades individuals
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
class TrackModel {
  int id;
  String name;
  bool isVisible;
  String hexColor;
  DateTime? importedAt;
  List<TrackPointModel> points;
  List<WaypointModel> waypoints;

  TrackModel({
    required this.name,
    this.isVisible = true,
    this.hexColor = '#007AFF',
    this.importedAt,
    List<TrackPointModel>? points,
    List<WaypointModel>? waypoints,
    int?
    id, // 👈 SOLUCIÓ AL BUG: Permetem injectar un ID existent si estem clonant
  }) : id =
           id ??
           DateTime.now()
               .microsecondsSinceEpoch, // Si és nou, genera ID; si es clona, el manté.
       points = points ?? [],
       waypoints = waypoints ?? [] {
    this.importedAt = importedAt ?? DateTime.now();
  }

  /// 🔥 EL MÈTODE SOLUCIÓ: Clona l'objecte de forma immutable transparent per a Riverpod i Isar.
  /// Evita que es generi un ID nou en utilitzar copyWith.
  TrackModel copyWith({
    String? name,
    bool? isVisible,
    String? hexColor,
    DateTime? importedAt,
    List<TrackPointModel>? points,
    List<WaypointModel>? waypoints,
  }) {
    return TrackModel(
      id: this.id, // 👈 Clau: Forcem a mantenir l'ID original de la capa
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      hexColor: hexColor ?? this.hexColor,
      importedAt: importedAt ?? this.importedAt,
      // Fem servir List.from per assegurar-nos que es trenca la referència de memòria de la llista vella
      points: points ?? List<TrackPointModel>.from(this.points),
      waypoints: waypoints ?? List<WaypointModel>.from(this.waypoints),
    );
  }
}
