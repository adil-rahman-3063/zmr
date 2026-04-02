import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Absolute Base: Deep Brown
  static const Color brownBase = Color(0xFF2D241E); // Warm Deep Brown
  static const Color blackBase = Color(0xFF000000);
  
  // Grey shades for depth and hierarchy
  static const Color greyDark = Color(0xFF1C1C1E);
  static const Color greyMedium = Color(0xFF2C2C2E);
  static const Color greyLight = Color(0xFF3A3A3C);
  
  // White/Off-white for text and primary elements
  static const Color whiteBase = Color(0xFFFFFFFF);
  static const Color whiteMuted = Color(0xFFEBEBF5);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brownBase,
      brightness: Brightness.light,
      primary: brownBase,
      onPrimary: whiteBase,
      surface: whiteBase,
      onSurface: brownBase,
    ),
    textTheme: GoogleFonts.outfitTextTheme(),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brownBase,
      brightness: Brightness.dark,
      primary: whiteBase,
      onPrimary: blackBase,
      secondary: whiteMuted,
      onSecondary: blackBase,
      surface: brownBase,
      onSurface: whiteBase,
    ),
    scaffoldBackgroundColor: brownBase,
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: whiteBase),
      titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: whiteBase),
      bodyLarge: GoogleFonts.outfit(color: whiteMuted),
      bodyMedium: GoogleFonts.outfit(color: whiteMuted.withAlpha(178)), // ~0.7 opacity
    ),
    iconTheme: const IconThemeData(color: whiteBase),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: whiteBase),
    ),
  );
}
