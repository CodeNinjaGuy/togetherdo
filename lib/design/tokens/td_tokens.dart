/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

/// Abstände auf einem 4-Punkt-Raster.
abstract final class TdSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Seitlicher Rand von Bildschirminhalten.
  static const double page = 20;
}

/// Eckradien. Große Radien für große Flächen, kleine für kleine.
abstract final class TdRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get control => BorderRadius.circular(md);
  static BorderRadius get sheet =>
      const BorderRadius.vertical(top: Radius.circular(xl));
}

/// Dauern und Kurven. Alle Animationen der App greifen hierauf zu, damit
/// sich die Bewegung überall gleich anfühlt.
abstract final class TdMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration page = Duration(milliseconds: 320);
  static const Duration celebrate = Duration(milliseconds: 900);
  static const Duration counter = Duration(milliseconds: 700);

  /// Standardkurve: zügig raus, weich rein.
  static const Curve standard = Curves.easeOutCubic;

  /// Betont, für Einblendungen größerer Flächen.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Leichter Überschwinger für Abhaken und Belohnung.
  static const Curve spring = Curves.easeOutBack;

  /// Zurückhaltend für Ausblenden.
  static const Curve exit = Curves.easeInCubic;

  /// Liefert `true`, wenn der Nutzer „Bewegung reduzieren“ eingeschaltet
  /// hat. Dann entfallen Verschiebungen, Konfetti und Überschwinger; nur
  /// kurze Überblendungen bleiben.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Dauer unter Berücksichtigung von „Bewegung reduzieren“.
  static Duration of(BuildContext context, Duration base) =>
      reduced(context) ? Duration.zero : base;

  /// Versatz einer gestaffelten Einblendung (Listenzeile `index`).
  static Duration stagger(int index, {int stepMs = 45, int maxMs = 400}) {
    final ms = (index * stepMs).clamp(0, maxMs);
    return Duration(milliseconds: ms);
  }
}

/// Umbruchpunkte für Handy, iPad und Mac.
abstract final class TdBreakpoints {
  static const double compact = 600;
  static const double medium = 1024;
}

enum TdLayoutSize { compact, medium, expanded }

extension TdLayoutContext on BuildContext {
  TdLayoutSize get tdLayout {
    final w = MediaQuery.sizeOf(this).width;
    if (w < TdBreakpoints.compact) return TdLayoutSize.compact;
    if (w < TdBreakpoints.medium) return TdLayoutSize.medium;
    return TdLayoutSize.expanded;
  }

  bool get tdIsCompact => tdLayout == TdLayoutSize.compact;
}

/// Schatten-Ebenen. Weich und farbig abgetönt statt grau.
abstract final class TdShadows {
  static List<BoxShadow> soft(Color tint, {bool dark = false}) => [
    BoxShadow(
      color: tint.withValues(alpha: dark ? 0.35 : 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: tint.withValues(alpha: dark ? 0.25 : 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> lifted(Color tint, {bool dark = false}) => [
    BoxShadow(
      color: tint.withValues(alpha: dark ? 0.5 : 0.14),
      blurRadius: 32,
      offset: const Offset(0, 14),
    ),
  ];

  /// Leuchten um Primärknöpfe und aktive Elemente.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
