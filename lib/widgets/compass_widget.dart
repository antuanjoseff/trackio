import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/providers/map_view_provider.dart';

/// Brúixola amb escala gràfica opcional col·locada al costat.
class CompassScalePanel extends ConsumerWidget {
  final VoidCallback? onTapCompass;
  final bool showScale;
  const CompassScalePanel({
    super.key,
    this.onTapCompass,
    this.showScale = true,
  });

  static String _formatMeters(int m) =>
      m >= 1000 ? '${m ~/ 1000} km' : '$m m';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapBearing = ref.watch(mapBearingProvider);

    final compass = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapCompass,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            AnimatedRotation(
              turns: -mapBearing / 360,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Stack(
                children: [
                  Positioned(
                    top: 2,
                    left: 0,
                    right: 0,
                    child: Center(child: _label('N')),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 0,
                    right: 0,
                    child: Center(child: _label('S')),
                  ),
                  Positioned(
                    left: 2,
                    top: 0,
                    bottom: 0,
                    child: Center(child: _label('W')),
                  ),
                  Positioned(
                    right: 2,
                    top: 0,
                    bottom: 0,
                    child: Center(child: _label('E')),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: -mapBearing / 360,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: CustomPaint(
                size: const Size(12, 14),
                painter: _CompassArrowPainter(),
              ),
            ),
            Container(
              width: 2.5,
              height: 2.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );

    final scaleMeters = ref.watch(mapScaleMetersProvider);
    final scaleWidthPx = ref.watch(mapScaleWidthPxProvider);

    if (!showScale || scaleMeters == null || scaleWidthPx == null) {
      return compass;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 57,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatMeters(scaleMeters),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: scaleWidthPx.clamp(8.0, 45.0),
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        compass,
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

class _CompassArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h)
      ..lineTo(w / 2, h * 0.8)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
