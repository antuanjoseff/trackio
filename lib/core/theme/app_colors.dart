import 'package:flutter/material.dart';

class AppColors {
  // ===== Paleta Elegant (Star Trek Inspired) =====

  static const Color starTrekRed = Color(0xFF8E4A49); // Borgonya suau
  static const Color starTrekGold = Color(0xFFC8A46B); // Bronze elegant
  static const Color starTrekBlue = Color(0xFF5E81AC); // Blau acer
  static const Color starTrekPurple = Color(0xFF7B6D8D); // Lila apagat
  static const Color starTrekSpeedLine = Color(
    0xFF4DA3D9,
  ); // Blau cian per la línia de velocitat

  // Colors semàntics
  static const Color starTrekGreen = Color(0xFF4F8A5B); // Èxit
  static const Color onSuccess = Color.fromARGB(255, 84, 190, 81);
  static const Color pureRed = Color.fromARGB(255, 255, 0, 0);

  static const Color lightBackground = Color(0xFFF4F4F2);
  static const Color darkBackground = Color(0xFF151A22);

  static const Color lightSurface = Colors.white;
  static const Color darkSurface = Color(0xFF1E2532);

  // ================= LIGHT =================

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,

    primary: starTrekRed,
    onPrimary: Colors.white,

    secondary: starTrekGold,
    onSecondary: Colors.black,

    tertiary: starTrekBlue,
    onTertiary: Colors.white,

    error: Color(0xFFB85050),
    onError: Colors.white,

    surface: lightSurface,
    onSurface: Color(0xFF2C313A),
  );

  // ================= DARK =================

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,

    primary: starTrekGold,
    onPrimary: Colors.black,

    secondary: starTrekBlue,
    onSecondary: Colors.white,

    tertiary: starTrekPurple,
    onTertiary: Colors.white,

    error: Color(0xFFE57373),
    onError: Colors.black,

    surface: darkSurface,
    onSurface: Color(0xFFF2F2F2),
  );

  static ThemeData themed(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = isLight ? lightColorScheme : darkColorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,

      scaffoldBackgroundColor: isLight ? lightBackground : darkBackground,

      // ================= APP BAR =================
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: isLight ? lightSurface : darkSurface,
        foregroundColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: scheme.primary),
        actionsIconTheme: IconThemeData(color: scheme.primary),
      ),

      // ================= DRAWER =================
      drawerTheme: DrawerThemeData(
        backgroundColor: isLight ? lightSurface : darkSurface,
        surfaceTintColor: Colors.transparent,
      ),

      // ================= CARDS =================
      cardTheme: CardThemeData(
        color: isLight ? lightSurface : darkSurface,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ================= BUTTONS =================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withOpacity(.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: starTrekBlue),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: starTrekBlue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // ================= INPUTS =================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF262F3E),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isLight ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: starTrekBlue, width: 2),
        ),
      ),

      // ================= NAVIGATION =================
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? lightSurface : darkSurface,
        indicatorColor: starTrekBlue.withOpacity(.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ================= DIVIDERS =================
      dividerColor: isLight ? Colors.grey.shade300 : Colors.grey.shade800,

      // ================= ICONS =================
      iconTheme: IconThemeData(color: scheme.primary),

      // ================= CHIPS =================
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? Colors.grey.shade200
            : const Color(0xFF2B3444),
        selectedColor: starTrekBlue.withOpacity(.25),
        disabledColor: Colors.grey.shade400,
        labelStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),

      // ================= SWITCH =================
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? starTrekBlue
              : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? starTrekBlue.withOpacity(.30)
              : Colors.grey.withOpacity(.25),
        ),
      ),

      // ================= PROGRESS =================
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: starTrekBlue,
      ),

      // ================= SNACKBAR =================
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight
            ? const Color(0xFF30343F)
            : const Color(0xFF242A35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),

      // ================= DIALOG =================
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? Colors.white : darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ================= TYPOGRAPHY =================
      textTheme: Typography.material2021().black.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }

  static ThemeData get lightTheme => themed(Brightness.light);

  static ThemeData get darkTheme => themed(Brightness.dark);
}
