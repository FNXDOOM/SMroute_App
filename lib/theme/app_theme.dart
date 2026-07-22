import 'package:flutter/material.dart';

class AppTheme {
  // ── Color constants ────────────────────────────────────────────────────────
  static const Color scaffoldBg    = Color(0xFF111111);
  static const Color surfaceColor  = Color(0xFF1A1A1A);
  static const Color accentBlue    = Color(0xFF276EF1);
  static const Color accentPurple  = Color(0xFF7B3FF2);
  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Color(0xFF888888);
  static const Color textTertiary  = Color(0xFF666666);
  static const Color textDisabled  = Color(0xFF444444);
  static const Color readNotifBg   = Color(0xFF161616);
  static const Color borderColor   = Color(0xFF2A2A2A);
  static const Color borderDark    = Color(0xFF1E1E1E);

  // ── Border-radius constants ────────────────────────────────────────────────
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;

  // ── TextStyle presets ──────────────────────────────────────────────────────
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.white,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Color(0xFF888888),
  );

  static const TextStyle labelUppercase = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF888888),
    letterSpacing: 0.8,
  );

  // ── ThemeData ──────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: scaffoldBg,
        colorScheme: const ColorScheme.dark(
          primary: accentBlue,
          surface: surfaceColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          hintStyle: const TextStyle(color: textDisabled),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: const BorderSide(color: Colors.white),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
}
