import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:trackio/l10n/app_localizations.dart';
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
    _precomputeChartData();
  }

  /// 🏎️ CÀLCUL EN MEMÒRIA BASAT EN DISTÀNCIA REAL (MÈTRES)
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

    int step = 1;
    if (len > 2000) {
      step = (len / 2000).ceil();
    }

    // El primer punt comença sempre a 0 metres acumulats
    localDistances.add(0.0);

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
        localDistances.add(totalDistanceMeters);
      }

      // 🌟 L'eix X és ara la distància real (totalDistanceMeters) en comptes de l'índex secuencial (i)
      if (i % step == 0 || i == len - 1) {
        localSpots.add(FlSpot(totalDistanceMeters, alt));

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
    final t = AppLocalizations.of(context)!;
    if (_validPoints.isEmpty) {
      return Center(
        child: Text(
          t.trackWithoutElevationData,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final int trackColorValue = int.parse(
      widget.track.hexColor.replaceFirst('#', '0xFF'),
    );
    final Color trackColor = Color(trackColorValue);

    // 1. Leemos las variables fijas de rango del estado de Riverpod
    final start = ref.watch(
      gpxEditorProvider.select((s) => s.selectionStartIndex),
    );
    final end = ref.watch(gpxEditorProvider.select((s) => s.selectionEndIndex));

    // =========================================================================
    // 📊 CONFIGURACIÓ MATEMÀTICA DEL SEGON EIX Y (VELOCITAT)
    // =========================================================================
    const double maxSpeedTarget = 40.0;
    const double minSpeedTarget = 0.0;

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

    // Generación de spots de velocidad utilizando la distancia real (metros) como eje X
    final List<FlSpot> speedSpots = [];
    const geo.Distance distanceCalculator = geo.Distance();

    for (int i = 0; i < _validPoints.length; i++) {
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

      final double currentMeters =
          _distances[i.clamp(0, _distances.length - 1)];
      speedSpots.add(
        FlSpot(
          currentMeters,
          scaleSpeedToAlt(speedKmh.clamp(0, maxSpeedTarget)),
        ),
      );
    }

    // =========================================================================
    // 🌟 NUEVO: CÁLCULO DINÁMICO DEL RANGO (FIJO O EFÍMERO EN VIVO)
    // =========================================================================
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final isSelectingRange = ref.watch(
      gpxEditorProvider.select((s) => s.isSelectingRange),
    );
    final snappedIdx = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPointIndex),
    );

    int? startPointsIndex;
    int? endPointsIndex;

    if (activeTool == 'range_map') {
      if (start != null && end != null && end != -1 && !isSelectingRange) {
        // Opción A: El tramo ya está guardado y fijado de forma definitiva (Fase 3)
        startPointsIndex = start;
        endPointsIndex = end;
      } else if (start != null && isSelectingRange && snappedIdx != null) {
        // Opción B: Tramo efímero en vivo (Fase 2) mientras mueves el mapa
        startPointsIndex = start < snappedIdx ? start : snappedIdx;
        endPointsIndex = start < snappedIdx ? snappedIdx : start;
      }
    } else if (activeTool == 'split' && snappedIdx != null) {
      // Opción C: Iluminación elástica del modo split hasta la tijera
      startPointsIndex = 0;
      endPointsIndex = snappedIdx;
    }

    // Filtramos la lista de '_spots' buscando los metros del rango dinámico
    final List<FlSpot> selectedSpots = [];
    if (startPointsIndex != null && endPointsIndex != null) {
      final double startMeters =
          _distances[startPointsIndex.clamp(0, _distances.length - 1)];
      final double endMeters =
          _distances[endPointsIndex.clamp(0, _distances.length - 1)];
      selectedSpots.addAll(
        _spots.where((spot) => spot.x >= startMeters && spot.x <= endMeters),
      );
    }
    final showSpeed = ref.watch(
      gpxEditorProvider.select((s) => s.showSpeedInChart),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 24, left: 12, bottom: 8),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            // Desactivem els tooltips natius només en modo 'range_map' per a que no facin nosa en arrossegar el dit
            handleBuiltInTouches: activeTool != 'range_map',
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
              if (event is FlPanStartEvent || event is FlTapDownEvent) {
                ref.read(gpxEditorProvider.notifier).setActiveTool('range_map');
              }

              if (touchResponse == null ||
                  touchResponse.lineBarSpots == null ||
                  touchResponse.lineBarSpots!.isEmpty) {
                // Si l'usuari surt dels marges de la gràfica o aixeca el dit fora, consolidem el rang de seguretat
                if (touchResponse == null ||
                    touchResponse.lineBarSpots == null ||
                    touchResponse.lineBarSpots!.isEmpty) {
                  // 🏁 Netegem l'esdeveniment que donava error: eliminem FlLongPressEndEvent
                  if ((event is FlTapUpEvent || event is FlPanEndEvent) &&
                      activeTool == 'range_map') {
                    if (start != null && snappedIdx != null) {
                      ref
                          .read(gpxEditorProvider.notifier)
                          .finalizeChartRangeSelection(start, snappedIdx);
                    }
                  }
                  return;
                }

                return;
              }

              // 🧮 CÀLCUL D'ÍNDEX (El teu codi original intacte): Trobem el punt GPX més proper segons els metres X
              final double touchedMeters = touchResponse.lineBarSpots!.first.x;
              int realPointsIndex = 0;
              double minDiff = double.infinity;

              for (int i = 0; i < _distances.length; i++) {
                final double diff = (touchedMeters - _distances[i]).abs();
                if (diff < minDiff) {
                  minDiff = diff;
                  realPointsIndex = i;
                }
              }
              realPointsIndex = realPointsIndex.clamp(
                0,
                _validPoints.length - 1,
              );

              final notifier = ref.read(gpxEditorProvider.notifier);

              // =========================================================================
              // 📐 CAS A: EINA SELECCIONAR TRAM ACTIVA (range_map)
              // =========================================================================
              if (activeTool == 'range_map') {
                // 🛑 FASE 1: Inici de la selecció (Funciona unificat amb Clic o Toc Tàctil)
                if (event is FlTapDownEvent || event is FlPanStartEvent) {
                  _lastSentIndex = realPointsIndex;
                  notifier.startChartRangeSelection(realPointsIndex);

                  // Si és un inici tàctil, fem un petit feedback vibratori opcional
                  if (event is FlPanStartEvent) {
                    try {
                      Feedback.forLongPress(context);
                    } catch (_) {}
                  }
                }

                // 🔄 FASE 2: Arrossegament elàstic en viu (L'usuari mou el dit/ratolí)
                if (event is FlPanUpdateEvent) {
                  final int currentTimestamp =
                      DateTime.now().millisecondsSinceEpoch;
                  if (currentTimestamp - _lastUpdateTimestamp < 30) return;
                  _lastUpdateTimestamp = currentTimestamp;

                  if (_lastSentIndex != realPointsIndex) {
                    _lastSentIndex = realPointsIndex;
                    notifier.updateChartRangeSelection(
                      realPointsIndex,
                      _validPoints[realPointsIndex],
                    );
                  }
                }

                // 🏁 FASE 3: L'usuari aixeca el dit o el ratolí (Congelar el tram)
                if (event is FlTapUpEvent || event is FlPanEndEvent) {
                  if (start != null) {
                    notifier.finalizeChartRangeSelection(
                      start,
                      realPointsIndex,
                    );
                  }
                  _lastSentIndex = null;
                }
              }
              // =========================================================================
              // ✂️ CAS B: COMPORTAMENT PER DEFECTE / RETÍCULA O SPLIT (El teu hover original)
              // =========================================================================
              else {
                final int currentTimestamp =
                    DateTime.now().millisecondsSinceEpoch;
                if (currentTimestamp - _lastUpdateTimestamp < 30) return;
                _lastUpdateTimestamp = currentTimestamp;

                if (_lastSentIndex == realPointsIndex) return;
                _lastSentIndex = realPointsIndex;

                notifier.updateSnappedPoint(
                  _validPoints[realPointsIndex],
                  realPointsIndex,
                );
              }
            },
            touchTooltipData: LineTouchTooltipData(
              maxContentWidth: 160,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                if (_distances.isEmpty || touchedSpots.isEmpty) return [];

                final double metersAccumulated = touchedSpots.first.x;

                final int km = (metersAccumulated / 1000).floor();
                final int m = (metersAccumulated % 1000).round();
                final String distanceString = km > 0 ? "$km km $m m" : "$m m";

                int searchIndex = 0;
                double minDiff = double.infinity;
                for (int i = 0; i < _distances.length; i++) {
                  final double diff = (metersAccumulated - _distances[i]).abs();
                  if (diff < minDiff) {
                    minDiff = diff;
                    searchIndex = i;
                  }
                }
                searchIndex = searchIndex.clamp(0, _validPoints.length - 1);
                final double realAlt =
                    _validPoints[searchIndex].elevation ?? 0.0;

                final speedSpot = speedSpots.firstWhere(
                  (s) => (s.x - metersAccumulated).abs() < 10.0,
                  orElse: () => FlSpot(metersAccumulated, _minAlt),
                );
                final double realSpeed = scaleAltToSpeed(speedSpot.y);

                int counter = 0;
                return touchedSpots.map((LineBarSpot touchedSpot) {
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
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showSpeed,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  final double speedVal = scaleAltToSpeed(value);
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
          maxX: _distances.isNotEmpty ? _distances.last : 0.0,
          minY: _minAlt,
          maxY: _maxAlt,
          lineBarsData: [
            // 1. Línea Base: Perfil complet d'Altitud (es queda sempre visible)
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

            // 2. Línea de Tram seleccionat (apareix si hi ha selecció activa)
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

            // 🌟 3. LÍNIA DE VELOCITAT CORREGIDA: Ara respecta el toggle de l'usuari
            if (speedSpots.isNotEmpty &&
                showSpeed) // 👈 Afegim "&& showSpeed" aquí
              LineChartBarData(
                spots: speedSpots,
                isCurved: true,
                color: Colors.teal.shade500.withValues(alpha: 0.6),
                barWidth: 1.2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}
