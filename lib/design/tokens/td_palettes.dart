/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import 'td_palette.dart';

/// Alle Paletten der App. Die Schlüssel (`id`) sind die Namen, die der
/// `ThemeBloc` speichert; sie dürfen sich nicht ändern, sonst verlieren
/// Nutzer ihre Auswahl.
abstract final class TdPalettes {
  /// Markenpalette hell: warmes Leinen, Indigo als Markenfarbe,
  /// Koralle als warmer Akzent, Mint für Fairness/Erledigt.
  static const light = TdPalette(
    id: 'Light',
    brightness: Brightness.light,
    primary: Color(0xFF5B4BD6),
    secondary: Color(0xFFFF7A59),
    tertiary: Color(0xFF1FB38F),
    background: Color(0xFFF8F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1C1B22),
    onSurfaceMuted: Color(0xFF6E6B7A),
    outline: Color(0xFFE6E1DA),
    heroGradient: [Color(0xFF6A5AE0), Color(0xFF9F6BFF), Color(0xFFFF8A65)],
  );

  /// Markenpalette dunkel: warmes Anthrazit statt reinem Schwarz.
  static const dark = TdPalette(
    id: 'Dark',
    brightness: Brightness.dark,
    primary: Color(0xFF9B8CFF),
    onPrimary: Color(0xFF171331),
    secondary: Color(0xFFFF8F70),
    tertiary: Color(0xFF3DD6AE),
    background: Color(0xFF131218),
    surface: Color(0xFF1C1B23),
    surfaceElevated: Color(0xFF26242F),
    onSurface: Color(0xFFF2EFF8),
    onSurfaceMuted: Color(0xFF9A96A8),
    outline: Color(0xFF302E3A),
    heroGradient: [Color(0xFF4F3FC6), Color(0xFF7E5BE8), Color(0xFFD9674A)],
  );

  // ---------------------------------------------------------------
  // Bestehende Themes, in das neue System überführt. Farben bleiben,
  // Flächen und Schriften folgen den neuen Regeln (Lesbarkeit zuerst,
  // Display-Schrift trägt den Charakter).
  // ---------------------------------------------------------------

  static const matrix = TdPalette(
    id: 'Matrix',
    brightness: Brightness.dark,
    primary: Color(0xFF00FF41),
    onPrimary: Colors.black,
    secondary: Color(0xFF00B32D),
    tertiary: Color(0xFF7CFF9B),
    background: Color(0xFF0A0F0A),
    surface: Color(0xFF111A11),
    surfaceElevated: Color(0xFF17241A),
    onSurface: Color(0xFF9DFFB0),
    onSurfaceMuted: Color(0xFF4FAE60),
    outline: Color(0xFF1F3A24),
    bodyFont: 'Source Code Pro',
    displayFont: 'Source Code Pro',
    heroGradient: [Color(0xFF003B00), Color(0xFF00FF41)],
  );

  static const neo = TdPalette(
    id: 'Neo',
    brightness: Brightness.dark,
    primary: Color(0xFF00E5FF),
    onPrimary: Colors.black,
    secondary: Color(0xFFFF00E5),
    tertiary: Color(0xFF7CFFB2),
    background: Color(0xFF12141B),
    surface: Color(0xFF181A20),
    surfaceElevated: Color(0xFF23263A),
    onSurface: Colors.white,
    onSurfaceMuted: Color(0xFF9AA3B8),
    outline: Color(0xFF2C3047),
    displayFont: 'Orbitron',
    heroGradient: [Color(0xFF00E5FF), Color(0xFF7B2FFF), Color(0xFFFF00E5)],
  );

  static const summer = TdPalette(
    id: 'Summer',
    brightness: Brightness.light,
    primary: Color(0xFFF2A500),
    onPrimary: Color(0xFF4E3524),
    secondary: Color(0xFFFF7043),
    tertiary: Color(0xFF2EB88A),
    background: Color(0xFFFFF8E1),
    surface: Color(0xFFFFFDF6),
    surfaceElevated: Color(0xFFFFFFFF),
    onSurface: Color(0xFF5A3F31),
    onSurfaceMuted: Color(0xFF9A7B6B),
    outline: Color(0xFFF2E3C0),
    displayFont: 'Pacifico',
    heroGradient: [Color(0xFFFFC107), Color(0xFFFF7043)],
  );

