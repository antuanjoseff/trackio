import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:trackio/models/track_model.dart';

class ElevationChartWidget extends StatelessWidget {
  final TrackModel track;

  // ⏱️ VARIABLE DE CONTROL PERSISTENTE: Guarda la marca de agua temporal en la memoria RAM
  // para aplicar el Throttle entre redibujados sin perder el estado del temporizador.
  static int _lastUpdateTimestamp = 0;

  const ElevationChartWidget({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final validPoints = track.points
        .where(
          (p) =>
              p.elevation != null && p.latitude != null && p.longitude != null,
        )
        .toList();

    if (validPoints.isEmpty) {
      return const Center(
        child: Text(
          "Aquest track no conté dades d'altitud",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final List<FlSpot> spots = [];
    final List<double> distances = [];

    double totalDistanceMeters = 0.0;
    double minAlt = double.infinity;
    double maxAlt = -double.infinity;

    final geo.Distance distanceCalculator = const geo.Distance();

    for (int i = 0; i < validPoints.length; i++) {
      final double alt = validPoints[i].elevation!;

      if (i > 0) {
        final double segment = distanceCalculator.as(
          geo.LengthUnit.Meter,
          geo.LatLng(
            validPoints[i - 1].latitude!,
            validPoints[i - 1].longitude!,
          ),
          geo.LatLng(validPoints[i].latitude!, validPoints[i].longitude!),
        );
        totalDistanceMeters += segment;
      }

      distances.add(totalDistanceMeters);
      spots.add(FlSpot(i.toDouble(), alt));

      if (alt < minAlt) minAlt = alt;
      if (alt > maxAlt) maxAlt = alt;
    }

    minAlt = (minAlt - 20).clamp(0, double.infinity);
    maxAlt = maxAlt + 20;

    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 24, left: 12, bottom: 8),
      child: LineChart(
        LineChartData(
          // 🛠️ CONFIGURACIÓN DEL INTERACTIVO CON THROTTLE DE ALTA VELOCIDAD
          lineTouchData: LineTouchData(
            // El callback se ejecuta cada vez que el usuario desliza el cursor por encima del gráfico
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
              // 1. Si no hay interacción real, cancelamos la evaluación
              if (touchResponse == null || touchResponse.lineBarSpots == null)
                return;

              // 2. FILTRO THROTTLE: Evaluamos si han pasado menos de 30 milisegundos desde el último evento
              final int currentTimestamp =
                  DateTime.now().millisecondsSinceEpoch;
              if (currentTimestamp - _lastUpdateTimestamp < 30) {
                // Descartamos pacíficamente la petición masiva para no ahogar los hilos de Chrome
                return;
              }

              // 3. Si pasa el filtro, actualizamos la marca de tiempo con el milisegundo actual
              _lastUpdateTimestamp = currentTimestamp;

              // 4. Capturamos el punto exacto donde se encuentra el cursor del usuario
              final spots = touchResponse.lineBarSpots!;
              if (spots.isNotEmpty) {
                final int pointIndex = spots.first.x.toInt();
                if (pointIndex >= 0 && pointIndex < validPoints.length) {
                  final targetPoint = validPoints[pointIndex];

                  // Traza de depuración en consola para ver la optimización del corte de tasa de refresco
                  debugPrint(
                    "⏱️ [THROTTLE] Enviando actualización al mapa: Punto #$pointIndex - Lat: ${targetPoint.latitude}",
                  );

                  // Aquí conectaremos en el siguiente paso el envío de coordenadas al mapa de MapLibre
                }
              }
            },
            touchTooltipData: LineTouchTooltipData(
              maxContentWidth: 150,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final int index = touchedSpot.x.toInt();
                  if (index >= distances.length) return null;

                  final double metersAccumulated = distances[index];
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
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
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
                reservedSize: 40,
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
          maxX: (validPoints.length - 1).toDouble(),
          minY: minAlt,
          maxY: maxAlt,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Color(int.parse(track.hexColor.replaceAll('#', '0xFF'))),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Color(
                  int.parse(track.hexColor.replaceAll('#', '0xFF')),
                ).withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
