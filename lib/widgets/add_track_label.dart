import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';

/// Etiqueta "+ AFEGIR TRACK": només és visible quan hi ha un tram seleccionat
/// (al mapa o al gràfic) i crea un track nou a partir d'aquest tram.
class AddTrackLabel extends ConsumerWidget {
  const AddTrackLabel({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRange = ref.watch(
      gpxEditorProvider.select(
        (s) =>
            s.selectedTrackId != null &&
            s.selectionStartIndex != null &&
            s.selectionEndIndex != null &&
            s.selectionEndIndex != -1 &&
            !s.isSelectingRange,
      ),
    );
    if (!hasRange) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        ref.read(gpxEditorProvider.notifier).createTrackFromSelectedRange();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.newTrackAddedFromSelectedSegment),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.starTrekRed,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              t.addTrack,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
