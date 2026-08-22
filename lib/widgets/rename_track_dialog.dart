import 'package:flutter/material.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/models/track_model.dart';

/// ✏️ Modal per canviar el nom d'un track.
/// En prémer "Desa", retorna el nou nom introduït.
class RenameTrackDialog extends StatefulWidget {
  final TrackModel track;
  final AppLocalizations t;

  const RenameTrackDialog({super.key, required this.track, required this.t});

  @override
  State<RenameTrackDialog> createState() => _RenameTrackDialogState();
}

class _RenameTrackDialogState extends State<RenameTrackDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.track.name);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final String newName = _controller.text.trim();
    if (newName.isNotEmpty) {
      Navigator.of(context).pop(newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.t.renameTrack,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 340,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: widget.t.trackName,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          style: AppColors.dialogCancelButtonStyle,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.t.cancel),
        ),
        FilledButton(
          style: AppColors.dialogActionButtonStyle,
          onPressed: _save,
          child: Text(widget.t.save),
        ),
      ],
    );
  }
}
