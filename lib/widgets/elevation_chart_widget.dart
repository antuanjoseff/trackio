import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:trackio/core/theme/app_colors.dart';
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
  List<FlSpot> _speedSpots = [];
  List<double> _distances = [];
  List<double> _filteredAltitudes = [];
  double _minAlt = 0.0;
  double _maxAlt = 0.0;
  int _lastUpdateTimestamp = 0;

  static const double minSpeedTarget = 0.0;
  static const double maxSpeedTarget = 40.0;

  int _draggingHandle = -1;
  bool _hideBlueNeedle = false;
  final GlobalKey _startTooltipKey = GlobalKey();
  final GlobalKey _endTooltipKey = GlobalKey();

  double _tooltipWidth = 0;

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

    if (_validPoints.isEmpty) {
      setState(() {
        _spots = [];
        _speedSpots = [];
        _distances = [];
        _filteredAltitudes = [];
        _minAlt = 0.0;
        _maxAlt = 0.0;
      });
      return;
    }

    final List<FlSpot> localSpots = [];
    final List<FlSpot> localSpeedSpots = [];
    final List<double> localDistances = [];
    final List<double> localFilteredAltitudes = [];
    double totalDistanceMeters = 0.0;
    double minAlt = double.infinity;
    double maxAlt = -double.infinity;

    const geo.Distance distanceCalculator = geo.Distance();
    final int len = _validPoints.length;

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

      localSpots.add(FlSpot(totalDistanceMeters, alt));
      localFilteredAltitudes.add(alt);
      if (alt < minAlt) minAlt = alt;
      if (alt > maxAlt) maxAlt = alt;
    }

    final double finalMinAlt = (minAlt - 12.0).clamp(0, double.infinity);
    final double finalMaxAlt = maxAlt;

    for (int i = 0; i < len; i++) {
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

    // Búsqueda binària per trobar l'índex real més proper en distància.
    int low = 0;
    int high = _distances.length - 1;

    while (low < high) {
      final int mid = (low + high) >> 1;
      if (_distances[mid] < meters) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    final int right = low;
    final int left = right > 0 ? right - 1 : 0;
    final double leftDiff = (_distances[left] - meters).abs();
    final double rightDiff = (_distances[right] - meters).abs();

    return (rightDiff < leftDiff ? right : left).clamp(
      0,
      _distances.length - 1,
    );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTooltipSize();
    });
    if (_validPoints.isEmpty) {
      return Center(
        child: Text(
          t.trackWithoutElevationData,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final start = ref.watch(
      gpxEditorProvider.select((s) => s.selectionStartIndex),
    );
    final end = ref.watch(gpxEditorProvider.select((s) => s.selectionEndIndex));
    // 🌟 SUBSTITEIX LA TEVA LÍNIA ACTUAL PER AQUESTA:
    final snappedIdx = ref.watch(
      gpxEditorProvider.select(
        (s) => s.chartNeedleIndex ?? s.snappedPointIndex,
      ),
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

          final double tooltipWidth = _tooltipWidth > 0 ? _tooltipWidth : 130.0;

          final double tooltipMinLeft = 4.0;
          final double tooltipMaxLeft =
              (chartWidth + paddingLeft + paddingRight) - tooltipWidth;

          double? startTooltipLeft;
          double? endTooltipLeft;

          if (startXRealPixel != null && endXRealPixel != null) {
            final bool startIsLeft = startXRealPixel <= endXRealPixel;

            final double xLeft = startIsLeft ? startXRealPixel : endXRealPixel;

            final double xRight = startIsLeft ? endXRealPixel : startXRealPixel;

            final double distance = xRight - xLeft;

            double leftBox;
            double rightBox;

            // ==========================================================
            // ESTADO 1:
            // Separadas -> siempre centradas en la aguja
            // ==========================================================
            if (distance >= tooltipWidth) {
              leftBox = xLeft - tooltipWidth / 2;
              rightBox = xRight - tooltipWidth / 2;
            }
            // ==========================================================
            // ESTADO 2:
            // Colisión real -> anclaje rígido
            // ==========================================================
            else {
              final double midPoint = (xLeft + xRight) / 2;

              leftBox = midPoint - tooltipWidth;
              rightBox = midPoint;
            }

            // Clamp final
            leftBox = leftBox.clamp(tooltipMinLeft, tooltipMaxLeft);

            rightBox = rightBox.clamp(tooltipMinLeft, tooltipMaxLeft);

            startTooltipLeft = startIsLeft ? leftBox : rightBox;

            endTooltipLeft = startIsLeft ? rightBox : leftBox;
          }

          final bool showRangeArea =
              isRangeModeActive && startPointsIndex != null;

          return SizedBox(
            height: currentChartHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ==========================================================
                // 1. SUPERFÍCIE DEL TRAM SELECCIONAT
                // ==========================================================
                if (showRangeArea && endPointsIndex != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RangeAreaPainter(
                        startX: startXRealPixel,
                        endX: endXRealPixel,
                        chartHeight: currentChartHeight,
                        maxDistance: maxDistance,
                        spots: _spots,
                        minY: _minAlt,
                        maxY: _maxAlt,
                        startIdx: startPointsIndex,
                        endIdx: endPointsIndex,
                      ),
                    ),
                  ),

                // ==========================================================
                // 2. GRÀFIC D'ELEVACIÓ
                // ==========================================================
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
                              color: AppColors.starTrekRed,
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                            ),

                            if (showSpeed && _speedSpots.isNotEmpty)
                              LineChartBarData(
                                spots: _speedSpots,
                                isCurved: true,
                                curveSmoothness: 0.4,
                                preventCurveOverShooting: true,
                                color: AppColors.starTrekGold.withValues(
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

                // ==========================================================
                // 3. LÍNIES VERTICALS / AGULLES
                // ==========================================================
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
                    totalTrackPoints: _validPoints.length,
                  ),
                ),

                // ==========================================================
                // 4. GESTOS
                // ==========================================================
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
                      setState(() {
                        _draggingHandle = 1;
                      });
                      return;
                    }

                    if (isRangeModeActive && touchedEnd) {
                      setState(() {
                        _draggingHandle = 2;
                      });
                      return;
                    }

                    if (touchedBlueNeedle) {
                      setState(() {
                        _hideBlueNeedle = false;
                        _draggingHandle = 3;
                      });
                      return;
                    }

                    final meters = dxToMeters(x);
                    final idx = _metersToIndex(meters);

                    setState(() {
                      _hideBlueNeedle = false;
                      _draggingHandle = 3;
                    });

                    ref.read(gpxEditorProvider.notifier).clearChartSelection();

                    ref.read(gpxEditorProvider.notifier).updateChartNeedle(idx);

                    ref
                        .read(gpxEditorProvider.notifier)
                        .updateSnappedPoint(_validPoints[idx], idx);
                  },

                  onPanUpdate: (details) {
                    if (_draggingHandle == -1) return;

                    final double x = details.localPosition.dx;
                    final int idx = _metersToIndex(dxToMeters(x));

                    final int now = DateTime.now().millisecondsSinceEpoch;

                    if (_draggingHandle == 1) {
                      if (now - _lastUpdateTimestamp < 20) return;

                      _lastUpdateTimestamp = now;

                      if (endPointsIndex != null && idx > endPointsIndex) {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateIndividualRangeHandle(
                              newStartIdx: endPointsIndex,
                              newEndIdx: idx,
                            );

                        setState(() {
                          _draggingHandle = 2;
                        });

                        return;
                      }

                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateIndividualRangeHandle(newStartIdx: idx);
                    } else if (_draggingHandle == 2) {
                      if (now - _lastUpdateTimestamp < 20) return;

                      _lastUpdateTimestamp = now;

                      if (startPointsIndex != null && idx < startPointsIndex) {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateIndividualRangeHandle(
                              newStartIdx: idx,
                              newEndIdx: startPointsIndex,
                            );

                        setState(() {
                          _draggingHandle = 1;
                        });

                        return;
                      }

                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateIndividualRangeHandle(newEndIdx: idx);
                    } else if (_draggingHandle == 3) {
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

                  onPanEnd: (_) {
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

                  onLongPressStart: (details) {
                    final idx = _metersToIndex(
                      dxToMeters(details.localPosition.dx),
                    );

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
                    final idx = _metersToIndex(
                      dxToMeters(details.localPosition.dx),
                    );

                    ref
                        .read(gpxEditorProvider.notifier)
                        .updateIndividualRangeHandle(newEndIdx: idx);
                  },

                  onLongPressEnd: (_) {
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
                  },
                ),

                // ==========================================================
                // 5. TOOLTIPS
                // ==========================================================
                if (showRangeArea &&
                    endPointsIndex != null &&
                    startTooltipLeft != null &&
                    endTooltipLeft != null)
                  Stack(
                    children: [
                      Positioned(
                        bottom: 2,
                        left: startTooltipLeft,
                        child: Container(
                          key: _startTooltipKey,
                          child: _buildFlutterTooltip(
                            "${(_distances[startPointsIndex] / 1000).toStringAsFixed(2)} km | ${_validPoints[startPointsIndex].elevation?.toStringAsFixed(0)} m",
                            _getRealSpeedKmh(startPointsIndex),
                            AppColors.starTrekGold,
                            showSpeed,
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 2,
                        left: endTooltipLeft,
                        child: Container(
                          key: _endTooltipKey,
                          child: _buildFlutterTooltip(
                            "${(_distances[endPointsIndex] / 1000).toStringAsFixed(2)} km | ${_validPoints[endPointsIndex].elevation?.toStringAsFixed(0)} m",
                            _getRealSpeedKmh(endPointsIndex),
                            AppColors.starTrekRed,
                            showSpeed,
                          ),
                        ),
                      ),
                    ],
                  ),

                // Tooltip agulla blava
                if (!_hideBlueNeedle && snappedIdx != null && graphX != null)
                  Positioned(
                    bottom: 2,
                    left: (graphX - 65).clamp(
                      4.0,
                      (chartWidth + paddingLeft + paddingRight) - 130,
                    ),

                    child: _buildFlutterTooltip(
                      "${(_distances[snappedIdx] / 1000).toStringAsFixed(2)} km | ${_validPoints[snappedIdx].elevation?.toStringAsFixed(0)} m",
                      _getRealSpeedKmh(snappedIdx),
                      AppColors.starTrekGold,
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

  void _updateTooltipSize() {
    final RenderBox? box =
        _startTooltipKey.currentContext?.findRenderObject() as RenderBox?;

    if (box != null && box.size.width != _tooltipWidth) {
      setState(() {
        _tooltipWidth = box.size.width;
      });
    }
  }
}
