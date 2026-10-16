/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Expansion von Wiederholungen in konkrete Vorkommen, Sichtbarkeits-Ende
/// und nächste Erinnerung. Reine Dart-Logik; Wanduhrzeiten in der Zeitzone
/// des Termins (Sommerzeit-sicher über `timezone`).
///
/// Die gleiche Logik gibt es für die Erinnerungs-Function in
/// `functions/src/termine_logik.ts`; beide müssen dieselben Vorkommen liefern.
library;

import 'package:timezone/timezone.dart' as tz;

import '../models/termin.dart';
import 'zeit.dart';

/// Sicherheitsgrenze gegen Endlosschleifen bei kaputten Regeln.
const int _maxSchritte = 20000;

/// Alle Vorkommen eines Termins, die mit `[von, bis)` überlappen,
/// aufsteigend nach Start.
List<Vorkommen> vorkommenIm(Termin t, DateTime von, DateTime bis) {
  final out = <Vorkommen>[];
  if (!bis.isAfter(von)) return out;
  final w = t.wiederholung;
  if (w == null) {
    final v = Vorkommen(termin: t, start: t.start.toUtc(), ende: t.ende.toUtc());
    if (v.ueberlappt(von, bis)) out.add(v);
    return out;
  }
  for (final v in _serie(t, w)) {
    if (!v.start.isBefore(bis)) break;
    if (v.ende.isAfter(von)) out.add(v);
  }
  return out;
}

/// Erstes Vorkommen, das um oder nach `ab` beginnt (oder `null`).
Vorkommen? naechstesVorkommen(Termin t, DateTime ab) {
  final w = t.wiederholung;
  if (w == null) {
    return t.start.toUtc().isBefore(ab)
        ? null
        : Vorkommen(termin: t, start: t.start.toUtc(), ende: t.ende.toUtc());
  }
  for (final v in _serie(t, w)) {
    if (!v.start.isBefore(ab)) return v;
  }
  return null;
}

/// Letzter Zeitpunkt, bis zu dem der Termin in Abfragen auftauchen muss.
DateTime sichtbarBis(Termin t) {
  final w = t.wiederholung;
  if (w == null) return t.ende.toUtc();
  if (w.endlos) return terminUnendlich;
  DateTime? letztes;
  for (final v in _serie(t, w)) {
    letztes = v.ende;
  }
  return letztes ?? t.ende.toUtc();
}

class NaechsteErinnerung {
  const NaechsteErinnerung({
    required this.zeitpunkt,
    required this.vorkommenStart,
    required this.minuten,
  });

  final DateTime zeitpunkt;
  final DateTime vorkommenStart;
  final int minuten;

  /// Idempotenz-Schlüssel, identisch zur Function.
  String get schluessel => '${vorkommenStart.toIso8601String()}|$minuten';
}

/// Nächste fällige Erinnerung strikt nach `ab` (UTC), oder `null`.
NaechsteErinnerung? naechsteErinnerung(Termin t, DateTime ab) {
  if (t.erinnerungen.isEmpty) return null;
  final minuten = t.erinnerungen.toSet().toList()..sort();
  final w = t.wiederholung;
  Iterable<Vorkommen> kandidaten = w == null
      ? [Vorkommen(termin: t, start: t.start.toUtc(), ende: t.ende.toUtc())]
      : _serie(t, w);
  // Die größte Vorlaufzeit bestimmt, ab wann ein Vorkommen relevant ist.
  final maxVorlauf = Duration(minutes: minuten.last);
  NaechsteErinnerung? beste;
  var geprueft = 0;
  for (final v in kandidaten) {
    if (v.start.add(const Duration(days: 1)).isBefore(ab.subtract(maxVorlauf))) {
      // Vorkommen liegt weit zurück; weiter.
      if (++geprueft > _maxSchritte) break;
      continue;
    }
    for (final m in minuten) {
      final z = v.start.subtract(Duration(minutes: m));
      if (z.isAfter(ab)) {
        if (beste == null || z.isBefore(beste.zeitpunkt)) {
          beste = NaechsteErinnerung(
            zeitpunkt: z,
            vorkommenStart: v.start,
            minuten: m,
          );
        }
      }
    }
    // Sobald ein Vorkommen selbst später als die beste Erinnerung liegt,
    // kann kein späteres Vorkommen eine frühere Erinnerung liefern.
    if (beste != null && v.start.subtract(maxVorlauf).isAfter(beste.zeitpunkt)) {
      break;
    }
  }
  return beste;
}

