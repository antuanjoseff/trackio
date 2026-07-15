import 'package:flutter/material.dart';
import 'package:trackio/l10n/app_localizations.dart';

Future<String?> askWaypointNameDialog(
  BuildContext context,
  String defaultName,
) {
  // 🌟 Carreguem l'estat del diccionari reactiu de Trackio
  final t = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: defaultName);

  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      // 🌍 "Nom del waypoint" / "Añadir waypoint" / "Add waypoint" segons l'idioma actiu
      title: Text(t.addWaypoint),
      content: TextField(
        controller: controller,
        autofocus: true,
        // 🌍 Etiqueta multiidioma interna ("Nom" / "Nombre" / "Name")
        decoration: InputDecoration(labelText: t.route ?? 'Nom'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          // 🌍 "Cancel·lar" / "Cancelar" / "Cancel" unificat de forma nativa
          child: Text(t.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

Future<String?> askTrackNameDialog(BuildContext context, String defaultName) {
  final t = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: defaultName);

  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(
        t.toolDraw,
      ), // Utilitza "Dibuixar ruta" / "Dibujar ruta" / "Draw route"
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: t.route ?? 'Ruta', // O simplement l'etiqueta de text
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(t.cancel), // S'adapta a l'idioma seleccionat
        ),
        TextButton(
          onPressed: () {
            final text = controller.text.trim();
            Navigator.pop(context, text.isNotEmpty ? text : null);
          },
          child: const Text("OK"),
        ),
      ],
    ),
  );
}
