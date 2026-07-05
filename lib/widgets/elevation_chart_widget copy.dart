import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';

class ElevationChartWidget extends ConsumerStatefulWidget {
  final TrackModel track;

  const ElevationChartWidget({super.key, required this.track});

  @override
  ConsumerState<ElevationChartWidget> createState() =>
      _ElevationChartWidgetState();
}

class _ElevationChartWidgetState extends ConsumerState<ElevationChartWidget> {
  List<TrackPointModel> _validPoints = [];
  List<FlSpot> _spots = [];
  List<double> _distances = [];
  double _minAlt = 0.0;
  double _maxAlt = 0.0;
  int _lastUpdateTimestamp = 0;
  int? _lastSentIndex;

  @override
  void initState() {
    super.initState();
    _precomputeChartData();
  }

  @override
  void didUpdateWidget(covariant ElevationChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _precomputeChartData(); // 🔥 també es recalcula quan només s’inverteix l’ordre dels punts
  }

  /// 🏎️ CÀLCUL EN MEMÒRIA (S'executa una sola vegada per track)
  void _precomputeChartData() {
    _validPoints = widget.track.points
        .where(
          (p) =>
              p.elevation != null && p.latitude != null && p.longitude != null,
        )
        .toList();

    if (_validPoints.isEmpty) return;

    final List<FlSpot> localSpots = [];
    final List<double> localDistances = [];
    double totalDistanceMeters = 0.0;
    double minAlt = double.infinity;
    double maxAlt = -double.infinity;

    const geo.Distance distanceCalculator = geo.Distance();
    final int len = _validPoints.length;

    // Reduïm dinàmicament el nombre d'spots visualitzats si passem de 2.000 punts
    // per evitar que fl_chart saturi la GPU en entorn web
    int step = 1;
    if (len > 2000) {
      step = (len / 2000).ceil();
    }

    for (int i = 0; i < len; i++) {
      final double alt = _validPoints[i].elevation!;

      if (i > 0) {
        totalDistanceMeters += distanceCalculator.as(
          geo.LengthUnit.Meter,
          geo.LatLng(
            _validPoints[i - 1].latitude!,
            _validPoints[i - 1].longitude!,
          ),
          geo.LatLng(_validPoints[i].latitude!, _validPoints[i].longitude!),
        );
      }

      // Mantenim l'índex real 'i' com a propietat X de l'spot gràfic!
      // Així l'eix X del mapa i de la gràfica coincideixen al 100% de manera nativa.
      if (i % step == 0 || i == len - 1) {
        localDistances.add(totalDistanceMeters);
        localSpots.add(FlSpot(i.toDouble(), alt));

        if (alt < minAlt) minAlt = alt;
        if (alt > maxAlt) maxAlt = alt;
      }
    }

    setState(() {
      _spots = localSpots;
      _distances = localDistances;
      _minAlt = (minAlt - 20).clamp(0, double.infinity);
      _maxAlt = maxAlt + 20;
      _lastSentIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_validPoints.isEmpty) {
      return const Center(
        child: Text(
          "Aquest track no conté dades d'altitud",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final int trackColorValue = int.parse(
      widget.track.hexColor.replaceFirst('#', '0xFF'),
    );
    final Color trackColor = Color(trackColorValue);

    final start = ref.watch(
      gpxEditorProvider.select((s) => s.selectionStartIndex),
    );
    final end = ref.watch(gpxEditorProvider.select((s) => s.selectionEndIndex));

    final List<FlSpot> selectedSpots = [];
    if (start != null && end != null && end != -1) {
      selectedSpots.addAll(
        _spots.where((spot) => spot.x >= start && spot.x <= end),
      );
    }

    // =========================================================================
    // 📊 1. PREPARACIÓN DEL SEGUNDO EJE Y (VELOCIDAD)
    // =========================================================================
    // Fijamos un rango fijo realista para la velocidad (de 0 a 40 km/h por ejemplo)
    const double maxSpeedTarget = 40.0;
    const double minSpeedTarget = 0.0;

    // Fórmulas para proyectar la velocidad dentro del rango de altitud (_minAlt a _maxAlt)
    double scaleSpeedToAlt(double speed) {
      final double altRange = _maxAlt - _minAlt;
      if (altRange <= 0) return _minAlt;
      return _minAlt +
          ((speed - minSpeedTarget) / (maxSpeedTarget - minSpeedTarget)) *
              altRange;
    }

    double scaleAltToSpeed(double altY) {
      final double altRange = _maxAlt - _minAlt;
      if (altRange <= 0) return 0.0;
      return minSpeedTarget +
          ((altY - _minAlt) / altRange) * (maxSpeedTarget - minSpeedTarget);
    }

    // 🚀 NUEVO: Generamos los spots de velocidad usando el escalado matemático
    // Calculamos la velocidad punto a punto basándonos en la distancia y el tiempo del GPX
    final List<FlSpot> speedSpots = [];
    const geo.Distance distanceCalculator = geo.Distance();

    for (int i = 0; i < _validPoints.length; i++) {
      // Aplicamos el mismo filtro de optimización 'step' que usas en tu INITSTATE para no saturar la GPU
      int step = 1;
      if (_validPoints.length > 2000)
        step = (_validPoints.length / 2000).ceil();
      if (i % step != 0 && i != _validPoints.length - 1) continue;

      double speedKmh = 0.0;
      if (i > 0) {
        final pPrev = _validPoints[i - 1];
        final pCurr = _validPoints[i];

        if (pPrev.timestamp != null &&
            pCurr.timestamp != null &&
            pPrev.latitude != null &&
            pCurr.latitude != null) {
          final seconds = pCurr.timestamp!
              .difference(pPrev.timestamp!)
              .inSeconds;
          if (seconds > 0) {
            final meters = distanceCalculator.as(
              geo.LengthUnit.Meter,
              geo.LatLng(pPrev.latitude!, pPrev.longitude!),
              geo.LatLng(pCurr.latitude!, pCurr.longitude!),
            );
            speedKmh = (meters / 1000) / (seconds / 3600);
          }
        }
      }
      // Guardamos la velocidad escalada al rango de altitud
      speedSpots.add(
        FlSpot(
          i.toDouble(),
          scaleSpeedToAlt(speedKmh.clamp(0, maxSpeedTarget)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 24, left: 12, bottom: 8),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchCallback:
                (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  if (touchResponse == null ||
                      touchResponse.lineBarSpots == null)
                    return;

                  final int currentTimestamp =
                      DateTime.now().millisecondsSinceEpoch;
                  if (currentTimestamp - _lastUpdateTimestamp < 30) return;
                  _lastUpdateTimestamp = currentTimestamp;

                  final spots = touchResponse.lineBarSpots!;
                  if (spots.isNotEmpty) {
                    final int realPointsIndex = spots.first.x.toInt();
                    if (realPointsIndex >= 0 &&
                        realPointsIndex < _validPoints.length) {
                      if (_lastSentIndex == realPointsIndex) return;
                      _lastSentIndex = realPointsIndex;

                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateSnappedPoint(
                            _validPoints[realPointsIndex],
                            realPointsIndex,
                          );
                    }
                  }
                },
            touchTooltipData: LineTouchTooltipData(
              maxContentWidth: 160,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                if (_distances.isEmpty || touchedSpots.isEmpty) return [];

                // 1. Tomamos el índice X del punto que se ha tocado (compartido por altitud y velocidad)
                final int index = touchedSpots.first.x.toInt();

                // 2. Calculamos de forma segura la aproximación de la distancia acumulada
                final int distanceIndex =
                    ((index / (_validPoints.length - 1)) *
                            (_distances.length - 1))
                        .clamp(0, _distances.length - 1)
                        .toInt();
                final double metersAccumulated = _distances[distanceIndex];

                final int km = (metersAccumulated / 1000).floor();
                final int m = (metersAccumulated % 1000).round();
                final String distanceString = km > 0
                    ? "${km}km ${m}m"
                    : "${m}m";

                // 3. Extraemos la Altitud real del track
                final double realAlt =
                    _validPoints[index.clamp(0, _validPoints.length - 1)]
                        .elevation ??
                    0.0;

                // 4. Extraemos la Velocidad desescalando el valor Y ficticio de la Línea 3
                // Buscamos si entre los spots tocados está el de la línea de velocidad (el tercero de la lista)
                // Si no, lo calculamos directamente con las mismas funciones de escala que creamos arriba
                final speedSpot = speedSpots.firstWhere(
                  (s) => s.x.toInt() == index,
                  orElse: () => FlSpot(0, _minAlt),
                );
                final double realSpeed = scaleAltToSpeed(speedSpot.y);

                // 5. 🌟 REPARADO: Generamos una lista mapeada que coincide al 100% con la longitud requerida por fl_chart
                int counter = 0;
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  // Solo al primer elemento de la lista le inyectamos el cuadro de texto unificado
                  if (counter == 0) {
                    counter++;
                    return LineTooltipItem(
                      "$distanceString\n⛰️ Alt: ${realAlt.toStringAsFixed(0)}m\n⚡ Vel: ${realSpeed.toStringAsFixed(1)} km/h",
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    );
                  }
                  // Para las líneas superpuestas (Línea 2 y Línea 3), devolvemos null para que no pinten cuadros duplicados
                  return null;
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            // 🌟 2. ACTIVACIÓN Y CONFIGURACIÓN DEL EJE Y DERECHO (VELOCIDAD)
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  // Desescalamos el valor Y ficticio del mapa para convertirlo en texto real de velocidad
                  final double speedVal = scaleAltToSpeed(value);
                  // Solo mostramos etiquetas legibles espaciadas (ej: múltiplos de 10)
                  if (speedVal % 10 == 0 || speedVal == maxSpeedTarget) {
                    return Text(
                      "${speedVal.toStringAsFixed(0)} km/h",
                      style: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text(
                    "${value.toStringAsFixed(0)}m",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (_validPoints.length - 1).toDouble(),
          minY: _minAlt,
          maxY: _maxAlt,
          lineBarsData: [
            // LÍNEA 1: Perfil de fondo completo de la ruta (Altitud)
            LineChartBarData(
              spots: _spots,
              isCurved: false,
              color: trackColor,
              barWidth: 2.0,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: trackColor.withValues(alpha: 0.1),
              ),
            ),

            // LÍNEA 2: Capa superpuesta para el tramo destacado
            if (selectedSpots.isNotEmpty)
              LineChartBarData(
                spots: selectedSpots,
                isCurved: false,
                color: Colors.orange.shade800,
                barWidth: 3.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.orange.shade400.withValues(alpha: 0.35),
                ),
              ),

            // LÍNEA 3: 🌟 NUEVA CURVA DE VELOCIDAD EN TIEMPO REAL (Línea discontinua azul/gris)
            // LÍNEA 3: 🌟 NUEVA CURVA DE VELOCIDAD EN TIEMPO REAL (Línea suave estilizada)
            if (speedSpots.isNotEmpty)
              LineChartBarData(
                spots: speedSpots,
                isCurved: true, // Suaviza los picos bruscos del GPS
                color: Colors.teal.shade500.withValues(
                  alpha: 0.6,
                ), // Color contrastado que no ensucia la altitud
                barWidth:
                    1.2, // Más fina para diferenciarla claramente de la línea de altitud
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}
