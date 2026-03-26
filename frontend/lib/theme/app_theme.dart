import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF1DB954);
  static const Color primaryDark = Color(0xFF17A845);
  static const Color primaryLight = Color(0xFFE8F8EE);
  static const Color primaryGlow = Color(0x331DB954);

  static const Color bgBase = Color(0xFFF7F8FA);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgOverlay = Color(0xFFF0F0F3);

  static const Color textPrimary = Color(0xFF0D1117);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFFADB5BD);

  static const Color success = Color(0xFF1DB954);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static const Color navBg = Color(0xFF1A1A2E);
  static const Color navActive = Color(0xFF1DB954);

  // Intensity Colors
  static const Color intensityLow = Color(0xFFF5CB51);
  static const Color intensityMid = Color(0xFFFC8F4C);
  static const Color intensityHigh = Color(0xFFE04154);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bgBase,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get navShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.18),
      blurRadius: 32,
      offset: const Offset(0, -4),
    ),
  ];

  static List<BoxShadow> get fabShadow => [
    BoxShadow(
      color: primary.withOpacity(0.45),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  // Border Radius
  static const double radiusXS = 8;
  static const double radiusSM = 12;
  static const double radiusMD = 16;
  static const double radiusLG = 24;
  static const double radiusXL = 32;
  static const double radiusFull = 100;
}
