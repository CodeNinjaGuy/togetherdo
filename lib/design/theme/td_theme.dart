/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../tokens/td_palette.dart';
import '../tokens/td_tokens.dart';

/// Ergänzt `ThemeData` um alles, was Material 3 nicht kennt: Verläufe,
/// Glas-Flächen, Zustandsfarben und Schatten. Zugriff über `context.td`.
@immutable
class TdTheme extends ThemeExtension<TdTheme> {
  const TdTheme({
    required this.palette,
    required this.heroGradient,
    required this.primaryGradient,
    required this.successGradient,
    required this.glassFill,
    required this.glassBorder,
    required this.success,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.shadowSoft,
    required this.shadowLifted,
    required this.confettiColors,
  });

  factory TdTheme.fromPalette(TdPalette p) {
    final hero = p.resolvedHeroGradient;
    return TdTheme(
      palette: p,
      heroGradient: LinearGradient(
        colors: hero,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      primaryGradient: LinearGradient(
        colors: [p.primary, Color.lerp(p.primary, hero.last, 0.45)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      successGradient: LinearGradient(
        colors: [p.tertiary, Color.lerp(p.tertiary, p.primary, 0.4)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glassFill: p.isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.62),
      glassBorder: p.isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.75),
      success: p.success,
      warning: p.warning,
      danger: p.danger,
      muted: p.onSurfaceMuted,
      shadowSoft: TdShadows.soft(
        p.isDark ? Colors.black : p.primary,
        dark: p.isDark,
      ),
      shadowLifted: TdShadows.lifted(
        p.isDark ? Colors.black : p.primary,
        dark: p.isDark,
      ),
      confettiColors: [p.primary, p.secondary, p.tertiary, ...hero],
    );
  }

  final TdPalette palette;
  final LinearGradient heroGradient;
  final LinearGradient primaryGradient;
  final LinearGradient successGradient;
  final Color glassFill;
  final Color glassBorder;
  final Color success;
  final Color warning;
  final Color danger;
  final Color muted;
  final List<BoxShadow> shadowSoft;
  final List<BoxShadow> shadowLifted;
  final List<Color> confettiColors;

  bool get isDark => palette.isDark;

  @override
  TdTheme copyWith({TdPalette? palette}) =>
      palette == null ? this : TdTheme.fromPalette(palette);

  @override
  TdTheme lerp(ThemeExtension<TdTheme>? other, double t) {
    if (other is! TdTheme) return this;
    return TdTheme(
      palette: t < 0.5 ? palette : other.palette,
      heroGradient:
          LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      primaryGradient:
          LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      successGradient:
          LinearGradient.lerp(successGradient, other.successGradient, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      shadowSoft: BoxShadow.lerpList(shadowSoft, other.shadowSoft, t)!,
      shadowLifted: BoxShadow.lerpList(shadowLifted, other.shadowLifted, t)!,
      confettiColors: t < 0.5 ? confettiColors : other.confettiColors,
    );
  }
}

extension TdThemeContext on BuildContext {
  /// Die Design-Erweiterung des aktuellen Themes. Fällt auf die
  /// Markenpalette zurück, falls ein fremdes `ThemeData` aktiv ist.
  TdTheme get td =>
      Theme.of(this).extension<TdTheme>() ??
      TdTheme.fromPalette(_fallbackPalette(Theme.of(this).brightness));

  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

TdPalette _fallbackPalette(Brightness b) => TdPalette(
  id: 'fallback',
  brightness: b,
  primary: const Color(0xFF5B4BD6),
  secondary: const Color(0xFFFF7A59),
  tertiary: const Color(0xFF1FB38F),
  background: b == Brightness.dark
      ? const Color(0xFF131218)
      : const Color(0xFFF8F5F0),
  surface: b == Brightness.dark ? const Color(0xFF1C1B23) : Colors.white,
  surfaceElevated:
      b == Brightness.dark ? const Color(0xFF26242F) : Colors.white,
  onSurface: b == Brightness.dark
      ? const Color(0xFFF2EFF8)
      : const Color(0xFF1C1B22),
  onSurfaceMuted: b == Brightness.dark
      ? const Color(0xFF9A96A8)
      : const Color(0xFF6E6B7A),
);
