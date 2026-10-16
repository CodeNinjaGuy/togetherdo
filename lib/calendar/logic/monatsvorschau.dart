/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Reine Logik für „Was kommt im Monat“ und den Jahresüberblick:
/// Highlights, freie Wochenenden, wer wie viel unterwegs ist, gemeinsamer
/// Urlaub („alle frei“) und die Dichte je Woche für die Heatmap.
///
/// Alle Tage sind reine Tage (UTC-Mitternacht, wie `nurTag`) in der
/// Zeitzone des Zustands; Vorkommen werden über `KalenderZustand.vorkommen`
/// geholt und damit nach Listen, Personen und Arten gefiltert.
library;

import '../bloc/kalender_cubit.dart';
import '../models/termin.dart';
import 'zeit.dart';

/// Zusammenhängender Zeitraum reiner Tage, `bis` einschließlich.
class Zeitraum {
  const Zeitraum(this.von, this.bis);

  final DateTime von;
  final DateTime bis;

  int get tage => tageZwischen(von, bis) + 1;

  bool enthaelt(DateTime tag) => !tag.isBefore(von) && !tag.isAfter(bis);

  /// Überlappt den Zeitraum `[von, bis]` (beide einschließlich).
  bool ueberlappt(DateTime a, DateTime b) => !bis.isBefore(a) && !von.isAfter(b);

  @override
  bool operator ==(Object other) =>
      other is Zeitraum && other.von == von && other.bis == bis;

  @override
  int get hashCode => Object.hash(von, bis);

  @override
  String toString() =>
      '${von.toIso8601String().substring(0, 10)}–${bis.toIso8601String().substring(0, 10)}';
}

/// Ein besonderer Eintrag des Monats (Urlaub, Geburtstag, Arzt, mehrtägig).
class Highlight {
  const Highlight({
    required this.vorkommen,
    required this.erster,
    required this.letzter,
    required this.personen,
  });

  final Vorkommen vorkommen;

  /// Erster und letzter Tag (reine Tage) des Vorkommens, auf den Monat begrenzt.
  final DateTime erster;
  final DateTime letzter;

  /// Betroffene Mitglieder-IDs.
  final List<String> personen;

  TerminArt get art => vorkommen.art;
  bool get mehrtaegig => letzter.isAfter(erster);
}

/// Wie viel ein Mitglied im Monat unterwegs ist.
class Unterwegs {
  const Unterwegs({
    required this.mitglied,
    required this.urlaubstage,
    required this.arbeitsstunden,
    required this.termine,
  });

  final Mitglied mitglied;
  final int urlaubstage;
  final double arbeitsstunden;
  final int termine;

  bool get leer => urlaubstage == 0 && arbeitsstunden == 0 && termine == 0;
}

class Monatsvorschau {
  const Monatsvorschau({
    required this.monat,
    required this.highlights,
    required this.freieWochenenden,
    required this.unterwegs,
    required this.gemeinsamerUrlaub,
    required this.dichte,
  });

  /// Erster Tag des Monats (reiner Tag).
  final DateTime monat;

  /// Nach Start sortiert, jedes Vorkommen einmal.
  final List<Highlight> highlights;

  /// Samstage der freien Wochenenden (Sa + So ohne Eintrag für die
  /// gewählten Personen; Geburtstage und Feiertage blockieren nicht).
  final List<DateTime> freieWochenenden;

  /// Je sichtbarem Mitglied, Reihenfolge wie `sichtbareMitglieder`.
  final List<Unterwegs> unterwegs;

  /// Zeiträume im Monat, in denen alle sichtbaren Mitglieder Urlaub haben
  /// (auf den Monat beschnitten).
  final List<Zeitraum> gemeinsamerUrlaub;

  /// Montag der Woche → Auslastung 0..1 (relativ zur vollsten Woche).
  final Map<DateTime, double> dichte;

  bool get ruhig =>
      highlights.isEmpty &&
      gemeinsamerUrlaub.isEmpty &&
      unterwegs.every((u) => u.leer);
}

/// Stunden, mit denen ein ganztägiger Arbeitstag zählt.
const double _ganztagsArbeitStunden = 8;

/// Mitglieder-IDs, die ein Vorkommen betrifft.
List<String> betroffenePersonen(KalenderZustand z, Vorkommen v) => v.termin.fuerAlle
    ? z.mitgliederIdsDerListe(v.termin.listId)
    : v.termin.personen;

/// Erster und letzter reiner Tag eines Vorkommens in der Zeitzone.
Zeitraum tageVon(Vorkommen v, String zone) {
  final erster = nurTag(lokal(v.start, zone));
  final letzter = nurTag(lokal(v.ende.subtract(const Duration(minutes: 1)), zone));
  return Zeitraum(erster, letzter.isBefore(erster) ? erster : letzter);
}

