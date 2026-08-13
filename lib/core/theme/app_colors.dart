import 'package:flutter/material.dart';

class AppColors {
  // ===== Nova paleta Trackio =====

  // ===== Editor branding (single source of truth) =====
  static const Color editorPrimary = Color(0xFF76A812);
  static const Color editorSidebarBackground = Color(0xFFE8F4DA);
  static const Color editorTrackCardBackground = Color(0xFFF5F5F5);
  static const Color editorOnPrimary = Colors.white;

  // Base UI
  static const Color techBlue = Color(0xFF0066FF);
  static const Color accentOrange = Color(0xFFFF6B00);
  static const Color cleanLightGray = Color(0xFFF8F9FA);
  static const Color slateGray = Color(0xFF1E222B);

  // Mapa i tracks
  static const Color activeTrackCyan = Color(0xFF00F0FF);
  static const Color secondaryTrackViolet = Color(0xFFD000FF);
  static const Color nodeWhite = Color(0xFFFFFFFF);
  static const Color nodeBorderBlack = Color(0xFF000000);

  // Gradient semàntic
  static const Color slopeGreen = Color(0xFF10B981);
  static const Color slopeYellow = Color(0xFFF59E0B);
  static const Color effortRed = Color(0xFFEF4444);

  // Compatibilitat amb codi existent
  static const Color starTrekRed = techBlue;
  static const Color starTrekGold = accentOrange;
  static const Color starTrekBlue = activeTrackCyan;
  static const Color starTrekPurple = secondaryTrackViolet;
  static const Color starTrekSpeedLine = activeTrackCyan;
  static const Color starTrekGreen = slopeGreen;
  static const Color onSuccess = slopeGreen;
  static const Color pureRed = effortRed;

  // Semantic editor tokens
  static const Color appBarBackground = editorPrimary;
  static const Color appBarForeground = editorOnPrimary;
  static const Color mapToolActiveBackground = Colors.white;
  static const Color mapToolActiveForeground = appBarBackground;

  static const Color lightBackground = cleanLightGray;
  static const Color darkBackground = slateGray;

  static const Color lightSurface = Colors.white;
  static const Color darkSurface = Color(0xFF252B36);

  // ================= LIGHT =================

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,

    primary: techBlue,
    onPrimary: Colors.white,

    secondary: accentOrange,
    onSecondary: Colors.white,

    tertiary: activeTrackCyan,
    onTertiary: Colors.black,

    error: accentOrange,
    onError: Colors.white,

    surface: lightSurface,
    onSurface: Color(0xFF2C313A),
  );

  // ================= DARK =================

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,

    primary: techBlue,
    onPrimary: Colors.white,

    secondary: accentOrange,
    onSecondary: Colors.white,

    tertiary: secondaryTrackViolet,
    onTertiary: Colors.white,

    error: accentOrange,
    onError: Colors.white,

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
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: appBarForeground),
        actionsIconTheme: const IconThemeData(color: appBarForeground),
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
        style: TextButton.styleFrom(foregroundColor: techBlue),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: techBlue,
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
          borderSide: const BorderSide(color: techBlue, width: 2),
        ),
      ),

      // ================= NAVIGATION =================
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? lightSurface : darkSurface,
        indicatorColor: techBlue.withOpacity(.12),
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
        selectedColor: techBlue.withOpacity(.25),
        disabledColor: Colors.grey.shade400,
        labelStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),

      // ================= SWITCH =================
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? techBlue : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? techBlue.withOpacity(.30)
              : Colors.grey.withOpacity(.25),
        ),
      ),

      // ================= PROGRESS =================
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: techBlue),

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
