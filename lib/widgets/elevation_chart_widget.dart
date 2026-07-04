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

    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 24, left: 12, bottom: 8),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
              if (touchResponse == null || touchResponse.lineBarSpots == null)
                return;

              // ⏱️ THROTTLE DE RENDIMENT PER A JAVASCRIPT/CHROME
              final int currentTimestamp =
                  DateTime.now().millisecondsSinceEpoch;
              if (currentTimestamp - _lastUpdateTimestamp < 30) return;
              _lastUpdateTimestamp = currentTimestamp;

              final spots = touchResponse.lineBarSpots!;
              if (spots.isNotEmpty) {
                // L'índex X ja és directament l'índex real de la llista de 50.000 punts
                final int realPointsIndex = spots.first.x.toInt();

                if (realPointsIndex >= 0 &&
                    realPointsIndex < _validPoints.length) {
                  if (_lastSentIndex == realPointsIndex) return;
                  _lastSentIndex = realPointsIndex;

                  // Sincronització instantània i directa amb MapLibre
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
              maxContentWidth: 150,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final int index = touchedSpot.x.toInt();

                  // Per evitar desbordaments, busquem el valor de distància més proper indexat
                  if (_distances.isEmpty) return null;

                  // Busquem una aproximació ràpida de la distància acumulada
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
                  final String altitudeString =
                      "${touchedSpot.y.toStringAsFixed(0)}m";

                  return LineTooltipItem(
                    "$distanceString\n$altitudeString",
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  );
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
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
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
          maxX: (_validPoints.length - 1)
              .toDouble(), // 🚀 RETORNAT: El mateix rang exacte de coordenades de la llista original
          minY: _minAlt,
          maxY: _maxAlt,
          lineBarsData: [
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
          ],
        ),
      ),
    );
  }
}
