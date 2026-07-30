import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/providers/gpx_editor_state.dart';

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
  List<FlSpot> _speedSpots = [];
  List<double> _distances = [];
  List<double> _filteredAltitudes = [];
  double _minAlt = 0.0;
  double _maxAlt = 0.0;
  int _lastUpdateTimestamp = 0;

  static const double minSpeedTarget = 0.0;
  static const double maxSpeedTarget = 40.0;

  int _draggingHandle = -1;
  bool _hideBlueNeedle =
      false; // 🌟 LA BANDERA CONTROLADORA EXCLUSIVA PER A WEB

  @override
  void initState() {
    super.initState();
    _precomputeChartData();
  }

  @override
  void didUpdateWidget(covariant ElevationChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id ||
        oldWidget.track.points.length != widget.track.points.length) {
      _precomputeChartData();
    }
  }

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
    final List<double> localFilteredAltitudes = [];
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
        localFilteredAltitudes.add(alt);
        if (alt < minAlt) minAlt = alt;
        if (alt > maxAlt) maxAlt = alt;
      }
    }

    final double finalMinAlt = (minAlt - 12.0).clamp(0, double.infinity);
    final double finalMaxAlt = maxAlt;

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
      _filteredAltitudes = localFilteredAltitudes;
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
              style: const TextStyle(
                color: Colors.white,
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

  double? _getRealSpeedKmh(int? index) {
    if (index == null ||
        index < 0 ||
        index >= _validPoints.length ||
        index == 0) {
      return 0.0;
    }
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

    final bool isRangeModeActive =
        activeTool == 'range_map' || activeTool == 'range_chart';
    final int? startPointsIndex = start;

    final int? endPointsIndex = (end == null || end == -1)
        ? ((snappedIdx != null && startPointsIndex != null)
              ? snappedIdx
              : start)
        : end;

    final double maxDistance = _distances.isNotEmpty ? _distances.last : 0.0;

    return SafeArea(
      top: false,
      bottom: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double paddingLeft = 12.0;
          const double paddingRight = 24.0;

          final double chartWidth =
              constraints.maxWidth - paddingLeft - paddingRight;
          final double currentChartHeight = constraints.maxHeight;

          double dxToMeters(double dx) {
            final double adjustedDx = (dx - paddingLeft).clamp(0.0, chartWidth);
            if (chartWidth <= 0 || maxDistance <= 0) return 0.0;
            return (adjustedDx / chartWidth) * maxDistance;
          }

          double mapX(double meters) {
            if (maxDistance <= 0) return 0.0;
            return paddingLeft + ((meters / maxDistance) * chartWidth);
          }

          final double? needleX =
              (snappedIdx != null &&
                  snappedIdx >= 0 &&
                  snappedIdx < _distances.length)
              ? _distances[snappedIdx]
              : null;

          final double? startXForPainters =
              (startPointsIndex != null && startPointsIndex < _distances.length)
              ? _distances[startPointsIndex]
              : null;

          final double? endXForPainters =
              (endPointsIndex != null && endPointsIndex < _distances.length)
              ? _distances[endPointsIndex]
              : null;

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
            height: currentChartHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (showRangeArea &&
                    startPointsIndex != null &&
                    endPointsIndex != null)
                  CustomPaint(
                    painter: RangeAreaPainter(
                      startX: startXRealPixel,
                      endX: endXRealPixel,
                      chartHeight: currentChartHeight,
                      maxDistance: maxDistance,
                      spots: _spots,
                      minY: _minAlt,
                      maxY: _maxAlt,
                      startIdx: _spots.indexWhere(
                        (spot) => spot.x >= _distances[startPointsIndex],
                      ),
                      endIdx: _spots.indexWhere(
                        (spot) => spot.x >= _distances[endPointsIndex],
                      ),
                    ),
                  ),

                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: paddingLeft,
                      right: paddingRight,
                      top: 0,
                      bottom: 22,
                    ),
                    child: IgnorePointer(
                      ignoring: true,
                      child: LineChart(
                        LineChartData(
                          lineTouchData: const LineTouchData(enabled: false),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: maxDistance,
                          minY: _minAlt,
                          maxY: _maxAlt,
                          clipData: const FlClipData.all(),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
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
                  ),
                ),
                // 3. CAPA DE LÍNIES VERTICALS AMB REGLA D'EXCLUSIÓ PER CONTROL DE BANDERA
                CustomPaint(
                  painter: SelectionPainter(
                    needleX: _hideBlueNeedle ? null : graphX,
                    snappedIdx: _hideBlueNeedle ? null : snappedIdx,
                    startX: startXRealPixel,
                    endX: endXRealPixel,
                    startPointsIndex: startPointsIndex,
                    endPointsIndex: endPointsIndex,
                    chartHeight: currentChartHeight,
                    maxDistance: maxDistance,
                    altitudes: _filteredAltitudes.isNotEmpty
                        ? _filteredAltitudes
                        : _spots.map((s) => s.y).toList(),
                    minY: _minAlt,
                    maxY: _maxAlt,

                    // 🌟 EL CANVI EXCLUSIU EN AQUEST ARXIU: Envia la mida de la llista original per activar la ràtio
                    totalTrackPoints: _validPoints.length,
                  ),
                ),

                // 4. MÀQUINA DE GESTOS INTERACTIVA AMB DRAG REPARAT I CONTROL DE BANDERA EXCLUSIU WEB
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanDown: (details) {
                    final double x = details.localPosition.dx;

                    final bool touchedStart =
                        startXRealPixel != null &&
                        (x - startXRealPixel).abs() < 24;
                    final bool touchedEnd =
                        endXRealPixel != null && (x - endXRealPixel).abs() < 24;
                    final bool touchedBlueNeedle =
                        graphX != null && (x - graphX).abs() < 24;

                    if (isRangeModeActive && touchedStart) {
                      setState(() => _draggingHandle = 1);
                    } else if (isRangeModeActive && touchedEnd) {
                      setState(() => _draggingHandle = 2);
                    } else {
                      // 🌟 DRAG NET EN ZONE BUDA: Si l'usuari fa drag i NO toca la verda ni la vermella,
                      // tornem a alliberar l'agulla blava a la Web i s'activa el seu arrossegament
                      setState(() {
                        _draggingHandle = 3;
                        _hideBlueNeedle = false;
                      });

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

                    if (_draggingHandle == 1) {
                      if (now - _lastUpdateTimestamp < 20) return;
                      _lastUpdateTimestamp = now;
                      if (endPointsIndex != null && idx >= endPointsIndex)
                        return;
                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateIndividualRangeHandle(newStartIdx: idx);
                    } else if (_draggingHandle == 2) {
                      if (now - _lastUpdateTimestamp < 20) return;
                      _lastUpdateTimestamp = now;
                      if (startPointsIndex != null && idx <= startPointsIndex)
                        return;
                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateIndividualRangeHandle(newEndIdx: idx);
                    }
                    // 🔵 ARROSSEGAMENT CONTÍNU DE L'AGULLA BLAVA ACTIU EN WEB (Handle 3)
                    else if (_draggingHandle == 3) {
                      if (now - _lastUpdateTimestamp < 25) return;
                      _lastUpdateTimestamp = now;

                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateChartNeedle(idx);
                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateSnappedPoint(_validPoints[idx], idx);
                    }
                  },
                  onPanEnd: (DragEndDetails details) {
                    if (_draggingHandle == 1 || _draggingHandle == 2) {
                      final currentState = ref.read(gpxEditorProvider);
                      if (currentState.selectionStartIndex != null &&
                          currentState.selectionEndIndex != null) {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .finalizeChartRangeSelection(
                              currentState.selectionStartIndex!,
                              currentState.selectionEndIndex!,
                            );
                      }
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
                  onLongPressStart: (LongPressStartDetails details) {
                    final double x = details.localPosition.dx;
                    final int idx = _metersToIndex(dxToMeters(x));

                    // 🌟 LONGPRESS: Amaguem l'agulla blava immediatament en obrir rang
                    setState(() {
                      _hideBlueNeedle = true;
                    });

                    ref.read(gpxEditorProvider.notifier).updateChartNeedle(idx);
                    ref
                        .read(gpxEditorProvider.notifier)
                        .updateSnappedPoint(_validPoints[idx], idx);
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
                ),

                // 5. Tooltips de distàncies (Verd, Vermell i Blau) clavats a sota
                if (showRangeArea &&
                    startPointsIndex != null &&
                    endPointsIndex != null) ...[
                  Positioned(
                    bottom: 2,
                    left: 4,
                    child: _buildFlutterTooltip(
                      "${(_distances[startPointsIndex] / 1000.0).toStringAsFixed(2)} km | ${_validPoints[startPointsIndex].elevation?.toStringAsFixed(0)} m",
                      _getRealSpeedKmh(startPointsIndex),
                      Colors.green,
                      showSpeed,
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 4,
                    child: _buildFlutterTooltip(
                      "${(_distances[endPointsIndex] / 1000.0).toStringAsFixed(2)} km | ${_validPoints[endPointsIndex].elevation?.toStringAsFixed(0)} m",
                      _getRealSpeedKmh(endPointsIndex),
                      Colors.red,
                      showSpeed,
                    ),
                  ),
                ],

                if (!_hideBlueNeedle && snappedIdx != null && graphX != null)
                  Positioned(
                    bottom: 2,
                    left: (graphX - 65).clamp(
                      4.0,
                      (chartWidth + paddingLeft + paddingRight) - 130.0,
                    ),
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
    );
  }
}