  static const aurora = TdPalette(
    id: 'Aurora',
    brightness: Brightness.dark,
    primary: Color(0xFF00FF88),
    onPrimary: Colors.black,
    secondary: Color(0xFF00D4FF),
    tertiary: Color(0xFFB388FF),
    background: Color(0xFF0B1419),
    surface: Color(0xFF0F1A23),
    surfaceElevated: Color(0xFF1A2E3A),
    onSurface: Color(0xFFDFFBEE),
    onSurfaceMuted: Color(0xFF7FB8A4),
    outline: Color(0xFF1F3A44),
    displayFont: 'Space Mono',
    heroGradient: [Color(0xFF00FF88), Color(0xFF00D4FF), Color(0xFF7B5CFF)],
  );

  static const sunset = TdPalette(
    id: 'Sunset',
    brightness: Brightness.light,
    primary: Color(0xFFFF6B35),
    secondary: Color(0xFFFF8E53),
    tertiary: Color(0xFF8E5BD6),
    background: Color(0xFFFFF8F0),
    surface: Color(0xFFFFFCF8),
    surfaceElevated: Color(0xFFFFFFFF),
    onSurface: Color(0xFF5C4037),
    onSurfaceMuted: Color(0xFF9C7F75),
    outline: Color(0xFFFFE0B2),
    displayFont: 'Playfair Display',
    heroGradient: [Color(0xFFFF6B35), Color(0xFFFFB347), Color(0xFFB45CD6)],
  );

  static const ocean = TdPalette(
    id: 'Ocean',
    brightness: Brightness.light,
    primary: Color(0xFF006064),
    secondary: Color(0xFF00ACC1),
    tertiary: Color(0xFF26A69A),
    background: Color(0xFFF0FDFF),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0B3C3F),
    onSurfaceMuted: Color(0xFF5F8A8D),
    outline: Color(0xFFB2EBF2),
    bodyFont: 'Raleway',
    displayFont: 'Raleway',
    heroGradient: [Color(0xFF006064), Color(0xFF00ACC1)],
  );

  static const forest = TdPalette(
    id: 'Forest',
    brightness: Brightness.light,
    primary: Color(0xFF2E7D32),
    secondary: Color(0xFF8BC34A),
    tertiary: Color(0xFFFFB300),
    background: Color(0xFFF1F8E9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1B3A1E),
    onSurfaceMuted: Color(0xFF5F7F62),
    outline: Color(0xFFC8E6C9),
    displayFont: 'Lora',
    heroGradient: [Color(0xFF2E7D32), Color(0xFF8BC34A)],
  );

  static const galaxy = TdPalette(
    id: 'Galaxy',
    brightness: Brightness.dark,
    primary: Color(0xFFC77DFF),
    onPrimary: Color(0xFF1A1038),
    secondary: Color(0xFFFF7EB6),
    tertiary: Color(0xFF7CF5FF),
    background: Color(0xFF130C2B),
    surface: Color(0xFF1A1038),
    surfaceElevated: Color(0xFF2D1B69),
    onSurface: Color(0xFFEEDFF7),
    onSurfaceMuted: Color(0xFFA78FC4),
    outline: Color(0xFF3B2A6E),
    displayFont: 'Audiowide',
    heroGradient: [Color(0xFF4A148C), Color(0xFF9C27B0), Color(0xFFFF7EB6)],
  );

  /// Firmen-Theme Fiberoptics25: dunkel, Orange-Rot aus dem Logo,
  /// Blau als Zweitfarbe, Gelb als Dritte. Mono-Schrift in Überschriften
  /// hält den Charakter, Fließtext bleibt gut lesbar.
  static const fiberoptics25 = TdPalette(
    id: 'Fiberoptics25',
    brightness: Brightness.dark,
    primary: Color(0xFFFF430B),
    secondary: Color(0xFF3C62A9),
    tertiary: Color(0xFFFFF000),
    background: Color(0xFF141414),
    surface: Color(0xFF1A1A1A),
    surfaceElevated: Color(0xFF2A2A2A),
    onSurface: Colors.white,
    onSurfaceMuted: Color(0xFFA6A6A6),
    outline: Color(0xFF333333),
    success: Color(0xFF01FF00),
    danger: Color(0xFFFF0000),
    displayFont: 'Roboto Mono',
    heroGradient: [Color(0xFFFF430B), Color(0xFFFF7A1A), Color(0xFF3C62A9)],
  );

  /// Reihenfolge wie in der Auswahl im Profil.
  static const all = <TdPalette>[
    light,
    dark,
    matrix,
    neo,
    summer,
    aurora,
    sunset,
    ocean,
    forest,
    galaxy,
    fiberoptics25,
  ];

  static TdPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => light);
}