Monatsvorschau berechneMonatsvorschau({
  required KalenderZustand zustand,
  required DateTime monat,
  DateTime? heute,
}) {
  final z = zustand;
  final zone = z.zeitzone;
  final erster = DateTime.utc(monat.year, monat.month, 1);
  final letzter = DateTime.utc(monat.year, monat.month + 1, 0);
  final von = utcVon(zone, erster.year, erster.month, 1);
  final bis = utcVon(zone, erster.year, erster.month + 1, 1);
  final vorkommen = z.vorkommen(von, bis);
  final mitglieder = z.sichtbareMitglieder;
  final sichtbar = mitglieder.map((m) => m.id).toSet();

  // --- Highlights -----------------------------------------------------
  final highlights = <Highlight>[];
  for (final v in vorkommen) {
    final t = tageVon(v, zone);
    final e = t.von.isBefore(erster) ? erster : t.von;
    final l = t.bis.isAfter(letzter) ? letzter : t.bis;
    final mehrtaegig = l.isAfter(e) || t.tage > 1;
    final besonders = v.art == TerminArt.urlaub ||
        v.art == TerminArt.geburtstag ||
        v.art == TerminArt.arzt ||
        (mehrtaegig && v.art != TerminArt.arbeit);
    if (!besonders) continue;
    final personen = betroffenePersonen(z, v);
    if (sichtbar.isNotEmpty && !personen.any(sichtbar.contains)) continue;
    highlights.add(Highlight(vorkommen: v, erster: e, letzter: l, personen: personen));
  }
  highlights.sort((a, b) {
    final c = a.erster.compareTo(b.erster);
    return c != 0 ? c : a.vorkommen.start.compareTo(b.vorkommen.start);
  });

  // --- Belegte Tage je Mitglied ----------------------------------------
  // Tagindex 0.. (Tag des Monats - 1) → Menge belegter Mitglieder.
  final tageImMonat = letzter.day;
  final belegt = List.generate(tageImMonat, (_) => <String>{});
  final urlaubTage = <String, Set<int>>{for (final m in mitglieder) m.id: {}};
  final arbeit = <String, double>{for (final m in mitglieder) m.id: 0};
  final termine = <String, int>{for (final m in mitglieder) m.id: 0};

  for (final v in vorkommen) {
    final personen = betroffenePersonen(z, v).where(sichtbar.contains).toList();
    if (personen.isEmpty) continue;
    final t = tageVon(v, zone);
    final startIdx = (tageZwischen(erster, t.von)).clamp(0, tageImMonat - 1);
    final endIdx = (tageZwischen(erster, t.bis)).clamp(0, tageImMonat - 1);
    if (v.art != TerminArt.geburtstag) {
      for (var i = startIdx; i <= endIdx; i++) {
        belegt[i].addAll(personen);
      }
    }
    switch (v.art) {
      case TerminArt.urlaub:
        for (final p in personen) {
          for (var i = startIdx; i <= endIdx; i++) {
            urlaubTage[p]!.add(i);
          }
        }
      case TerminArt.arbeit:
        final std = v.ganztaegig
            ? (endIdx - startIdx + 1) * _ganztagsArbeitStunden
            : _stundenImFenster(v, von, bis);
        for (final p in personen) {
          arbeit[p] = arbeit[p]! + std;
        }
      default:
        for (final p in personen) {
          termine[p] = termine[p]! + 1;
        }
    }
  }

  // --- Freie Wochenenden -------------------------------------------------
  final freie = <DateTime>[];
  for (var d = 1; d <= tageImMonat; d++) {
    final sa = DateTime.utc(erster.year, erster.month, d);
    if (sa.weekday != DateTime.saturday) continue;
    final saFrei = belegt[d - 1].isEmpty;
    final soFrei = d < tageImMonat ? belegt[d].isEmpty : _tagFrei(z, sa.add(const Duration(days: 1)), sichtbar);
    if (saFrei && soFrei) freie.add(sa);
  }

  // --- Unterwegs -----------------------------------------------------------
  final unterwegs = [
    for (final m in mitglieder)
      Unterwegs(
        mitglied: m,
        urlaubstage: urlaubTage[m.id]!.length,
        arbeitsstunden: arbeit[m.id]!,
        termine: termine[m.id]!,
      ),
  ];

  // --- Gemeinsamer Urlaub (auf Monat beschnitten) ------------------------
  final gemeinsam = <Zeitraum>[];
  for (final zr in gemeinsamerUrlaub(z, erster.year)) {
    if (!zr.ueberlappt(erster, letzter)) continue;
    gemeinsam.add(
      Zeitraum(
        zr.von.isBefore(erster) ? erster : zr.von,
        zr.bis.isAfter(letzter) ? letzter : zr.bis,
      ),
    );
  }

  return Monatsvorschau(
    monat: erster,
    highlights: highlights,
    freieWochenenden: freie,
    unterwegs: unterwegs,
    gemeinsamerUrlaub: gemeinsam,
    dichte: wochenDichte(z, erster, letzter),
  );
}

