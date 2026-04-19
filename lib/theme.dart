import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Islam 360-inspired theme: deep midnight green background, gold and emerald
/// accents, Amiri serif for headings, Inter for body.
class AppTheme {
  // Colours
  static const Color bg          = Color(0xFF071A14); // near-black emerald
  static const Color surface     = Color(0xFF0E2A20); // card surface
  static const Color surfaceAlt  = Color(0xFF12372A); // slightly lighter
  static const Color line        = Color(0xFF1F4A39);
  static const Color emerald     = Color(0xFF15803D);
  static const Color emeraldSoft = Color(0xFF22A06B);
  static const Color gold        = Color(0xFFD4AF37);
  static const Color goldSoft    = Color(0xFFEFC766);
  static const Color cream       = Color(0xFFF5EFD8);
  static const Color textHi      = Color(0xFFF5EFD8);
  static const Color textMid     = Color(0xFFB7C7BF);
  static const Color textLo      = Color(0xFF738880);

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.amiri(color: textHi, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.amiri(color: textHi, fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.amiri(color: textHi, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.amiri(color: textHi, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.amiri(color: textHi, fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.amiri(color: textHi, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.inter(color: textHi, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: GoogleFonts.inter(color: textHi, fontWeight: FontWeight.w600, fontSize: 15),
      bodyLarge: GoogleFonts.inter(color: textHi, fontSize: 14.5),
      bodyMedium: GoogleFonts.inter(color: textMid, fontSize: 13.5),
      bodySmall: GoogleFonts.inter(color: textLo, fontSize: 11.5, letterSpacing: 0.4),
      labelLarge: GoogleFonts.inter(color: textHi, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        brightness: Brightness.dark,
        primary: emerald,
        secondary: gold,
        surface: surface,
      ).copyWith(surface: surface),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textHi,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.amiri(
          color: textHi, fontSize: 22, fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        hintStyle: GoogleFonts.inter(color: textLo, fontSize: 13.5),
        prefixIconColor: gold,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.4),
        ),
      ),
      iconTheme: const IconThemeData(color: textMid),
    );
  }
}
