import 'dart:async';
import 'dart:collection';
import 'cog_service.dart';

class TrackElevationService {
  // Canviem el punt únic per una cua d'espera concurrent
  final Queue<
    (
      double lat,
      double lon,
      void Function(double lat, double lon, double ele) callback,
    )
  >
  _queue = Queue();
  bool _isProcessing = false;

  void requestPoint({
    required double lat,
    required double lon,
    required void Function(double lat, double lon, double ele) onResult,
  }) {
    // 1. Afegim el punt i la seva funció de resposta a la cua
    _queue.add((lat, lon, onResult));

    // 2. Iniciem el processament en cadena si no estava actiu
    if (!_isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      // Treiem el primer punt de la cua (FIFO: First In, First Out)
      final current = _queue.removeFirst();
      final lat = current.$1;
      final lon = current.$2;
      final onResult = current.$3;

      try {
        // Demanem l'alçada de manera segura al teu CogService binari
        final ele = await CogService().getElevation(lat, lon);

        // Retornem la veritat al Notifier de Riverpod
        onResult(lat, lon, ele);
      } catch (e) {
        // Si falla la xarxa, retornem alçada 0.0 de seguretat per no congelar l'app
        onResult(lat, lon, 0.0);
      }
    }

    _isProcessing = false;
  }
}
