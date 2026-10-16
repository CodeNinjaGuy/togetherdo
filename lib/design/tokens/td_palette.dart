/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

/// Farb-Grundlage eines Themes. Aus einer Palette baut `TdThemeBuilder`
/// das komplette Material-3-`ThemeData` samt `TdTheme`-Erweiterung.
///
/// Die Palette ist bewusst klein gehalten: wenige Grundfarben, aus denen
/// alles andere (Flächen, Verläufe, Zustände) abgeleitet wird.
@immutable
class TdPalette {
  const TdPalette({
    required this.id,
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.onSurface,
    required this.onSurfaceMuted,
    this.onPrimary = Colors.white,
    this.outline,
    this.success = const Color(0xFF2DC9A0),
    this.warning = const Color(0xFFF5A524),
    this.danger = const Color(0xFFE5484D),
    this.bodyFont = 'Manrope',
    this.displayFont = 'Nunito',
    this.heroGradient,
  });

  /// Schlüssel, unter dem der `ThemeBloc` das Theme speichert
  /// (z. B. `Light`, `Fiberoptics25`).
  final String id;
  final Brightness brightness;

  /// Markenfarbe: Knöpfe, aktive Zustände, Hervorhebungen.
  final Color primary;
  final Color onPrimary;

  /// Warmer Akzent: Belohnung, Konfetti, Hinweise.
  final Color secondary;

  /// Dritte Farbe: Fairness, Erfolg, Fortschritt.
  final Color tertiary;

  /// Hintergrund des Bildschirms.
  final Color background;

  /// Karten und Flächen auf dem Hintergrund.
  final Color surface;

  /// Hervorgehobene Flächen (Sheets, schwebende Elemente).
  final Color surfaceElevated;

  final Color onSurface;
  final Color onSurfaceMuted;
  final Color? outline;

  final Color success;
  final Color warning;
  final Color danger;

  /// Schriftfamilien (gebündelte Assets, siehe `TdTypography.bundledFamilies`). `displayFont` für Überschriften,
  /// `bodyFont` für Fließtext.
  final String bodyFont;
  final String displayFont;

  /// Verlauf für Kopfbereiche und Primärknöpfe. Ohne Angabe wird
  /// er aus `primary` und `secondary` gebildet.
  final List<Color>? heroGradient;

  bool get isDark => brightness == Brightness.dark;

  List<Color> get resolvedHeroGradient =>
      heroGradient ?? [primary, Color.lerp(primary, secondary, 0.65)!];
}
