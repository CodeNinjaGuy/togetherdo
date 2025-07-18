import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final themes = <String, ThemeData>{
    'Light': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFF6750A4),
        brightness: Brightness.light,
        onPrimary: Colors.white,
        onSurface: Colors.black,
        onSecondary: Colors.black,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
    ),
    'Matrix': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF00FF41),
        onPrimary: Colors.black,
        secondary: Color(0xFF003B00),
        onSecondary: Colors.white,
        surface: Color(0xFF101010),
        onSurface: Color(0xFF00FF41),
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: Color(0xFF101010),
      textTheme: GoogleFonts.sourceCodeProTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Color(0xFF00FF41), displayColor: Color(0xFF00FF41)),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF003B00),
        foregroundColor: Color(0xFF00FF41),
        iconTheme: IconThemeData(color: Color(0xFF00FF41)),
        titleTextStyle: TextStyle(
          color: Color(0xFF00FF41),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    'Neo': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF00E5FF),
        onPrimary: Colors.black,
        secondary: Color(0xFFFF00E5),
        onSecondary: Colors.black,
        surface: Color(0xFF181A20),
        onSurface: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: Color(0xFF181A20),
      textTheme: GoogleFonts.orbitronTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF23263A),
        foregroundColor: Color(0xFF00E5FF),
        iconTheme: IconThemeData(color: Color(0xFF00E5FF)),
        titleTextStyle: TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    'Summer': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFFFFC107),
        brightness: Brightness.light,
        primary: Color(0xFFFFC107),
        onPrimary: Color(0xFF6D4C41),
        secondary: Color(0xFFFF7043),
        onSecondary: Colors.white,
        surface: Color(0xFFFFF8E1),
        onSurface: Color(0xFF6D4C41),
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: Color(0xFFFFF8E1),
      textTheme: GoogleFonts.pacificoTextTheme().apply(
        bodyColor: Color(0xFF6D4C41),
        displayColor: Color(0xFF6D4C41),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFFFC107),
        foregroundColor: Color(0xFF6D4C41),
        iconTheme: IconThemeData(color: Color(0xFF6D4C41)),
        titleTextStyle: TextStyle(
          color: Color(0xFF6D4C41),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    'Aurora': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF00FF88),
        onPrimary: Colors.black,
        secondary: Color(0xFF00D4FF),
        onSecondary: Colors.black,
        surface: Color(0xFF0F1A23),
        onSurface: Color(0xFF00FF88),
        error: Color(0xFFFF6B6B),
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFF2A3F4A),
      ),
      scaffoldBackgroundColor: Color(0xFF0F1A23),
      textTheme: GoogleFonts.spaceMonoTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Color(0xFF00FF88), displayColor: Color(0xFF00FF88)),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1A2E3A),
        foregroundColor: Color(0xFF00FF88),
        iconTheme: IconThemeData(color: Color(0xFF00FF88)),
        titleTextStyle: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    'Sunset': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFFFF6B35),
        brightness: Brightness.light,
        primary: Color(0xFFFF6B35),
        onPrimary: Colors.white,
        secondary: Color(0xFFFF8E53),
        onSecondary: Colors.white,
        surface: Color(0xFFFFF8F0),
        onSurface: Color(0xFF8D6E63),
        error: Color(0xFFE57373),
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFFFFE0B2),
      ),
      scaffoldBackgroundColor: Color(0xFFFFF8F0),
      textTheme: GoogleFonts.playfairDisplayTextTheme().apply(
        bodyColor: Color(0xFF8D6E63),
        displayColor: Color(0xFF8D6E63),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    'Ocean': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFF006064),
        brightness: Brightness.light,
        primary: Color(0xFF006064),
        onPrimary: Colors.white,
        secondary: Color(0xFF00ACC1),
        onSecondary: Colors.white,
        surface: Color(0xFFF0FDFF),
        onSurface: Color(0xFF006064),
        error: Color(0xFFEF5350),
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFFB2EBF2),
      ),
      scaffoldBackgroundColor: Color(0xFFF0FDFF),
      textTheme: GoogleFonts.ralewayTextTheme().apply(
        bodyColor: Color(0xFF006064),
        displayColor: Color(0xFF006064),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF006064),
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    'Forest': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFF2E7D32),
        brightness: Brightness.light,
        primary: Color(0xFF2E7D32),
        onPrimary: Colors.white,
        secondary: Color(0xFF4CAF50),
        onSecondary: Colors.white,
        surface: Color(0xFFF1F8E9),
        onSurface: Color(0xFF2E7D32),
        error: Color(0xFFE57373),
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFFC8E6C9),
      ),
      scaffoldBackgroundColor: Color(0xFFF1F8E9),
      textTheme: GoogleFonts.loraTextTheme().apply(
        bodyColor: Color(0xFF2E7D32),
        displayColor: Color(0xFF2E7D32),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    'Galaxy': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF9C27B0),
        onPrimary: Colors.white,
        secondary: Color(0xFFE1BEE7),
        onSecondary: Colors.black,
        surface: Color(0xFF1A1038),
        onSurface: Color(0xFFE1BEE7),
        error: Color(0xFFF44336),
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFF4A148C),
      ),
      scaffoldBackgroundColor: Color(0xFF1A1038),
      textTheme: GoogleFonts.audiowideTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Color(0xFFE1BEE7), displayColor: Color(0xFFE1BEE7)),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF2D1B69),
        foregroundColor: Color(0xFFE1BEE7),
        iconTheme: IconThemeData(color: Color(0xFFE1BEE7)),
        titleTextStyle: TextStyle(
          color: Color(0xFFE1BEE7),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    'Fiberoptics25': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFFFF430B), // Orange-Rot aus dem Logo
        onPrimary: Colors.white,
        secondary: Color(0xFF3C62A9), // Blau aus dem Logo
        onSecondary: Colors.white,
        surface: Color(0xFF1A1A1A), // Dunkler Hintergrund
        onSurface: Colors.white,
        error: Color(0xFFFF0000), // Rot aus dem Logo
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFF2A2A2A),
        tertiary: Color(0xFFFFF000), // Gelb aus dem Logo
        onTertiary: Colors.black,
        outline: Color(0xFF006EFF), // Blau aus dem Logo
        outlineVariant: Color(0xFF01FF00), // Grün aus dem Logo
      ),
      scaffoldBackgroundColor: Color(0xFF1A1A1A),
      textTheme: GoogleFonts.robotoMonoTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF2A2A2A),
        foregroundColor: Color(0xFFFF430B),
        iconTheme: IconThemeData(color: Color(0xFFFF430B)),
        titleTextStyle: TextStyle(
          color: Color(0xFFFF430B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Color(0xFF2A2A2A),
        elevation: 8,
        shadowColor: Color(0xFFFF430B).withValues(alpha: 0.3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFF430B),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Color(0xFFFF430B).withValues(alpha: 0.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF3C62A9),
        foregroundColor: Colors.white,
      ),
    ),
  };
}
