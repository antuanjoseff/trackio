import 'package:flutter/material.dart';
import 'package:trackio/l10n/app_localizations.dart';

Future<Map<String, dynamic>?> askTrackNameDialog({
  required BuildContext context,
  required String defaultName,
  required String displayDistance,
  required String displayElevation,
}) {
  final t = AppLocalizations.of(context)!;
  final nameController = TextEditingController(text: defaultName);

  // Valors per defecte de les hores i minuts per al selector
  int hours = 1;
  int minutes = 0;

  return showDialog<Map<String, dynamic>>(
    context: context,
    // 🔥 PROTECCIÓ ANDROID: Evita saltar al context de navegació superior
    useRootNavigator: false,
    // 🔥 PROTECCIÓ GRÀFICA: Opacitat mínima del fons amb enters d'Alpha per estalviar càrrega a la GPU
    barrierColor: Colors.black.withAlpha(2),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(t.toolDraw), // "Dibuixar ruta"
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📊 BLOC DE DADES EN VIU REBUTS DEL MAPA:
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(
                              Icons.straighten,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayDistance,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              "Distància",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.terrain, color: Colors.orange),
                            const SizedBox(height: 4),
                            Text(
                              displayElevation,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              "Desnivell +",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 📝 CAMP DE TEXT PER AL NOM
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: t.route ?? 'Nom de la ruta',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ⏱️ SELECTOR DE TEMPS ESTIMAT (Hores i Minuts)
                  const Text(
                    "Temps estimat per recórrer la ruta:",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DropdownButton<int>(
                        value: hours,
                        items: List.generate(
                          24,
                          (i) =>
                              DropdownMenuItem(value: i, child: Text("$i h")),
                        ),
                        onChanged: (val) =>
                            setDialogState(() => hours = val ?? 1),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: minutes,
                        items: List.generate(
                          60,
                          (i) =>
                              DropdownMenuItem(value: i, child: Text("$i min")),
                        ),
                        onChanged: (val) =>
                            setDialogState(() => minutes = val ?? 0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(t.cancel),
              ),
              TextButton(
                onPressed: () {
                  final text = nameController.text.trim();
                  Navigator.pop(context, {
                    'name': text.isNotEmpty ? text : defaultName,
                    'duration': Duration(hours: hours, minutes: minutes),
                  });
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<String?> askWaypointNameDialog(
  BuildContext context,
  String defaultName,
) {
  final t = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: defaultName);

  return showDialog<String>(
    context: context,
    // 🔥 PROTECCIÓ ANDROID: Evita saltar al context de navegació superior
    useRootNavigator: false,
    // 🔥 PROTECCIÓ GRÀFICA: Opacitat mínima utilitzant un valor enter d'Alpha (2 és gairebé transparent sobre 255)
    barrierColor: Colors.black.withAlpha(2),
    builder: (context) => AlertDialog(
      title: Text(t.addWaypoint),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: t.route ?? 'Nom'),
        // 🌟 NOU PAS A PAS: Quan prems Enter al teclat dins de l'input de text,
        // s'executa immediatament la mateixa acció que el botó d'OK.
        onSubmitted: (String textValue) {
          Navigator.pop(context, textValue.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
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
