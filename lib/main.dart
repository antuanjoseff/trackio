import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackio/l10n/app_localizations.dart';
import 'package:trackio/screens/main_editor_screen.dart';

void main() {
  // 🧠 Assegurem la inicialització correcta dels serveis del framework
  // abans de muntar l'arbre de ginys de Flutter.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // Envoltem tota la app amb ProviderScope per activar Riverpod 2
    // a totes les pantalles de Trackio de forma global.
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trackio',
      debugShowCheckedModeBanner: false, // Traiem el banner de debug incòmode
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // 🌐 CONFIGURACIÓ GLOBAL MULTIIDIOMA (ca, es, en)
      localizationsDelegates: const [
        AppLocalizations.delegate, // El teu l10n de la Fase 1
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ca'), // Català
        Locale('es'), // Español
        Locale('en'), // English
      ],

      // 🚀 PANTALLA D'INICI: Apuntem al Layout responsive optimitzat amb const
      home: const MainEditorScreen(),
    );
  }
}
