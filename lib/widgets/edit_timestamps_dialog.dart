import 'package:flutter/material.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';

/// 🕒 Modal per editar el primer i l'últim timestamp d'un track.
/// En prémer "Aplica", retorna els nous límits perquè el notifier
/// reescali linealment tots els timestamps del track.
class EditTimestampsDialog extends StatefulWidget {
  final TrackModel track;
  final AppLocalizations t;

  const EditTimestampsDialog({super.key, required this.track, required this.t});

  @override
  State<EditTimestampsDialog> createState() => _EditTimestampsDialogState();
}

class _EditTimestampsDialogState extends State<EditTimestampsDialog> {
  DateTime? _firstTimestamp;
  DateTime? _lastTimestamp;

  @override
  void initState() {
    super.initState();
    final points = widget.track.points;
    if (points.isNotEmpty) {
      _firstTimestamp = points.first.timestamp;
      _lastTimestamp = points.last.timestamp;
    }
  }

  Future<void> _pickTimestamp({required bool isFirst}) async {
    final DateTime? current = isFirst ? _firstTimestamp : _lastTimestamp;
    final DateTime now = DateTime.now();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: current != null
          ? TimeOfDay.fromDateTime(current)
          : TimeOfDay.fromDateTime(now),
    );
    if (!mounted) return;

    final DateTime result = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );

    setState(() {
      if (isFirst) {
        _firstTimestamp = result;
      } else {
        _lastTimestamp = result;
      }
    });
  }

  Widget _buildTimestampRow({
    required String label,
    required DateTime? value,
    required VoidCallback onEdit,
  }) {
    final MaterialLocalizations m = MaterialLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                value != null
                    ? '${m.formatShortDate(value)} · ${m.formatTimeOfDay(TimeOfDay.fromDateTime(value))}'
                    : '—',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_calendar_outlined, size: 20),
          color: Colors.grey.shade700,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTimestamps =
        _firstTimestamp != null && _lastTimestamp != null;

    return AlertDialog(
      title: Text(
        widget.t.editTimestamps,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 340,
        child: hasTimestamps
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimestampRow(
                    label: widget.t.firstTimestamp,
                    value: _firstTimestamp,
                    onEdit: () => _pickTimestamp(isFirst: true),
                  ),
                  const Divider(height: 24),
                  _buildTimestampRow(
                    label: widget.t.lastTimestamp,
                    value: _lastTimestamp,
                    onEdit: () => _pickTimestamp(isFirst: false),
                  ),
                ],
              )
            : Text(widget.t.noTimestamps),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.t.cancel),
        ),
        if (hasTimestamps)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop((_firstTimestamp!, _lastTimestamp!));
            },
            child: Text(widget.t.apply),
          ),
      ],
    );
  }
}
