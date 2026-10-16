/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// „Wann haben alle Zeit?“ – freie gemeinsame Zeitfenster aus den belegten
/// Zeiten der gewählten Personen. Reine Dart-Logik.
library;

import '../models/termin.dart';
import 'zeit.dart';

class Zeitfenster {
  const Zeitfenster(this.start, this.ende);

  final DateTime start;
  final DateTime ende;

  Duration get dauer => ende.difference(start);

  @override
  bool operator ==(Object other) =>
      other is Zeitfenster && other.start == start && other.ende == ende;

  @override
  int get hashCode => Object.hash(start, ende);

  @override
  String toString() => 'Zeitfenster($start – $ende)';
}

/// Belegte Zeiten der `personen` aus den Vorkommen (leer = alle betrifft
/// jede Person). Ganztägige Urlaube blockieren den ganzen Tag; Arbeit und
/// Termine blockieren ihre Zeitspanne.
List<Zeitfenster> belegteZeiten(
  Iterable<Vorkommen> vorkommen,
  Set<String> personen,
) {
  final out = <Zeitfenster>[];
  for (final v in vorkommen) {
    final betrifft =
        v.termin.fuerAlle || v.termin.personen.any(personen.contains);
    if (!betrifft) continue;
    out.add(Zeitfenster(v.start, v.ende));
  }
  return verschmelzen(out);
}

/// Überlappende oder angrenzende Fenster zusammenfassen, sortiert.
List<Zeitfenster> verschmelzen(List<Zeitfenster> fenster) {
  if (fenster.isEmpty) return const [];
  final s = [...fenster]..sort((a, b) => a.start.compareTo(b.start));
  final out = <Zeitfenster>[s.first];
  for (final f in s.skip(1)) {
    final letzt = out.last;
    if (!f.start.isAfter(letzt.ende)) {
      if (f.ende.isAfter(letzt.ende)) {
        out[out.length - 1] = Zeitfenster(letzt.start, f.ende);
      }
    } else {
      out.add(f);
    }
  }
  return out;
}

/// Freie Fenster zwischen `von` und `bis` (UTC), nur innerhalb des
/// Tagesfensters `tagVon`–`tagBis` Uhr (Ortszeit in `zeitzone`), mindestens
/// `mindestDauer` lang, höchstens `maxErgebnisse`.
List<Zeitfenster> freieZeitfenster({
  required Iterable<Vorkommen> vorkommen,
  required Set<String> personen,
  required DateTime von,
  required DateTime bis,
  required Duration mindestDauer,
  String zeitzone = 'Europe/Vienna',
  int tagVon = 8,
  int tagBis = 21,
  int maxErgebnisse = 50,
}) {
  final belegt = belegteZeiten(vorkommen, personen);
  final out = <Zeitfenster>[];
  var tag = tagesanfang(von, zeitzone);
  while (tag.isBefore(bis) && out.length < maxErgebnisse) {
    final l = lokal(tag, zeitzone);
    final fensterStart = utcVon(zeitzone, l.year, l.month, l.day, tagVon);
    final fensterEnde = utcVon(zeitzone, l.year, l.month, l.day, tagBis);
    var cursor = fensterStart.isBefore(von) ? von : fensterStart;
    final ende = fensterEnde.isAfter(bis) ? bis : fensterEnde;
    for (final b in belegt) {
      if (!b.ende.isAfter(cursor)) continue;
      if (!b.start.isBefore(ende)) break;
      if (b.start.isAfter(cursor) &&
          b.start.difference(cursor) >= mindestDauer) {
        out.add(Zeitfenster(cursor, b.start));
      }
      if (b.ende.isAfter(cursor)) cursor = b.ende;
    }
    if (ende.isAfter(cursor) && ende.difference(cursor) >= mindestDauer) {
      out.add(Zeitfenster(cursor, ende));
    }
    tag = utcVon(zeitzone, l.year, l.month, l.day + 1);
  }
  return out.take(maxErgebnisse).toList();
}
