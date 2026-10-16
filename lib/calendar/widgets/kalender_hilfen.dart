/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Kleine Helfer für die Kalender-Oberfläche: Beschriftungen, Zeitformate,
/// Personen für die Avatar-Bausteine.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/calendar/td_calendar.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common/user_avatar.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';

extension KalenderTexte on AppLocalizations {
  String artLabel(TerminArt art) => switch (art) {
    TerminArt.termin => kalArtTermin,
    TerminArt.arzt => kalArtArzt,
    TerminArt.arbeit => kalArtArbeit,
    TerminArt.urlaub => kalArtUrlaub,
    TerminArt.schule => kalArtSchule,
    TerminArt.geburtstag => kalArtGeburtstag,
    TerminArt.sonstiges => kalArtSonstiges,
  };

  String wiederholungLabel(Wiederholung? w) {
    if (w == null) return kalWdhKeine;
    return switch (w.typ) {
      WiederholungTyp.taeglich => kalWdhTaeglichN(w.intervall),
      WiederholungTyp.woechentlich => kalWdhWoechentlichN(w.intervall),
      WiederholungTyp.monatlich => kalWdhMonatlichN(w.intervall),
      WiederholungTyp.jaehrlich => kalWdhJaehrlichN(w.intervall),
    };
  }

  String erinnerungLabel(int minuten) {
    if (minuten >= 1440 && minuten % 1440 == 0) {
      return kalErinnerungTage(minuten ~/ 1440);
    }
    if (minuten >= 60 && minuten % 60 == 0) {
      return kalErinnerungStunden(minuten ~/ 60);
    }
    return kalErinnerungMinuten(minuten);
  }

  String dauerLabel(Duration d) {
    if (d.inMinutes < 60) return kalMinuten(d.inMinutes);
    if (d.inMinutes % 60 == 0) return kalStunden(d.inHours);
    return '${kalStunden(d.inHours)} ${kalMinuten(d.inMinutes % 60)}';
  }
}

/// Uhrzeit eines UTC-Zeitpunkts in der Zeitzone, nach Gerätesprache.
String zeitText(BuildContext context, DateTime utc, String zeitzone) {
  final l = lokal(utc, zeitzone);
  final locale = Localizations.localeOf(context).toString();
  final f = MediaQuery.alwaysUse24HourFormatOf(context)
      ? DateFormat.Hm(locale)
      : DateFormat.jm(locale);
  return f.format(DateTime(l.year, l.month, l.day, l.hour, l.minute));
}

/// „15:00 – 16:00“ bzw. „Ganztägig“.
String zeitraumText(BuildContext context, Vorkommen v) {
  final s = AppLocalizations.of(context)!;
  if (v.ganztaegig) {
    final tage = tageZwischen(
      lokal(v.start, v.termin.zeitzone),
      lokal(v.ende, v.termin.zeitzone),
    );
    return tage > 1 ? '${s.kalGanztaegig} · ${s.kalTageAnzahl(tage)}' : s.kalGanztaegig;
  }
  return '${zeitText(context, v.start, v.termin.zeitzone)} – ${zeitText(context, v.ende, v.termin.zeitzone)}';
}

String datumText(BuildContext context, DateTime tag, {bool mitWochentag = true}) {
  final locale = Localizations.localeOf(context).toString();
  final d = DateTime(tag.year, tag.month, tag.day);
  return mitWochentag
      ? DateFormat.MMMMEEEEd(locale).format(d)
      : DateFormat.yMMMMd(locale).format(d);
}

/// Kurzes Datum für Pillen und Chips („Di., 20. Okt.“), naive Wanduhrzeit.
String datumKurz(DateTime d, String locale) =>
    DateFormat.MMMEd(locale).format(DateTime(d.year, d.month, d.day));

/// Mitglieder → Personen für die Avatar-Bausteine (Bild aus dem Cache).
List<TdPerson> personenVon(Iterable<Mitglied> mitglieder) => [
  for (final m in mitglieder)
    TdPerson(id: m.id, name: m.name, imageUrl: UserAvatarCache.instance.peek(m.id)),
];

/// Lädt fehlende Profilbilder nach und ruft `fertig`, wenn sich etwas tat.
Future<void> profilbilderLaden(Iterable<Mitglied> mitglieder, VoidCallback fertig) async {
  var neu = false;
  for (final m in mitglieder) {
    if (UserAvatarCache.instance.contains(m.id)) continue;
    final url = await UserAvatarCache.instance.urlFor(m.id);
    if (url != null) neu = true;
  }
  if (neu) fertig();
}

/// Wochentag-Kürzel (Mo, Di …) für Wochentagsauswahl, 1 = Montag.
String wochentagKurz(BuildContext context, int tag) {
  final locale = Localizations.localeOf(context).toString();
  final montag = DateTime(2024, 1, 1);
  return DateFormat.E(locale).format(montag.add(Duration(days: tag - 1))).replaceAll('.', '');
}
