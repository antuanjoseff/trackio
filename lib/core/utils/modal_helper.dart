import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/providers/gpx_editor_notifier.dart';

/// 🛡️ SHOW DIALOG PROTEGIT CONTRA EL MAPA
///
/// Wrapper sobre `showDialog` que activa el flag `isModalOpen` de l'estat
/// global mentre el modal és visible, de manera que tots els gestos del mapa
/// (pan, zoom, scroll, clics) queden desactivats fins que es tanca.
///
/// IMPORTANT: cal passar un [ref] (WidgetRef) perquè el helper pugui
/// actualitzar el provider. Si el context ja ve d'un ConsumerWidget/State,
/// passa el `ref` directament.
Future<T?> showModalGuarded<T>({
  required BuildContext context,
  required WidgetRef ref,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  Color? barrierColor,
}) async {
  final notifier = ref.read(gpxEditorProvider.notifier);
  notifier.setModalOpen(true);
  try {
    return await showDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: barrierColor,
      builder: builder,
    );
  } finally {
    notifier.setModalOpen(false);
  }
}
