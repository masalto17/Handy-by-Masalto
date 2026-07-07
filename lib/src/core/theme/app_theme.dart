import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const String logoAsset = 'assets/handy_logo.png';

  static const Color background = Color(0xFF030404);
  static const Color backgroundRaised = Color(0xFF080A0A);
  static const Color surface = Color(0xFF101313);
  static const Color surfaceRaised = Color(0xFF171B1B);
  static const Color surfaceBorder = Color(0xFF2B3030);
  static const Color accent = Color(0xFFE0B233);
  static const Color brandGold = Color(0xFFE0B233);
  static const Color accentSoft = Color(0xFF3B2A08);
  static const Color success = Color(0xFF36D66B);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFE63838);

  static BoxDecoration screenDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050606), background, Color(0xFF000000)],
        stops: [0, 0.54, 1],
      ),
    );
  }

  static BoxDecoration panelDecoration({
    Color? borderColor,
    Color? fillColor,
    bool glow = false,
  }) {
    final effectiveBorder = borderColor ?? surfaceBorder;
    return BoxDecoration(
      color: fillColor ?? surface.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: effectiveBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        if (glow)
          BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 28),
      ],
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF030404),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: 0.78),
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: surfaceBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: surfaceBorder),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
        labelLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
      ),
    );
  }
}
