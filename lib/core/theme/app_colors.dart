import 'package:flutter/material.dart';

class AppColors {
  static const Color starTrekRed = Color(0xFF9B1C1C); // Vermell fosc
  static const Color starTrekGold = Color(0xFFD39A2A); // Daurat

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: starTrekRed,
    onPrimary: Colors.white,
    secondary: starTrekGold,
    onSecondary: Colors.white,
    error: Color(0xFF7A1010),
    onError: Colors.white,
    surface: Color(0xFFFFF9EF),
    onSurface: Color(0xFF2F1A05),
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: starTrekRed,
    onPrimary: Colors.white,
    secondary: starTrekGold,
    onSecondary: Colors.white,
    error: Color(0xFFFF8A80),
    onError: Colors.black,
    surface: Color(0xFF1F1812),
    onSurface: Color(0xFFF4E7CF),
  );

  static ThemeData themed(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final ColorScheme scheme = isLight ? lightColorScheme : darkColorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: isLight
          ? const Color(0xFFFFF7EC)
          : const Color(0xFF14100C),
      cardColor: isLight ? Colors.white.withOpacity(0.96) : scheme.surface,
      dividerColor: isLight ? const Color(0xFFE5D7BF) : const Color(0xFF3A2E23),
      iconTheme: const IconThemeData(color: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: starTrekGold,
        foregroundColor: starTrekRed,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: starTrekGold,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: starTrekRed,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: starTrekRed,
        foregroundColor: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: starTrekRed),
      ),
    );
  }

  static ThemeData get lightTheme => themed(Brightness.light);
  static ThemeData get darkTheme => themed(Brightness.dark);
}
