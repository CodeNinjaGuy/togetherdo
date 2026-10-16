/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../../calendar/models/termin.dart';
import '../theme/td_theme.dart';

/// Farbe und Symbol je Termin-Art. Farben sind in hell und dunkel gut
/// unterscheidbar und passen zur Markenpalette (warm, nicht grell).
class TdTerminStil {
  const TdTerminStil._(this.farbe, this.symbol);

  final Color farbe;
  final IconData symbol;

  static TdTerminStil of(BuildContext context, TerminArt art) {
    final td = context.td;
    final dunkel = td.isDark;
    switch (art) {
      case TerminArt.termin:
        return TdTerminStil._(td.palette.primary, Icons.event_rounded);
      case TerminArt.arzt:
        return TdTerminStil._(
          dunkel ? const Color(0xFFFF8A80) : const Color(0xFFE5484D),
          Icons.medical_services_rounded,
        );
      case TerminArt.arbeit:
        return TdTerminStil._(
          dunkel ? const Color(0xFF6FB6FF) : const Color(0xFF2E7FD6),
          Icons.work_rounded,
        );
      case TerminArt.urlaub:
        return TdTerminStil._(
          dunkel ? const Color(0xFF4FD6B8) : const Color(0xFF17A589),
          Icons.beach_access_rounded,
        );
      case TerminArt.schule:
        return TdTerminStil._(
          dunkel ? const Color(0xFFFFC14D) : const Color(0xFFE39A00),
          Icons.school_rounded,
        );
      case TerminArt.geburtstag:
        return TdTerminStil._(
          dunkel ? const Color(0xFFFF8BC2) : const Color(0xFFE05A8E),
          Icons.cake_rounded,
        );
      case TerminArt.sonstiges:
        return TdTerminStil._(
          dunkel ? const Color(0xFFB9A7FF) : const Color(0xFF8E5BD6),
          Icons.push_pin_rounded,
        );
    }
  }

  /// Zarte Fläche für Blöcke und Bänder.
  Color fuellung(BuildContext context) =>
      farbe.withValues(alpha: context.td.isDark ? 0.28 : 0.16);

  /// Kräftigere Fläche für Bänder (Urlaub/Arbeit).
  Color band(BuildContext context) =>
      farbe.withValues(alpha: context.td.isDark ? 0.45 : 0.3);

  /// Textfarbe auf der zarten Fläche.
  Color text(BuildContext context) => context.td.isDark
      ? Color.lerp(farbe, Colors.white, 0.35)!
      : Color.lerp(farbe, Colors.black, 0.35)!;
}

/// Farbe einer Person (stabil je UID, wie `TdAvatarData`).
Color tdPersonFarbe(String id, String name) {
  var hash = 0;
  for (final c in id.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  const palette = <Color>[
    Color(0xFF6A5AE0),
    Color(0xFFFF7A59),
    Color(0xFF1FB38F),
    Color(0xFFF2A500),
    Color(0xFFE05A8E),
    Color(0xFF2E9BE0),
    Color(0xFF8E5BD6),
    Color(0xFF3FB950),
  ];
  return palette[hash % palette.length];
}
