import 'package:flutter/material.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/core/utils/geo_utils.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';

/// 📋 Modal read-only amb les propietats del track.
class TrackPropertiesDialog extends StatelessWidget {
  final TrackModel track;
  final AppLocalizations t;

  const TrackPropertiesDialog({
    super.key,
    required this.track,
    required this.t,
  });

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(1)} m';
  }

  String _formatDuration(Duration d) {
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatDateTime(BuildContext context, DateTime? dt) {
    if (dt == null) return t.noData;
    final m = MaterialLocalizations.of(context);
    return '${m.formatShortDate(dt)} · ${m.formatTimeOfDay(TimeOfDay.fromDateTime(dt))}';
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = track.points
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

    // Distància total
    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += GeoCalculations.distanceBetween(
        points[i].latitude!,
        points[i].longitude!,
        points[i + 1].latitude!,
        points[i + 1].longitude!,
      );
    }

    final int nodeCount = points.length;
    final double metersPerNode = nodeCount > 1
        ? totalDistance / (nodeCount - 1)
        : 0;

    final DateTime? firstTs = points.isNotEmpty ? points.first.timestamp : null;
    final DateTime? lastTs = points.isNotEmpty ? points.last.timestamp : null;
    final Duration? duration = (firstTs != null && lastTs != null)
        ? lastTs.difference(firstTs)
        : null;

    return AlertDialog(
      title: Text(
        t.properties,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(t.totalDistance, _formatDistance(totalDistance)),
            const Divider(height: 1),
            _row(t.nodesCount, '$nodeCount'),
            const Divider(height: 1),
            _row(
              t.metersPerNode,
              nodeCount > 1
                  ? '${metersPerNode.toStringAsFixed(2)} m'
                  : t.noData,
            ),
            const Divider(height: 1),
            _row(t.firstTimestamp, _formatDateTime(context, firstTs)),
            const Divider(height: 1),
            _row(t.lastTimestamp, _formatDateTime(context, lastTs)),
            const Divider(height: 1),
            _row(
              t.trackDuration,
              duration != null ? _formatDuration(duration) : t.noData,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: AppColors.dialogCancelButtonStyle,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
      ],
    );
  }
}
