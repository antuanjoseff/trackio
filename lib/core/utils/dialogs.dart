import 'package:flutter/material.dart';

Future<String?> askWaypointNameDialog(
  BuildContext context,
  String defaultName,
) {
  final controller = TextEditingController(text: defaultName);

  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Nom del waypoint"),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: "Nom"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("Cancel·lar"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}
