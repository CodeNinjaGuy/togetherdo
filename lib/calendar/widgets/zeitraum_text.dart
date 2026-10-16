/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Kurze Datumsbereiche für Chips: „12.–16. Aug.“ (de) bzw. „Aug 12–16“
/// (en). Reine Tage, keine Zeitzone.
library;

import 'package:intl/intl.dart';

String _tag(DateTime d, String locale) =>
    DateFormat.MMMd(locale).format(DateTime(d.year, d.month, d.day));

/// Zeitraum von `von` bis `bis` (einschließlich) als kurzer Text.
String zeitraumKurz(DateTime von, DateTime bis, String locale) {
  if (von.year == bis.year && von.month == bis.month && von.day == bis.day) {
    return _tag(von, locale);
  }
  final gleicherMonat = von.year == bis.year && von.month == bis.month;
  if (gleicherMonat) {
    final monat = DateFormat.MMM(locale).format(DateTime(bis.year, bis.month, bis.day));
    return locale.startsWith('de')
        ? '${von.day}.–${bis.day}. $monat'
        : '$monat ${von.day}–${bis.day}';
  }
  return '${_tag(von, locale)} – ${_tag(bis, locale)}';
}

/// Wochenende „7./8.“ (de) bzw. „7/8“ (en) für den Samstag `sa`.
String wochenendeKurz(DateTime sa, String locale) {
  final so = sa.add(const Duration(days: 1));
  return locale.startsWith('de') ? '${sa.day}./${so.day}.' : '${sa.day}/${so.day}';
}
