import 'package:isar/isar.dart';

/// 📍 PASO 1.1 (A): Modelo embebido para los puntos de la línea de ruta
/// ⚡ CORRECCIÓN WEB: Forzamos un nombre de hash ultra corto seguro para JavaScript
@embedded
@Name('TP')
/// 📍 MODELO DE DATOS PURO PARA TRACKIO (MULTIPLATAFORMA WEB/MÓVIL)
/// Eliminamos Isar temporalmente para asegurar compatibilidad 100% con JavaScript.
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
}

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
}

class TrackModel {
  // Generamos un ID único numérico basado en milisegundos para cada capa
  int id;
  String name;
  bool isVisible;
  String hexColor;
  DateTime? importedAt;
  List<TrackPointModel> points = [];
  List<WaypointModel> waypoints = [];

  TrackModel({
    required this.name,
    this.isVisible = true,
    this.hexColor = '#007AFF',
    this.importedAt,
    this.points = const [],
    this.waypoints = const [],
  }) : id = DateTime.now().microsecondsSinceEpoch {
    this.importedAt = importedAt ?? DateTime.now();
  }
}