/// Ob an einem Tag kein (blockierender) Eintrag für die Mitglieder liegt.
bool _tagFrei(KalenderZustand z, DateTime tag, Set<String> sichtbar) {
  final von = utcVon(z.zeitzone, tag.year, tag.month, tag.day);
  final bis = utcVon(z.zeitzone, tag.year, tag.month, tag.day + 1);
  for (final v in z.vorkommen(von, bis)) {
    if (v.art == TerminArt.geburtstag) continue;
    if (betroffenePersonen(z, v).any(sichtbar.contains)) return false;
  }
  return true;
}

double _stundenImFenster(Vorkommen v, DateTime von, DateTime bis) {
  final s = v.start.isBefore(von) ? von : v.start;
  final e = v.ende.isAfter(bis) ? bis : v.ende;
  if (!e.isAfter(s)) return 0;
  return e.difference(s).inMinutes / 60;
}

/// Zeiträume des Jahres, in denen ALLE sichtbaren Mitglieder Urlaub haben
/// (aus `urlaub`-Vorkommen, über Monatsgrenzen hinweg). Ohne Mitglieder
/// leer.
List<Zeitraum> gemeinsamerUrlaub(KalenderZustand zustand, int jahr) {
  final z = zustand;
  final mitglieder = z.sichtbareMitglieder.map((m) => m.id).toSet();
  if (mitglieder.isEmpty) return const [];
  final zone = z.zeitzone;
  final erster = DateTime.utc(jahr, 1, 1);
  final letzter = DateTime.utc(jahr, 12, 31);
  final tage = tageZwischen(erster, letzter) + 1;
  final imUrlaub = List.generate(tage, (_) => <String>{});
  final von = utcVon(zone, jahr, 1, 1);
  final bis = utcVon(zone, jahr + 1, 1, 1);
  for (final v in z.vorkommen(von, bis)) {
    if (v.art != TerminArt.urlaub) continue;
    final personen = betroffenePersonen(z, v).where(mitglieder.contains);
    if (personen.isEmpty) continue;
    final t = tageVon(v, zone);
    final a = tageZwischen(erster, t.von).clamp(0, tage - 1);
    final b = tageZwischen(erster, t.bis).clamp(0, tage - 1);
    for (var i = a; i <= b; i++) {
      imUrlaub[i].addAll(personen);
    }
  }
  final out = <Zeitraum>[];
  int? start;
  for (var i = 0; i <= tage; i++) {
    final alle = i < tage && imUrlaub[i].length == mitglieder.length;
    if (alle && start == null) start = i;
    if (!alle && start != null) {
      out.add(
        Zeitraum(
          erster.add(Duration(days: start)),
          erster.add(Duration(days: i - 1)),
        ),
      );
      start = null;
    }
  }
  return out;
}

/// Auslastung je Woche (Montag → 0..1) im Zeitraum `[von, bis]` (reine
/// Tage). Je Vorkommen zählt ein Grundwert, Zeittermine zusätzlich nach
/// Dauer; ganztägige Bänder (Urlaub, Arbeit) zählen wenig, weil sie den
/// Tag nicht „voll“ machen. Normiert auf die vollste Woche im Zeitraum.
Map<DateTime, double> wochenDichte(KalenderZustand zustand, DateTime von, DateTime bis) {
  final z = zustand;
  final zone = z.zeitzone;
  final erster = wochenanfang(von);
  final letzter = wochenanfang(bis);
  final roh = <DateTime, double>{};
  for (var mo = erster; !mo.isAfter(letzter); mo = mo.add(const Duration(days: 7))) {
    roh[mo] = 0;
  }
  final fensterVon = utcVon(zone, erster.year, erster.month, erster.day);
  final fensterBis = utcVon(zone, letzter.year, letzter.month, letzter.day + 7);
  for (final v in z.vorkommen(fensterVon, fensterBis)) {
    final t = tageVon(v, zone);
    final mo = wochenanfang(t.von.isBefore(erster) ? erster : t.von);
    if (!roh.containsKey(mo)) continue;
    double wert;
    if (v.ganztaegig && v.art.istBand) {
      wert = 0.25;
    } else if (v.ganztaegig) {
      wert = 1;
    } else {
      final std = v.dauer.inMinutes / 60;
      wert = v.art == TerminArt.arbeit ? 0.5 + std / 16 : 1 + std / 2;
    }
    roh[mo] = roh[mo]! + wert;
  }
  var max = 0.0;
  for (final w in roh.values) {
    if (w > max) max = w;
  }
  if (max == 0) return {for (final k in roh.keys) k: 0.0};
  return {for (final e in roh.entries) e.key: (e.value / max).clamp(0.0, 1.0)};
}
