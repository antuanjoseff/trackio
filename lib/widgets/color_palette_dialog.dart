import 'package:flutter/material.dart';
import 'package:trackio/vars/track_colors.dart';

class ColorPaletteDialog extends StatelessWidget {
  final Function(String hexColor) onColorSelected;

  const ColorPaletteDialog({super.key, required this.onColorSelected});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 300,
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Tria un color",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // 🔥 Grid sense scroll
            Expanded(
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 8, // 8x5 = 40 colors
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: TrackColors.paletteHex.map((hex) {
                  return GestureDetector(
                    onTap: () {
                      onColorSelected(hex);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TrackColors.fromHex(hex),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
