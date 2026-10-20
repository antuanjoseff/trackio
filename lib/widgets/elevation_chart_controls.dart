import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/core/theme/app_colors.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';
import 'package:trackio/widgets/add_track_label.dart';

/// Controls del gràfic d'elevacions per a web: mostrar/amagar el gràfic,
/// mostrar/amagar la velocitat i "+ AFEGIR TRACK".
class ElevationChartControls extends ConsumerWidget {
  const ElevationChartControls({super.key});

  static const double _size = 42;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final notifier = ref.read(gpxEditorProvider.notifier);
    final hasTrack = ref.watch(
      gpxEditorProvider.select((s) => s.selectedTrackId != null),
    );
    final showChart = ref.watch(
      gpxEditorProvider.select((s) => s.showElevationChart),
    );
    final showSpeed = ref.watch(
      gpxEditorProvider.select((s) => s.showSpeedInChart),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _circleButton(
          tooltip: t.elevationProfile,
          icon: Icons.terrain,
          enabled: hasTrack,
          active: showChart,
          onPressed: notifier.toggleElevationChart,
        ),
        if (showChart && hasTrack) ...[
          const SizedBox(width: 8),
          _circleButton(
            tooltip: showSpeed ? t.hideSpeed : t.showSpeed,
            icon: Icons.speed,
            enabled: true,
            active: showSpeed,
            onPressed: notifier.toggleSpeedChart,
          ),
          const SizedBox(width: 8),
          const AddTrackLabel(height: _size),
        ],
      ],
    );
  }

  Widget _circleButton({
    required String tooltip,
    required IconData icon,
    required bool enabled,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: !enabled
            ? AppColors.mapToolDisabledBackground
            : active
            ? Colors.white
            : AppColors.appBarBackground,
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled
              ? AppColors.appBarBackground
              : AppColors.mapToolDisabledBackground,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(
          icon,
          color: !enabled
              ? AppColors.mapToolDisabledForeground
              : active
              ? AppColors.appBarBackground
              : Colors.white,
          size: 18,
        ),
        onPressed: enabled ? onPressed : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }
}
