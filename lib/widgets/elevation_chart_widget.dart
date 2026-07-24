import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';

import 'package:trackio/screens/painters/selection_painter.dart';
import 'package:trackio/screens/painters/range_area_painter.dart';

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
  List<FlSpot> _speedSpots = []; // 🌟 Precalculat en memòria local
  List<double> _distances = [];
  double _minAlt = 0.0;
  double _maxAlt = 0.0;
  int _lastUpdateTimestamp = 0;

  // Constants fixes globals per a l'escala de la velocitat
  static const double minSpeedTarget = 0.0;
  static const double maxSpeedTarget = 40.0;

  // Controlador de captures físiques del GestureDetector
  // -1 = cap, 1 = agulla verda, 2 = agulla vermella, 3 = dit blau mòbil
  int _draggingHandle = -1;

  @override
  void initState() {
    super.initState();
    _precomputeChartData();
  }

  @override
  void didUpdateWidget(covariant ElevationChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) {
      _precomputeChartData();
    }
  }

  // 📐 ESCALA MATEMÀTICA: Ajusta proporcionalment la velocitat [0-40] al rang [minAlt-maxAlt] de la ruta
  double _scaleSpeedToAlt(double speed, double minAlt, double maxAlt) {
    final double altRange = maxAlt - minAlt;
    if (altRange <= 0) return minAlt;
    return minAlt +
        ((speed - minSpeedTarget) / (maxSpeedTarget - minSpeedTarget)) *
            altRange;
  }

  void _precomputeChartData() {
    _validPoints = widget.track.points
        .where(
          (p) =>
              p.elevation != null && p.latitude != null && p.longitude != null,
        )
        .toList();

    if (_validPoints.isEmpty) return;

    final List<FlSpot> localSpots = [];
    final List<FlSpot> localSpeedSpots = [];
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

    localDistances.add(0.0);

    // 1er Pas: Calcular distàncies de l'eix X i extrems d'altitud de l'eix Y
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

      if (i % step == 0 || i == len - 1) {
        localSpots.add(FlSpot(totalDistanceMeters, alt));
        if (alt < minAlt) minAlt = alt;
        if (alt > maxAlt) maxAlt = alt;
      }
    }

    final double finalMinAlt = (minAlt - 20).clamp(0, double.infinity);
    final double finalMaxAlt = maxAlt + 20;

    // 2on Pas: Precàlcul de velocitats estables basat en temps real evitant lag al Build
    for (int i = 0; i < len; i++) {
      if (i % step != 0 && i != len - 1) continue;

      double speedKmh = 0.0;
      if (i > 0) {
        final pPrev = _validPoints[i - 1];
        final pCurr = _validPoints[i];

        if (pPrev.timestamp != null && pCurr.timestamp != null) {
          final seconds = pCurr.timestamp!
              .difference(pPrev.timestamp!)
              .inSeconds;
          if (seconds > 0) {
            final double meters = localDistances[i] - localDistances[i - 1];
            speedKmh = (meters / 1000) / (seconds / 3600);
          }
        }
      }

      final double currentMeters = localDistances[i];
      localSpeedSpots.add(
        FlSpot(
          currentMeters,
          _scaleSpeedToAlt(
            speedKmh.clamp(minSpeedTarget, maxSpeedTarget),
            finalMinAlt,
            finalMaxAlt,
          ),
        ),
      );
    }

    setState(() {
      _spots = localSpots;
      _speedSpots = localSpeedSpots;
      _distances = localDistances;
      _minAlt = finalMinAlt;
      _maxAlt = finalMaxAlt;
    });
  }

  int _metersToIndex(double meters) {
    if (_distances.isEmpty) return 0;
    int low = 0;
    int high = _distances.length - 1;

    while (low < high) {
      int mid = (low + high) ~/ 2;
      if (_distances[mid] < meters) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low.clamp(0, _validPoints.length - 1);
  }

  // 🌟 TOOLTIP NATIU INTEL·LIGENT: Afegeix la línia de velocitat en color teula dinàmicament si showSpeed és cert
  Widget _buildFlutterTooltip(
    String mainText,
    double? speedKmh,
    Color baseColor,
    bool showSpeedActive,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            mainText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          if (showSpeedActive && speedKmh != null) ...[
            const SizedBox(height: 2),
            Text(
              "${speedKmh.toStringAsFixed(1)} km/h",
              style: TextStyle(
                color: Colors
                    .teal
                    .shade200, // Color de contrast per a la velocitat
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🧠 FUNCIÓ AUXILIAR PER BUSCAR LA VELOCITAT REAL D'UN NODE DEL TRACK EN KM/H
  double? _getRealSpeedKmh(int? index) {
    if (index == null ||
        index < 0 ||
        index >= _validPoints.length ||
        index == 0)
      return 0.0;
    final pPrev = _validPoints[index - 1];
    final pCurr = _validPoints[index];
    if (pPrev.timestamp == null || pCurr.timestamp == null) return null;

    final seconds = pCurr.timestamp!.difference(pPrev.timestamp!).inSeconds;
    if (seconds <= 0) return 0.0;

    const geo.Distance distanceCalculator = geo.Distance();
    final meters = distanceCalculator.as(
      geo.LengthUnit.Meter,
      geo.LatLng(pPrev.latitude!, pPrev.longitude!),
      geo.LatLng(pCurr.latitude!, pCurr.longitude!),
    );
    return (meters / 1000) / (seconds / 3600);
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

    // Escoltors directes de Riverpod (Font Única de Veritat)
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final start = ref.watch(
      gpxEditorProvider.select((s) => s.selectionStartIndex),
    );
    final end = ref.watch(gpxEditorProvider.select((s) => s.selectionEndIndex));
    final snappedIdx = ref.watch(
      gpxEditorProvider.select((s) => s.snappedPointIndex),
    );
    final showSpeed = ref.watch(
      gpxEditorProvider.select((s) => s.showSpeedInChart),
    );

    final bool isRangeModeActive = activeTool == 'range_map';

    // 🔒 REPARACIÓ CRÍTICA: Pipelining directe eliminant el bloqueig de nuls del if antic.
    // Així garantim que qualsevol moviment del drag viatgi a l'acte a l'eix X del pintor.
    final int? startPointsIndex = start;
    final int? endPointsIndex = (end == null || end == -1) ? start : end;

    final double maxDistance = _distances.isNotEmpty ? _distances.last : 0.0;
    const double chartHeight = 140.0;

    // 🌟 PROTECCIÓ GEOMÈTRICA: El SafeArea i el Padding encapsulen el gràfic per complet,
    // elevant el giny fora dels botons del SO i forçant que les coordenades de píxels siguin 100% exactes.
    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 0, right: 24, left: 12, bottom: 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double chartWidth = constraints.maxWidth;

            double dxToMeters(double dx) {
              if (chartWidth <= 0 || maxDistance <= 0) return 0.0;
              return (dx.clamp(0.0, chartWidth) / chartWidth) * maxDistance;
            }

            double mapX(double meters) {
              if (maxDistance <= 0) return 0.0;
              return (meters / maxDistance) * chartWidth;
            }

            // Resolució de distàncies mètriques del track
            final double? needleX =
                (snappedIdx != null &&
                    snappedIdx >= 0 &&
                    snappedIdx < _distances.length)
                ? _distances[snappedIdx]
                : null;

            final double? startXForPainters =
                (startPointsIndex != null &&
                    startPointsIndex < _distances.length)
                ? _distances[startPointsIndex]
                : null;

            final double? endXForPainters =
                (endPointsIndex != null && endPointsIndex < _distances.length)
                ? _distances[endPointsIndex]
                : null;

            // Càlcul de píxels de pantalla per a les zones de captura del detector de gestos (handles de 30px)
            final double? graphX = needleX != null ? mapX(needleX) : null;
            final double? startXRealPixel = startXForPainters != null
                ? mapX(startXForPainters)
                : null;
            final double? endXRealPixel = endXForPainters != null
                ? mapX(endXForPainters)
                : null;

            final bool showRangeArea =
                isRangeModeActive && startPointsIndex != null;

            return SizedBox(
              height: chartHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Capa de fons taronja de la zona seleccionada
                  CustomPaint(
                    painter: RangeAreaPainter(
                      startX: startXForPainters,
                      endX: endXForPainters,
                      chartHeight: chartHeight,
                      maxDistance: maxDistance,
                    ),
                  ),

                  // 2. Capa de la gràfica de fl_chart (🔒 Moguda aquí a sota perquè no tapi les agulles)
                  IgnorePointer(
                    ignoring: true,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: const LineTouchData(enabled: false),
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: maxDistance,
                        minY: _minAlt,
                        maxY: _maxAlt,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _spots,
                            isCurved: true,
                            curveSmoothness: 0.4,
                            preventCurveOverShooting: true,
                            color: trackColor,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                          ),
                          if (showSpeed && _speedSpots.isNotEmpty)
                            LineChartBarData(
                              spots: _speedSpots,
                              isCurved: true,
                              curveSmoothness: 0.4,
                              preventCurveOverShooting: true,
                              color: Colors.teal.shade500.withValues(
                                alpha: 0.6,
                              ),
                              barWidth: 1.3,
                              dotData: const FlDotData(show: false),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Capa de línies verticals
                  // 3. Capa de línies verticals (SelectionPainter)
                  CustomPaint(
                    painter: SelectionPainter(
                      // REPARACIÓ EXCLUSIVITAT: Si l'eina és range_map, el blau es força a null.
                      // Si no és range_map, les coordenades del verd i vermell es forcen a null.
                      needleX: activeTool == 'range_map' ? null : graphX,
                      startX: activeTool == 'range_map'
                          ? startXRealPixel
                          : null,
                      endX: activeTool == 'range_map' ? endXRealPixel : null,
                      chartHeight: chartHeight,
                      maxDistance: maxDistance,
                      snappedIdx: activeTool == 'range_map' ? null : snappedIdx,

                      // Escoltem directament els nous índexs paral·lels que gestiona el Notifier
                      startPointsIndex: activeTool == 'range_map'
                          ? ref.watch(
                              gpxEditorProvider.select(
                                (s) => s.chartRangeStartIndex,
                              ),
                            )
                          : null,
                      endPointsIndex: activeTool == 'range_map'
                          ? ref.watch(
                              gpxEditorProvider.select(
                                (s) => s.chartRangeEndIndex,
                              ),
                            )
                          : null,
                      altitudes: _validPoints
                          .map((p) => p.elevation ?? 0.0)
                          .toList(),
                      minY: _minAlt,
                      maxY: _maxAlt,
                    ),
                  ),

                  // 4. MÀQUINA DE GESTOS COMPLETA PER ZONES DE CAPTURA...
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanDown: (details) {
                      final double x = details.localPosition.dx;

                      final bool touchedStart =
                          startXRealPixel != null &&
                          (x - startXRealPixel).abs() < 30;
                      final bool touchedEnd =
                          endXRealPixel != null &&
                          (x - endXRealPixel).abs() < 30;

                      if (isRangeModeActive && (touchedStart || touchedEnd)) {
                        // 🔒 REPARACIÓ D'EXCLUSIVITAT: Si l'usuari agafa l'agulla verda o la vermella,
                        // liquidem immediatament qualsevol rastre, agulla, tooltip o cercle blau del mapa.
                        ref.read(gpxEditorProvider.notifier).clearChartNeedle();
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateSnappedPoint(null, null);

                        setState(() {
                          _draggingHandle = touchedStart ? 1 : 2;
                        });
                      } else {
                        // Clic lliure a la gràfica: Neteja rang (verd/vermell) i activa l'agulla blava mòbil
                        setState(() {
                          _draggingHandle = 3;
                        });
                        ref
                            .read(gpxEditorProvider.notifier)
                            .clearChartSelection();

                        final meters = dxToMeters(x);
                        final idx = _metersToIndex(meters);
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateChartNeedle(idx);
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateSnappedPoint(_validPoints[idx], idx);
                      }
                    },
                    onPanUpdate: (details) {
                      if (_draggingHandle == -1) return;

                      final double x = details.localPosition.dx;
                      final int idx = _metersToIndex(dxToMeters(x));

                      final int now = DateTime.now().millisecondsSinceEpoch;
                      if (now - _lastUpdateTimestamp < 20)
                        return; // Alta taxa de refresc fluid a 60fps
                      _lastUpdateTimestamp = now;

                      if (_draggingHandle == 1) {
                        // 🧠 REPARACIÓ DRAG INDIVIDUAL: Moure l'agulla verda d'inici
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateIndividualRangeHandle(newStartIdx: idx);
                      } else if (_draggingHandle == 2) {
                        // 🧠 REPARACIÓ DRAG INDIVIDUAL: Moure l'agulla vermella de final
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateIndividualRangeHandle(newEndIdx: idx);
                      } else if (_draggingHandle == 3) {
                        // Moure l'agulla blava mòbil del dit lliure
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateChartNeedle(idx);
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateSnappedPoint(_validPoints[idx], idx);
                      }
                    },
                    onPanEnd: (_) {
                      if (_draggingHandle == 3) {
                        ref.read(gpxEditorProvider.notifier).clearChartNeedle();
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateSnappedPoint(null, null);
                      } else if ((_draggingHandle == 1 ||
                              _draggingHandle == 2) &&
                          start != null &&
                          end != null) {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .finalizeChartRangeSelection(start, end);
                      }
                      setState(() {
                        _draggingHandle = -1;
                      });
                    },
                    onPanCancel: () {
                      setState(() {
                        _draggingHandle = -1;
                      });
                    },
                    onLongPressStart: (_) {
                      // 🔒 REPARACIÓ D'EXCLUSIVITAT: En el moment exacte que es prem de forma sostinguda,
                      // esborrem fulminantment l'agulla blava, el tooltip blau i el cercle blau del mapa.
                      ref.read(gpxEditorProvider.notifier).clearChartNeedle();
                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateSnappedPoint(null, null);

                      // Després d'assegurar la neteja, inicialitzem el ventall verd i vermell (25% - 75%)
                      ref
                          .read(gpxEditorProvider.notifier)
                          .startChartRangeSelectionWithPercent();
                    },
                    onLongPressMoveUpdate: (details) {
                      final double x = details.localPosition.dx;
                      final int idx = _metersToIndex(dxToMeters(x));

                      final int now = DateTime.now().millisecondsSinceEpoch;
                      if (now - _lastUpdateTimestamp < 25) return;
                      _lastUpdateTimestamp = now;

                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateIndividualRangeHandle(newEndIdx: idx);
                    },
                    onLongPressEnd: (_) {
                      final s = ref.read(gpxEditorProvider);
                      if (s.selectionStartIndex != null &&
                          s.selectionEndIndex != null) {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .finalizeChartRangeSelection(
                              s.selectionStartIndex!,
                              s.selectionEndIndex!,
                            );
                      }
                    },
                  ),

                  // 5. TOOLTIPS FIXATS A LES CANTONADES SUPERIORS (Mode Rang Actiu)
                  if (showRangeArea &&
                      startPointsIndex != null &&
                      endPointsIndex != null) ...[
                    Positioned(
                      top: -22,
                      left: 4,
                      child: _buildFlutterTooltip(
                        "${(_distances[startPointsIndex] / 1000.0).toStringAsFixed(2)} km | ${_validPoints[startPointsIndex].elevation?.toStringAsFixed(0)} m",
                        _getRealSpeedKmh(startPointsIndex),
                        Colors.green,
                        showSpeed,
                      ),
                    ),
                    Positioned(
                      top: -22,
                      right: 4,
                      child: _buildFlutterTooltip(
                        "${(_distances[endPointsIndex] / 1000.0).toStringAsFixed(2)} km | ${_validPoints[endPointsIndex].elevation?.toStringAsFixed(0)} m",
                        _getRealSpeedKmh(endPointsIndex),
                        Colors.red,
                        showSpeed,
                      ),
                    ),
                  ],

                  // 6. TOOLTIP BLAU MÒBIL DEL DIT AMB CLAMPING HORITZONTAL ANTI-RETALLS
                  if (!showRangeArea && snappedIdx != null && graphX != null)
                    Positioned(
                      top: -22,
                      left: (graphX - 65).clamp(4.0, chartWidth - 130.0),
                      child: _buildFlutterTooltip(
                        "${(_distances[snappedIdx] / 1000.0).toStringAsFixed(2)} km | ${_validPoints[snappedIdx].elevation?.toStringAsFixed(0)} m",
                        _getRealSpeedKmh(snappedIdx),
                        Colors.blue,
                        showSpeed,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
