import 'package:flutter/material.dart';

class AppTheme {
  // ☀️ 1. CONFIGURACIÓ DEL TEMA CLAR (Mode Dia)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF2E7D32), // Verd Senda pirinenc
      scaffoldBackgroundColor: const Color(
        0xFFF8F9FA,
      ), // Fondo gris/blanc alpí molt suau
      // Estil per a les teves càpsules flotants i panells de dades
      cardColor: Colors.white.withOpacity(0.95),
      dividerColor: Colors.grey.shade300,

      // Paleta de colors contextuals per a les eines
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2E7D32),
        secondary: Color(0xFFFF6D00), // Taronja de selecció de rang
        surface: Colors.white,
        error: Color(0xFFF44336), // Vermell de final de rang
      ),

      // Textos legibles i nets per a les estadístiques (TrackStatsPanel)
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF1A1D20), fontSize: 13),
        titleMedium: TextStyle(
          color: Color(0xFF1A1D20),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 🌙 2. CONFIGURACIÓ DEL TEMA FOSC (Mode Nit / Túnel)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(
        0xFF4CAF50,
      ), // Verd més brillant per garantir visibilitat a les fosques
      scaffoldBackgroundColor: const Color(
        0xFF121212,
      ), // Negre fosc estàndard d'alta descàrrega OLED
      // Les teves càpsules flotants es tornen gris grafit fosc amb transparència
      cardColor: const Color(0xFF1E1E1E).withOpacity(0.90),
      dividerColor: Colors.grey.shade800,

      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF4CAF50),
        secondary: Color(
          0xFFFFAB40,
        ), // Taronja adaptat amb més brillantor per a la nit
        surface: Color(0xFF1E1E1E),
        error: Color(
          0xFFFF5252,
        ), // Vermell neó per veure el waypoint o final sota el túnel
      ),

      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: Color(0xFFE0E0E0),
          fontSize: 13,
        ), // Blanc grisos per no enlluernar
        titleMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
