import 'package:flutter/material.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';

/// 🔢 Modal per canviar el número de nodes d'un track sense modificar
/// el recorregut. Dues modalitats: per temps (s) o per distància (m).
/// Retorna un record (interval, byTime) en prémer "Aplica".
class NodeCountDialog extends StatefulWidget {
  final TrackModel track;
  final AppLocalizations t;

  const NodeCountDialog({super.key, required this.track, required this.t});

  @override
  State<NodeCountDialog> createState() => _NodeCountDialogState();
}

class _NodeCountDialogState extends State<NodeCountDialog> {
  bool _byTime = true;
  final TextEditingController _intervalController = TextEditingController(
    text: '10',
  );

  bool get _trackHasTimestamps =>
      widget.track.points.length >= 2 &&
      widget.track.points.every((p) => p.timestamp != null);

  @override
  void initState() {
    super.initState();
    if (!_trackHasTimestamps) {
      _byTime = false;
      _intervalController.text = '50';
    }
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  double? get _interval => double.tryParse(_intervalController.text.trim());

  bool get _isValid =>
      _interval != null && _interval! > 0 && widget.track.points.length >= 2;

  void _apply() {
    if (!_isValid) return;
    Navigator.of(context).pop((_interval!, _byTime));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;

    return AlertDialog(
      title: Text(
        t.nodeCount,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modalitat
            Text(
              t.resampleMode,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(t.resampleByTime),
                  enabled: _trackHasTimestamps,
                ),
                ButtonSegment(value: false, label: Text(t.resampleByDistance)),
              ],
              selected: {_byTime},
              onSelectionChanged: (s) => setState(() {
                _byTime = s.first;
                _intervalController.text = _byTime ? '10' : '50';
              }),
            ),
            if (!_trackHasTimestamps)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  t.trackNeedsTimestamps,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                ),
              ),
            const SizedBox(height: 16),

            // Interval
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _intervalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: _isValid ? null : t.invalidInterval,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _apply(),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _byTime ? t.secondsAbbr : t.metersAbbr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(onPressed: _isValid ? _apply : null, child: Text(t.apply)),
      ],
    );
  }
}
