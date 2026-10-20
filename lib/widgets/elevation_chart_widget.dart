import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';

import 'package:trackio/screens/painters/range_area_painter.dart';

class _HandleMarkerPainter extends CustomPainter {
  const _HandleMarkerPainter({
    required this.color,
    required this.markerY,
    required this.chartHeight,
    required this.lineWidth,
    required this.circleRadius,
  });

  final Color color;
  final double markerY;
  final double chartHeight;
  final double lineWidth;
  final double circleRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final lineX = size.width / 2;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // La línia només ocupa la zona del perfil, sense entrar a les franges dels tooltips
    canvas.drawLine(
      Offset(lineX, _kTopBand),
      Offset(lineX, chartHeight - _kBottomBand),
      linePaint,
    );

    final circlePaint = Paint()..color = color;
    final circleBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final circleCenter = Offset(lineX, markerY);
    canvas.drawCircle(circleCenter, circleRadius, circlePaint);
    canvas.drawCircle(circleCenter, circleRadius, circleBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _HandleMarkerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.markerY != markerY ||
        oldDelegate.chartHeight != chartHeight ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.circleRadius != circleRadius;
  }
}

const Color _kSpeedNavy = Color(0xFF0B3D91);

// Franges reservades ddalt (distància/altitud) i baix (velocitat) del gràfic
const double _kTopBand = 24.0;
const double _kBottomBand = 24.0;

class ElevationChartWidget extends ConsumerStatefulWidget {
  final TrackModel track;

  const ElevationChartWidget({super.key, required this.track});

  @override
  ConsumerState<ElevationChartWidget> createState() =>
      _ElevationChartWidgetState();
}

class _ElevationChartWidgetState extends ConsumerState<ElevationChartWidget> {
  List<TrackPointModel> _validPoints = [];
  List<int> _validPointTrackIndices = [];
  Map<int, int> _trackToChartIndex = {};
  List<FlSpot> _spots = [];
  List<FlSpot> _speedSpots = [];
  List<double> _distances = [];
  List<double> _filteredAltitudes = [];
  double _minAlt = 0.0;
  double _maxAlt = 0.0;

  static const double minSpeedTarget = 0.0;
  static const double maxSpeedTarget = 40.0;

