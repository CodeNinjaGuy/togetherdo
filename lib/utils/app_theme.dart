import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final themes = <String, ThemeData>{
    'Light': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme(),
    ),
    'Matrix': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF00FF41),
        secondary: Color(0xFF003B00),
        surface: Color(0xFF222B22),
      ),
      scaffoldBackgroundColor: Color(0xFF101010),
      textTheme: GoogleFonts.sourceCodeProTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Color(0xFF00FF41), displayColor: Color(0xFF00FF41)),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF003B00),
        foregroundColor: Color(0xFF00FF41),
      ),
    ),
    'Neo': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF00E5FF),
        secondary: Color(0xFFFF00E5),
        surface: Color(0xFF23263A),
      ),
      scaffoldBackgroundColor: Color(0xFF181A20),
      textTheme: GoogleFonts.orbitronTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Color(0xFF00E5FF), displayColor: Color(0xFFFF00E5)),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF23263A),
        foregroundColor: Color(0xFF00E5FF),
      ),
    ),
    'Summer': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFFFFC107),
        brightness: Brightness.light,
        primary: Color(0xFFFFC107),
        secondary: Color(0xFFFF7043),
        surface: Color(0xFFFFECB3),
      ),
      scaffoldBackgroundColor: Color(0xFFFFF8E1),
      textTheme: GoogleFonts.pacificoTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFFFC107),
        foregroundColor: Color(0xFF6D4C41),
      ),
    ),
  };
}
