import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Orientació actual del mapa en graus (0 = nord amunt).
final mapBearingProvider = StateProvider<double>((ref) => 0.0);

/// Escala gràfica actual: metres representats i amplada en píxels.
final mapScaleMetersProvider = StateProvider<int?>((ref) => null);
final mapScaleWidthPxProvider = StateProvider<double?>((ref) => null);
