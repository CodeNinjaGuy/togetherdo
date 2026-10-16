/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import 'td_palette.dart';

/// Typografie-Skala. Überschriften in der Display-Schrift (rund, warm),
/// Fließtext in der Grotesk (ruhig, gut lesbar).
abstract final class TdTypography {
  /// Schriften, die als Assets gebündelt sind (pubspec.yaml, `fonts:`).
  /// Unbekannte Namen fallen auf die Systemschrift zurück, damit die App
  /// nie wegen einer Schrift bricht.
  static const bundledFamilies = <String>{
    'Manrope',
    'Nunito',
    'Source Code Pro',
    'Orbitron',
    'Pacifico',
    'Space Mono',
    'Playfair Display',
    'Raleway',
    'Lora',
    'Audiowide',
    'Roboto Mono',
  };

  static TextTheme build(TdPalette p) {
    final base = p.isDark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final body = _family(p.bodyFont, base);
    final display = _family(p.displayFont, base);

    TextStyle d(
      TextStyle? s,
      double size,
      FontWeight w,
      double height, [
      double spacing = 0,
    ]) => (s ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: w,
      height: height,
      letterSpacing: spacing,
      color: p.onSurface,
    );

    final theme = TextTheme(
      displayLarge: d(display.displayLarge, 44, FontWeight.w800, 1.1, -1.0),
      displayMedium: d(display.displayMedium, 36, FontWeight.w800, 1.12, -0.8),
      displaySmall: d(display.displaySmall, 30, FontWeight.w800, 1.15, -0.5),
      headlineLarge: d(display.headlineLarge, 28, FontWeight.w700, 1.2, -0.4),
      headlineMedium: d(display.headlineMedium, 24, FontWeight.w700, 1.2, -0.3),
      headlineSmall: d(display.headlineSmall, 20, FontWeight.w700, 1.25, -0.2),
      titleLarge: d(body.titleLarge, 20, FontWeight.w700, 1.25, -0.2),
      titleMedium: d(body.titleMedium, 16, FontWeight.w700, 1.3, -0.1),
      titleSmall: d(body.titleSmall, 14, FontWeight.w600, 1.3),
      bodyLarge: d(body.bodyLarge, 16, FontWeight.w500, 1.45),
      bodyMedium: d(body.bodyMedium, 14, FontWeight.w500, 1.45),
      bodySmall: d(
        body.bodySmall,
        12,
        FontWeight.w500,
        1.4,
      ).copyWith(color: p.onSurfaceMuted),
      labelLarge: d(body.labelLarge, 15, FontWeight.w700, 1.2, 0.1),
      labelMedium: d(body.labelMedium, 13, FontWeight.w600, 1.2, 0.2),
      labelSmall: d(
        body.labelSmall,
        11,
        FontWeight.w600,
        1.2,
        0.4,
      ).copyWith(color: p.onSurfaceMuted),
    );
    return theme;
  }

  /// Setzt die gebündelte Schriftfamilie auf alle Stile; bei unbekanntem
  /// Namen bleibt die Systemschrift.
  static TextTheme _family(String family, TextTheme base) {
    if (!bundledFamilies.contains(family)) return base;
    return base.apply(fontFamily: family);
  }
}