/// Erzeugt die Vorkommen einer Serie, aufsteigend, lazily.
Iterable<Vorkommen> _serie(Termin t, Wiederholung w) sync* {
  final zone = t.zeitzone;
  final loc = ort(zone);
  final startL = tz.TZDateTime.from(t.start.toUtc(), loc);
  final endeL = tz.TZDateTime.from(t.ende.toUtc(), loc);
  final tageSpanne = tageZwischen(
    DateTime.utc(startL.year, startL.month, startL.day),
    DateTime.utc(endeL.year, endeL.month, endeL.day),
  );
  final startTag = DateTime.utc(startL.year, startL.month, startL.day);
  final bisTag = w.bisDatum == null
      ? null
      : (() {
          final b = tz.TZDateTime.from(w.bisDatum!.toUtc(), loc);
          return DateTime.utc(b.year, b.month, b.day);
        })();
  final ausnahmen = w.ausnahmen.toSet();
  final intervall = w.intervall < 1 ? 1 : w.intervall;
  var zaehler = 0;
  var schritte = 0;

  Vorkommen? bauen(DateTime tag) {
    final s = tz.TZDateTime(
      loc,
      tag.year,
      tag.month,
      tag.day,
      startL.hour,
      startL.minute,
    );
    final e = tz.TZDateTime(
      loc,
      tag.year,
      tag.month,
      tag.day + tageSpanne,
      endeL.hour,
      endeL.minute,
    );
    final startUtc = reinUtc(s);
    var endeUtc = reinUtc(e);
    if (!endeUtc.isAfter(startUtc)) {
      endeUtc = startUtc.add(const Duration(minutes: 1));
    }
    return Vorkommen(termin: t, start: startUtc, ende: endeUtc);
  }

  Iterable<DateTime> tage() sync* {
    switch (w.typ) {
      case WiederholungTyp.taeglich:
        for (var n = 0; ; n++) {
          yield startTag.add(Duration(days: n * intervall));
        }
      case WiederholungTyp.woechentlich:
        final wochentage = (w.wochentage.isEmpty
                ? [startL.weekday]
                : w.wochentage.where((d) => d >= 1 && d <= 7).toSet().toList())
            ..sort();
        final montag = wochenanfang(startTag);
        for (var woche = 0; ; woche++) {
          final basis = montag.add(Duration(days: woche * 7 * intervall));
          for (final wd in wochentage) {
            final tag = basis.add(Duration(days: wd - 1));
            if (tag.isBefore(startTag)) continue;
            yield tag;
          }
        }
      case WiederholungTyp.monatlich:
        for (var n = 0; ; n++) {
          final monat = startTag.month - 1 + n * intervall;
          final jahr = startTag.year + monat ~/ 12;
          final m = monat % 12 + 1;
          final tag = DateTime.utc(jahr, m, startTag.day);
          if (tag.month != m) continue; // 31. in kurzem Monat: überspringen
          yield tag;
        }
      case WiederholungTyp.jaehrlich:
        for (var n = 0; ; n++) {
          final jahr = startTag.year + n * intervall;
          final tag = DateTime.utc(jahr, startTag.month, startTag.day);
          if (tag.month != startTag.month) continue; // 29. Februar
          yield tag;
        }
    }
  }

  for (final tag in tage()) {
    if (++schritte > _maxSchritte) return;
    if (bisTag != null && tag.isAfter(bisTag)) return;
    if (w.anzahl != null && zaehler >= w.anzahl!) return;
    zaehler++;
    if (ausnahmen.contains(tagSchluesselVon(tag.year, tag.month, tag.day))) {
      continue;
    }
    final v = bauen(tag);
    if (v != null) yield v;
  }
}

/// Werte, die beim Speichern eines Termins aus der Wiederholungslogik
/// abgeleitet werden (Repository schreibt sie mit).
Map<String, dynamic> abgeleiteteFelder(Termin t, {DateTime? jetzt}) {
  final ab = (jetzt ?? DateTime.now()).toUtc();
  final e = naechsteErinnerung(t, ab);
  return {
    'sichtbarBis': sichtbarBis(t),
    'naechsteErinnerungAm': e?.zeitpunkt,
  };
}