  int _draggingHandle = -1;
  bool _hideBlueNeedle = false;
  int _ignorePanDownUntilMs = 0;
  double? _lastRangeActivationDx;
  int? _displayStartTrackIdx;
  int? _displayEndTrackIdx;
  int? _displayNeedleTrackIdx;
  double? _displayStartX;
  double? _displayEndX;
  double? _displayNeedleX;
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
        oldWidget.track.points.length != widget.track.points.length ||
        oldWidget.track.points != widget.track.points) {
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
    final List<TrackPointModel> validPoints = [];
    final List<int> validTrackIndices = [];

    for (int i = 0; i < widget.track.points.length; i++) {
      final p = widget.track.points[i];
      if (p.elevation != null && p.latitude != null && p.longitude != null) {
        validPoints.add(p);
        validTrackIndices.add(i);
      }
    }

    _validPoints = validPoints;
    _validPointTrackIndices = validTrackIndices;
    _trackToChartIndex = {
      for (int i = 0; i < _validPointTrackIndices.length; i++)
        _validPointTrackIndices[i]: i,
    };

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

    final double altHalfWindow = (totalDistanceMeters / 400).clamp(8.0, 120.0);
    final List<double> smoothAlt = _smoothByDistance(
      localDistances,
      localFilteredAltitudes,
      altHalfWindow,
    );
    for (int i = 0; i < len; i++) {
      localSpots[i] = FlSpot(localSpots[i].x, smoothAlt[i]);
      localFilteredAltitudes[i] = smoothAlt[i];
    }

    final List<double> rawSpeeds = List<double>.filled(len, 0.0);
    for (int i = 0; i < len; i++) {
      double speedKmh = 0.0;
      if (i > 0) {
        final pPrev = _validPoints[i - 1];
        final pCurr = _validPoints[i];

        if (pPrev.timestamp != null && pCurr.timestamp != null) {
          final double seconds =
              pCurr.timestamp!.difference(pPrev.timestamp!).inMilliseconds /
              1000.0;
          // 🌟 REPARACIÓ: Ignorem velocitats si el temps és <= 0 (punts sense diferència temporal)
          if (seconds > 0.1) {
            final double meters = localDistances[i] - localDistances[i - 1];
            speedKmh = (meters / 1000) / (seconds / 3600);
          }
        }
      }

      rawSpeeds[i] = speedKmh.clamp(minSpeedTarget, maxSpeedTarget);
    }

    final double speedHalfWindow = (totalDistanceMeters / 150).clamp(
      20.0,
      300.0,
    );
    final List<double> smoothSpeeds = _smoothByDistance(
      localDistances,
      rawSpeeds,
      speedHalfWindow,
    );
    for (int i = 0; i < len; i++) {
      localSpeedSpots.add(
        FlSpot(
          localDistances[i],
          _scaleSpeedToAlt(smoothSpeeds[i], finalMinAlt, finalMaxAlt),
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

  // Mitjana mòbil per distància: manté el nombre de punts i les posicions X,
  // només suavitza el valor Y que es dibuixa.
  List<double> _smoothByDistance(
    List<double> distances,
    List<double> values,
    double halfWindowMeters,
  ) {
    final int n = values.length;
    if (n < 3 || halfWindowMeters <= 0) return List<double>.from(values);

    final List<double> prefix = List<double>.filled(n + 1, 0.0);
    for (int i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + values[i];
    }

    final List<double> out = List<double>.filled(n, 0.0);
    int lo = 0;
    int hi = 0;
    for (int i = 0; i < n; i++) {
      while (distances[i] - distances[lo] > halfWindowMeters) {
        lo++;
      }
      if (hi < i) hi = i;
      while (hi + 1 < n &&
          distances[hi + 1] - distances[i] <= halfWindowMeters) {
        hi++;
      }
      out[i] = (prefix[hi + 1] - prefix[lo]) / (hi - lo + 1);
    }
    return out;
  }

  int _chartToTrackIndex(int chartIdx) {
    if (_validPointTrackIndices.isEmpty) return 0;
    final safeChartIdx = chartIdx.clamp(0, _validPointTrackIndices.length - 1);
    return _validPointTrackIndices[safeChartIdx];
  }

  int? _trackToNearestChartIndex(int? trackIdx) {
    if (trackIdx == null || _validPointTrackIndices.isEmpty) return null;

    final exact = _trackToChartIndex[trackIdx];
    if (exact != null) return exact;

    int low = 0;
    int high = _validPointTrackIndices.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final value = _validPointTrackIndices[mid];

      if (value == trackIdx) {
        return mid;
      } else if (value < trackIdx) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (low >= _validPointTrackIndices.length) {
      return _validPointTrackIndices.length - 1;
    }
    if (high < 0) {
      return 0;
    }

    final lowDiff = (_validPointTrackIndices[low] - trackIdx).abs();
    final highDiff = (_validPointTrackIndices[high] - trackIdx).abs();
    return lowDiff < highDiff ? low : high;
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

  double _getHandleYForIndex(int? chartIndex, {required double chartHeight}) {
    if (chartIndex == null || _filteredAltitudes.isEmpty) {
      return chartHeight - _kBottomBand;
    }

    final int safeIndex = chartIndex.clamp(0, _filteredAltitudes.length - 1);
    final double realAltitude = _filteredAltitudes[safeIndex];
    final double topOffset = _kTopBand;
    final double bottomOffset = _kBottomBand;
    final double usableChartHeight = chartHeight - topOffset - bottomOffset;
    final double yRange = (_maxAlt - _minAlt) == 0 ? 1.0 : (_maxAlt - _minAlt);
    final double rel = (realAltitude - _minAlt) / yRange;

    return topOffset + (usableChartHeight * (1.0 - rel.clamp(0.0, 1.0)));
  }

  Widget _buildHandleMarker({
    required double x,
    required double chartHeight,
    required Color color,
    required double? y,
  }) {
    if (x.isNaN || x.isInfinite) return const SizedBox.shrink();

    final double markerY = y ?? chartHeight - _kBottomBand;

    return Positioned(
      left: x - 10.0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: SizedBox(
          width: 20,
          height: chartHeight,
          child: CustomPaint(
            painter: _HandleMarkerPainter(
              color: color,
              markerY: markerY,
              chartHeight: chartHeight,
              lineWidth: 1.5,
              circleRadius: 5.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlutterTooltip(String mainText) {
    const Color lineColor = AppColors.editorPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: lineColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        mainText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // Tooltip de velocitat: ocupa la franja inferior, centrat sota el tooltip principal
  Widget _buildSpeedTooltip({
    required double left,
    required double width,
    required double? speedKmh,
  }) {
    final String text = speedKmh != null
        ? "${speedKmh.toStringAsFixed(1)} km/h"
        : "-- km/h";
    return Positioned(
      bottom: 2,
      left: left,
      width: width,
      child: IgnorePointer(
        ignoring: true,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kSpeedNavy,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
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

    final seconds = pCurr.timestamp!
        .difference(pPrev.timestamp!)
        .inSeconds
        .abs();
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

    // Llegim l'estat global de Riverpod de forma atòmica
    final activeTool = ref.watch(gpxEditorProvider.select((s) => s.activeTool));
    final chartSelectionMode = ref.watch(
      gpxEditorProvider.select((s) => s.chartSelectionMode),
    );
    final startTrackIdx = ref.watch(
      gpxEditorProvider.select((s) => s.chartRangeStartIndex),
    );
    final endTrackIdx = ref.watch(
      gpxEditorProvider.select((s) => s.chartRangeEndIndex),
    );
    final snappedTrackIdx = ref.watch(
      gpxEditorProvider.select(
        (s) => s.chartNeedleIndex ?? s.snappedPointIndex,
      ),
    );
    final showSpeed = ref.watch(
      gpxEditorProvider.select((s) => s.showSpeedInChart),
    );

    // Només usem el preview local mentre l'usuari arrossega dins del gràfic.
    // Si el moviment ve del mapa, el gràfic ha de seguir l'estat global.
    final bool useLocalDragPreview = _draggingHandle != -1;

    // Conversió d'índexs globals a índexs filtrats del gràfic
    final int? snappedIdx = _trackToNearestChartIndex(
      useLocalDragPreview
          ? (_displayNeedleTrackIdx ?? snappedTrackIdx)
          : snappedTrackIdx,
    );
    final int? effectiveStartTrackIdx = useLocalDragPreview
        ? (_displayStartTrackIdx ?? startTrackIdx)
        : startTrackIdx;
    final int? startPointsIndex = _trackToNearestChartIndex(
      effectiveStartTrackIdx,
    );
    final int? effectiveEndTrackIdx = useLocalDragPreview
        ? (_displayEndTrackIdx ??
              ((endTrackIdx == null || endTrackIdx == -1)
                  ? (snappedTrackIdx ?? startTrackIdx)
                  : endTrackIdx))
        : ((endTrackIdx == null || endTrackIdx == -1)
              ? (snappedTrackIdx ?? startTrackIdx)
              : endTrackIdx);
    final int? endPointsIndex = _trackToNearestChartIndex(effectiveEndTrackIdx);

    final bool isRangeModeActive =
        chartSelectionMode == 'range' ||
        activeTool == 'range_map' ||
        activeTool == 'range_chart';

    final double maxDistance = _distances.isNotEmpty ? _distances.last : 0.0;
    final overlayKey = ValueKey<String>(
      'chart-overlay-${_displayStartX?.toStringAsFixed(2) ?? 'null'}-${_displayEndX?.toStringAsFixed(2) ?? 'null'}-${_displayNeedleX?.toStringAsFixed(2) ?? 'null'}',
    );

    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // El padding fix d'alineació exacte del LineChart
          const double paddingLeft = 12.0;
          const double paddingRight = 24.0;

          final double chartWidth =
              constraints.maxWidth - paddingLeft - paddingRight;
          final double currentChartHeight = constraints.maxHeight;

          // Fòrmules de transformació matemàtica píxels <-> metres
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

          final double? graphX = useLocalDragPreview
              ? (_displayNeedleX ?? (needleX != null ? mapX(needleX) : null))
              : (needleX != null ? mapX(needleX) : null);
          final double? startXRealPixel = useLocalDragPreview
              ? (_displayStartX ??
                    (startXForPainters != null
                        ? mapX(startXForPainters)
                        : null))
              : (startXForPainters != null ? mapX(startXForPainters) : null);
          final double? endXRealPixel = useLocalDragPreview
              ? (_displayEndX ??
                    (endXForPainters != null ? mapX(endXForPainters) : null))
              : (endXForPainters != null ? mapX(endXForPainters) : null);

          final double tooltipWidth = _tooltipWidth > 0 ? _tooltipWidth : 130.0;
          const double tooltipMinLeft = 4.0;
          const double tooltipGap = 6.0;
          final double tooltipMaxLeft =
              (chartWidth + paddingLeft + paddingRight) - tooltipWidth;

          double? startTooltipLeft;
          double? endTooltipLeft;

          // Càlcul de col·lisió i posicionament lateral dels tooltips de tram
          if (startXRealPixel != null && endXRealPixel != null) {
            double startLeft = (startXRealPixel - tooltipWidth / 2).clamp(
              tooltipMinLeft,
              tooltipMaxLeft,
            );
            double endLeft = (endXRealPixel - tooltipWidth / 2).clamp(
              tooltipMinLeft,
              tooltipMaxLeft,
            );

            final bool startIsLeft = startXRealPixel <= endXRealPixel;
            double leftTooltip = startIsLeft ? startLeft : endLeft;
            double rightTooltip = startIsLeft ? endLeft : startLeft;

            double overlap =
                (leftTooltip + tooltipWidth + tooltipGap) - rightTooltip;
            if (overlap > 0) {
              final double moveEach = overlap / 2;
              final double leftCapacity = leftTooltip - tooltipMinLeft;
              final double rightCapacity = tooltipMaxLeft - rightTooltip;

              final double moveLeft = leftCapacity < moveEach
                  ? leftCapacity
                  : moveEach;
              final double moveRight = rightCapacity < moveEach
                  ? rightCapacity
                  : moveEach;

              leftTooltip -= moveLeft;
              rightTooltip += moveRight;

              overlap =
                  (leftTooltip + tooltipWidth + tooltipGap) - rightTooltip;
              if (overlap > 0) {
                final double extraRightCapacity = tooltipMaxLeft - rightTooltip;
                final double extraRight = overlap < extraRightCapacity
                    ? overlap
                    : extraRightCapacity;
                rightTooltip += extraRight;
                overlap -= extraRight;
              }

              if (overlap > 0) {
                final double extraLeftCapacity = leftTooltip - tooltipMinLeft;
                final double extraLeft = overlap < extraLeftCapacity
                    ? overlap
                    : extraLeftCapacity;
                leftTooltip -= extraLeft;
              }
            }

            startTooltipLeft = startIsLeft ? leftTooltip : rightTooltip;
            endTooltipLeft = startIsLeft ? rightTooltip : leftTooltip;
          }

          final bool showRangeArea =
              isRangeModeActive && startPointsIndex != null;
          void startRangeSelectionAtDx(
            double dx, {
            bool fromDoubleTap = false,
          }) {
            final chartIdx = _metersToIndex(dxToMeters(dx));
            final trackIdx = _chartToTrackIndex(chartIdx);

            final int rangeStartChartIdx = (_validPoints.length * 0.25)
                .floor()
                .clamp(0, _validPoints.length - 1);
            final int rangeEndChartIdx = (_validPoints.length * 0.75)
                .floor()
                .clamp(0, _validPoints.length - 1);

            if (kIsWeb && fromDoubleTap) {
              _ignorePanDownUntilMs =
                  DateTime.now().millisecondsSinceEpoch + 220;
              _lastRangeActivationDx = dx;
            }

            setState(() {
              _hideBlueNeedle = true;
              _draggingHandle = -1;
            });

            ref
                .read(gpxEditorProvider.notifier)
                .updateSnappedPoint(widget.track.points[trackIdx], trackIdx);
            // Mostra les dues agulles sense activar l'eina range_map
            ref
                .read(gpxEditorProvider.notifier)
                .startChartRangeSelection(
                  startIdx: _chartToTrackIndex(rangeStartChartIdx),
                  endIdx: _chartToTrackIndex(rangeEndChartIdx),
                  activateRangeTool: false,
                );
          }

          void finalizeRangeSelectionIfNeeded() {
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

          return SizedBox(
            height: currentChartHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ==========================================================
                // CAPA 1: ZONA OMBREJADA DEL TRAM (RangeAreaPainter)
                // ==========================================================
                if (showRangeArea && endPointsIndex != null)
                  Positioned.fill(
                    child: IgnorePointer(
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
                  ),

                // ==========================================================
                // CAPA 2: GRÀFIC D'ELEVACIÓ (fl_chart passiu embolicat)
                // ==========================================================
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: paddingLeft,
                      right: paddingRight,
                      top: _kTopBand,
                      bottom: _kBottomBand,
                    ),
                    child: IgnorePointer(
                      ignoring:
                          true, // 🌟 Evita que fl_chart interfereixi amb els gestos de Flutter
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
                          titlesData: const FlTitlesData(
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
                              color: AppColors.editorPrimary,
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.editorPrimary.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            if (showSpeed && _speedSpots.isNotEmpty)
                              LineChartBarData(
                                spots: _speedSpots,
                                isCurved: true,
                                curveSmoothness: 0.4,
                                preventCurveOverShooting: true,
                                color: const Color(0xFF0B3D91),
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
                // CAPA 3: AGULLES VERTICALS RENDERITZADES COM A WIDGETS
                // ==========================================================
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      key: overlayKey,
                      child: Stack(
                        children: [
                          if (isRangeModeActive &&
                              startXRealPixel != null &&
                              startPointsIndex != null)
                            _buildHandleMarker(
                              x: startXRealPixel,
                              chartHeight: currentChartHeight,
                              color: AppColors.starTrekGreen,
                              y: _getHandleYForIndex(
                                startPointsIndex,
                                chartHeight: currentChartHeight,
                              ),
                            ),
                          if (isRangeModeActive &&
                              endXRealPixel != null &&
                              endPointsIndex != null)
                            _buildHandleMarker(
                              x: endXRealPixel,
                              chartHeight: currentChartHeight,
                              color: AppColors.pureRed,
                              y: _getHandleYForIndex(
                                endPointsIndex,
                                chartHeight: currentChartHeight,
                              ),
                            ),
                          if (!isRangeModeActive &&
                              !_hideBlueNeedle &&
                              graphX != null &&
                              snappedIdx != null)
                            _buildHandleMarker(
                              x: graphX,
                              chartHeight: currentChartHeight,
                              color: AppColors.starTrekGreen,
                              y: _getHandleYForIndex(
                                snappedIdx,
                                chartHeight: currentChartHeight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ==========================================================
                // CAPA 4: EL DETECTOR DE GESTOS MESTRE (Governa tot l'eix X)
                // ==========================================================
                Positioned.fill(
                  child: GestureDetector(
                    // Opaque captura absolutament tots els clics als espais buits
                    behavior: HitTestBehavior.opaque,

                    onDoubleTapDown: kIsWeb
                        ? (details) {
                            startRangeSelectionAtDx(
                              details.localPosition.dx,
                              fromDoubleTap: true,
                            );
                          }
                        : null,

                    onPanStart: (details) {
                      final double x = details.localPosition.dx;
                      final double handleHitRadius = kIsWeb ? 34.0 : 24.0;
                      debugPrint(
                        '[chart-widget] onPanStart x=$x isRangeModeActive=$isRangeModeActive',
                      );

                      final int nowMs = DateTime.now().millisecondsSinceEpoch;
                      if (kIsWeb && nowMs < _ignorePanDownUntilMs) {
                        final double activationDx = _lastRangeActivationDx ?? x;
                        if ((x - activationDx).abs() <= 18) return;
                      }

                      bool touchedStart =
                          startXRealPixel != null &&
                          (x - startXRealPixel).abs() < handleHitRadius;

                      bool touchedEnd =
                          endXRealPixel != null &&
                          (x - endXRealPixel).abs() < handleHitRadius;

                      // En mode tram sempre es mou l'agulla més propera:
                      // mai es queda amb una sola agulla.
                      if (isRangeModeActive &&
                          !touchedStart &&
                          !touchedEnd &&
                          startXRealPixel != null &&
                          endXRealPixel != null) {
                        if ((x - startXRealPixel).abs() <=
                            (x - endXRealPixel).abs()) {
                          touchedStart = true;
                        } else {
                          touchedEnd = true;
                        }
                      }

                      debugPrint(
                        '[chart-widget] onPanStart touchedStart=$touchedStart touchedEnd=$touchedEnd',
                      );
                      debugPrint(
                        '[chart-widget] isRangeModeActive=$isRangeModeActive',
                      );

                      if (isRangeModeActive) {
                        if (touchedStart) {
                          debugPrint(
                            '[chart-widget] handle START touched at x=$x',
                          );
                          setState(() {
                            _draggingHandle = 1; // START
                            _hideBlueNeedle = true;
                            _displayStartTrackIdx = startTrackIdx;
                            _displayEndTrackIdx = endTrackIdx;
                            _displayNeedleTrackIdx = snappedTrackIdx;
                            _displayStartX = startXRealPixel;
                            _displayEndX = endXRealPixel;
                            _displayNeedleX = graphX;
                          });
                          SchedulerBinding.instance.scheduleFrame();
                          return;
                        }

                        if (touchedEnd) {
                          debugPrint(
                            '[chart-widget] handle END touched at x=$x',
                          );
                          setState(() {
                            _draggingHandle = 2; // END
                            _hideBlueNeedle = true;
                            _displayStartTrackIdx = startTrackIdx;
                            _displayEndTrackIdx = endTrackIdx;
                            _displayNeedleTrackIdx = snappedTrackIdx;
                            _displayStartX = startXRealPixel;
                            _displayEndX = endXRealPixel;
                            _displayNeedleX = graphX;
                          });
                          SchedulerBinding.instance.scheduleFrame();
                          return;
                        }

                        // Tram encara sense dues agulles: no fem res
                        return;
                      }

                      // Mode consulta simple per defecte
                      final chartIdx = _metersToIndex(dxToMeters(x));
                      final int dragTrackIdx = _chartToTrackIndex(chartIdx);
                      setState(() {
                        _draggingHandle = 3; // SIMPLE
                        _hideBlueNeedle = false;
                        _displayStartTrackIdx = startTrackIdx;
                        _displayEndTrackIdx = endTrackIdx;
                        _displayNeedleTrackIdx = dragTrackIdx;
                        _displayStartX = startXRealPixel;
                        _displayEndX = endXRealPixel;
                        _displayNeedleX = x;
                      });
                      SchedulerBinding.instance.scheduleFrame();

                      ref
                          .read(gpxEditorProvider.notifier)
                          .updateChartNeedle(dragTrackIdx);
                    },

                    onPanUpdate: (details) {
                      if (_draggingHandle == -1) return;

                      final double x = details.localPosition.dx;
                      debugPrint(
                        '[chart-widget] onPanUpdate handle=$_draggingHandle x=$x',
                      );
                      final int chartIdx = _metersToIndex(dxToMeters(x));
                      final int trackIdx = _chartToTrackIndex(chartIdx);

                      if (_draggingHandle == 3) {
                        // Agulla blava simple: es mou de forma directa a cada canvi
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateChartNeedle(trackIdx);
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateSnappedPoint(
                              widget.track.points[trackIdx],
                              trackIdx,
                            );
                        setState(() {
                          _displayNeedleTrackIdx = trackIdx;
                          _displayNeedleX = x;
                        });
                        SchedulerBinding.instance.scheduleFrame();
                      } else if (_draggingHandle == 1) {
                        final int currentStartTrackIdx =
                            _displayStartTrackIdx ??
                            ref.read(gpxEditorProvider).chartRangeStartIndex ??
                            startTrackIdx ??
                            0;
                        final int currentEndTrackIdx =
                            _displayEndTrackIdx ??
                            ref.read(gpxEditorProvider).chartRangeEndIndex ??
                            endTrackIdx ??
                            (widget.track.points.length - 1);

                        debugPrint(
                          '[chart-widget] dragging START -> trackIdx=$trackIdx currentStart=$currentStartTrackIdx currentEnd=$currentEndTrackIdx',
                        );

                        if (trackIdx <= currentEndTrackIdx) {
                          ref
                              .read(gpxEditorProvider.notifier)
                              .updateIndividualRangeHandle(
                                newStartIdx: trackIdx,
                                newEndIdx: currentEndTrackIdx,
                              );
                          setState(() {
                            _displayStartTrackIdx = trackIdx;
                            _displayStartX = x;
                          });
                        } else {
                          ref
                              .read(gpxEditorProvider.notifier)
                              .updateIndividualRangeHandle(
                                newStartIdx: currentEndTrackIdx,
                                newEndIdx: trackIdx,
                              );
                          setState(() {
                            _draggingHandle = 2;
                            _displayStartTrackIdx = currentEndTrackIdx;
                            _displayEndTrackIdx = trackIdx;
                            _displayStartX = endXRealPixel;
                            _displayEndX = x;
                          });
                        }
                        SchedulerBinding.instance.scheduleFrame();
                      } else if (_draggingHandle == 2) {
                        final int currentStartTrackIdx =
                            _displayStartTrackIdx ??
                            ref.read(gpxEditorProvider).chartRangeStartIndex ??
                            startTrackIdx ??
                            0;
                        final int currentEndTrackIdx =
                            _displayEndTrackIdx ??
                            ref.read(gpxEditorProvider).chartRangeEndIndex ??
                            endTrackIdx ??
                            (widget.track.points.length - 1);

                        debugPrint(
                          '[chart-widget] dragging END -> trackIdx=$trackIdx currentStart=$currentStartTrackIdx currentEnd=$currentEndTrackIdx',
                        );

                        if (trackIdx >= currentStartTrackIdx) {
                          ref
                              .read(gpxEditorProvider.notifier)
                              .updateIndividualRangeHandle(
                                newStartIdx: currentStartTrackIdx,
                                newEndIdx: trackIdx,
                              );
                          setState(() {
                            _displayEndTrackIdx = trackIdx;
                            _displayEndX = x;
                          });
                        } else {
                          ref
                              .read(gpxEditorProvider.notifier)
                              .updateIndividualRangeHandle(
                                newStartIdx: trackIdx,
                                newEndIdx: currentStartTrackIdx,
                              );
                          setState(() {
                            _draggingHandle = 1;
                            _displayStartTrackIdx = trackIdx;
                            _displayEndTrackIdx = currentStartTrackIdx;
                            _displayStartX = x;
                            _displayEndX = startXRealPixel;
                          });
                        }
                        SchedulerBinding.instance.scheduleFrame();
                      }
                    },

                    onPanEnd: (_) {
                      debugPrint(
                        '[chart-widget] onPanEnd handle=$_draggingHandle',
                      );
                      if (_draggingHandle == 1 || _draggingHandle == 2) {
                        finalizeRangeSelectionIfNeeded();
                      }
                      setState(() {
                        _draggingHandle = -1;
                        _hideBlueNeedle = false;
                        _displayStartTrackIdx = null;
                        _displayEndTrackIdx = null;
                        _displayNeedleTrackIdx = null;
                        _displayStartX = null;
                        _displayEndX = null;
                        _displayNeedleX = null;
                      });
                    },
                    onPanCancel: () {
                      setState(() {
                        _draggingHandle = -1;
                        _hideBlueNeedle = false;
                        _displayStartTrackIdx = null;
                        _displayEndTrackIdx = null;
                        _displayNeedleTrackIdx = null;
                        _displayStartX = null;
                        _displayEndX = null;
                        _displayNeedleX = null;
                      });
                    },

                    onLongPressStart: (details) {
                      if (_validPoints.isEmpty) return;

                      // 📐 CALCULEM ELS ÍNDEXS COMPROVATS AL 25% I 75% DE LA RUTA
                      final int rangeStartChartIdx =
                          (_validPoints.length * 0.25).floor().clamp(
                            0,
                            _validPoints.length - 1,
                          );
                      final int rangeEndChartIdx = (_validPoints.length * 0.75)
                          .floor()
                          .clamp(0, _validPoints.length - 1);

                      final int finalStartTrackIdx = _chartToTrackIndex(
                        rangeStartChartIdx,
                      );
                      final int finalEndTrackIdx = _chartToTrackIndex(
                        rangeEndChartIdx,
                      );

                      // 🗺️ TRANSFORMEM LES COORDENADES DE DISTÀNCIA EN PÍXELS (X) HORITZONTALS PER A LA PANTALLA
                      final double xStart = mapX(
                        _distances[rangeStartChartIdx],
                      );
                      final double xEnd = mapX(_distances[rangeEndChartIdx]);

                      // 1. Configurem l'estat local del gràfic per dibuixar les nanses separades i els tooltips
                      setState(() {
                        _draggingHandle =
                            -1; // En repòs pur perquè l'usuari les mogui després fent Pan
                        _hideBlueNeedle = true;
                        _displayStartTrackIdx = finalStartTrackIdx;
                        _displayEndTrackIdx = finalEndTrackIdx;
                        _displayStartX = xStart;
                        _displayEndX = xEnd;
                        _displayNeedleX = null;
                      });

                      // 2. Indiquem al Notifier que desi els camps del 25%-75% a l'estat global
                      ref
                          .read(gpxEditorProvider.notifier)
                          .startChartRangeSelection(
                            startIdx: finalStartTrackIdx,
                            endIdx: finalEndTrackIdx,
                            activateRangeTool:
                                false, // Es queda en 'none' per pintar el tram net al mapa
                          );

                      SchedulerBinding.instance.scheduleFrame();
                    },

                    onLongPressMoveUpdate: (details) {
                      if (_draggingHandle == -1) return;

                      final double x = details.localPosition.dx;
                      final chartIdx = _metersToIndex(dxToMeters(x));
                      final int trackIdx = _chartToTrackIndex(chartIdx);

                      final int currentStartTrackIdx =
                          _displayStartTrackIdx ??
                          ref.read(gpxEditorProvider).chartRangeStartIndex ??
                          0;

                      // 3. Calculem l'expansió del tram sincronitzant píxels gràfics i coordenades del mapa
                      if (trackIdx >= currentStartTrackIdx) {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateIndividualRangeHandle(
                              newStartIdx: currentStartTrackIdx,
                              newEndIdx: trackIdx,
                            );
                        setState(() {
                          _displayEndTrackIdx = trackIdx;
                          _displayEndX = x;
                        });
                      } else {
                        ref
                            .read(gpxEditorProvider.notifier)
                            .updateIndividualRangeHandle(
                              newStartIdx: trackIdx,
                              newEndIdx: currentStartTrackIdx,
                            );
                        setState(() {
                          _displayStartTrackIdx = trackIdx;
                          _displayStartX = x;
                        });
                      }
                      SchedulerBinding.instance.scheduleFrame();
                    },

                    onLongPressEnd: (_) {
                      // 4. Consolidem la selecció a la memòria i alliberem les variables de l'overlay gràfic
                      finalizeRangeSelectionIfNeeded();
                      setState(() {
                        _draggingHandle = -1;
                        _hideBlueNeedle = false;
                        _displayStartTrackIdx = null;
                        _displayEndTrackIdx = null;
                        _displayNeedleTrackIdx = null;
                        _displayStartX = null;
                        _displayEndX = null;
                        _displayNeedleX = null;
                      });
                    },

                    // El giny fill del detector és només un full buit transparent
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // ==========================================================
                // CAPA 5: ELS TEUS TOOLTIPS FLOTANTS DE DADES INTACTES
                // ==========================================================
                if (showRangeArea &&
                    endPointsIndex != null &&
                    startTooltipLeft != null &&
                    endTooltipLeft != null)
                  Stack(
                    children: [
                      Positioned(
                        top: 2,
                        left: startTooltipLeft,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            key: _startTooltipKey,
                            child: _buildFlutterTooltip(
                              "${(_distances[startPointsIndex] / 1000).toStringAsFixed(2)} km | ${_validPoints[startPointsIndex].elevation?.toStringAsFixed(0)} m",
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 2,
                        left: endTooltipLeft,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            key: _endTooltipKey,
                            child: _buildFlutterTooltip(
                              "${(_distances[endPointsIndex] / 1000).toStringAsFixed(2)} km | ${_validPoints[endPointsIndex].elevation?.toStringAsFixed(0)} m",
                            ),
                          ),
                        ),
                      ),
                      if (showSpeed) ...[
                        _buildSpeedTooltip(
                          left: startTooltipLeft,
                          width: tooltipWidth,
                          speedKmh: _getRealSpeedKmh(startPointsIndex),
                        ),
                        _buildSpeedTooltip(
                          left: endTooltipLeft,
                          width: tooltipWidth,
                          speedKmh: _getRealSpeedKmh(endPointsIndex),
                        ),
                      ],
                    ],
                  ),

                // Tooltip agulla blava (Consulta simple)
                if (!isRangeModeActive &&
                    !_hideBlueNeedle &&
                    snappedIdx != null &&
                    graphX != null)
                  Positioned(
                    top: 2,
                    left: (graphX - 65).clamp(
                      4.0,
                      (chartWidth + paddingLeft + paddingRight) - 130,
                    ),
                    child: IgnorePointer(
                      ignoring: true,
                      child: _buildFlutterTooltip(
                        "${(_distances[snappedIdx] / 1000).toStringAsFixed(2)} km | ${_validPoints[snappedIdx].elevation?.toStringAsFixed(0)} m",
                      ),
                    ),
                  ),
                if (!isRangeModeActive &&
                    !_hideBlueNeedle &&
                    snappedIdx != null &&
                    graphX != null &&
                    showSpeed)
                  _buildSpeedTooltip(
                    left: (graphX - 65).clamp(
                      4.0,
                      (chartWidth + paddingLeft + paddingRight) - 130,
                    ),
                    width: 130,
                    speedKmh: _getRealSpeedKmh(snappedIdx),
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
