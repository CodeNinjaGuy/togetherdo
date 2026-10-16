/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Konflikt-Hinweis beim Anlegen: Wer hat zur gewünschten Zeit schon etwas
/// oder ist im Urlaub? Reine Dart-Logik.
library;

import '../models/termin.dart';
import 'wiederholung.dart';

enum KonfliktArt { belegt, urlaub }

class Konflikt {
  const Konflikt({
    required this.personId,
    required this.vorkommen,
    required this.art,
  });

  final String personId;
  final Vorkommen vorkommen;
  final KonfliktArt art;

  @override
  bool operator ==(Object other) =>
      other is Konflikt &&
      other.personId == personId &&
      other.vorkommen == vorkommen &&
      other.art == art;

  @override
  int get hashCode => Object.hash(personId, vorkommen, art);
}

/// Konflikte des (neuen oder geänderten) Termins `neu` gegen `vorhandene`.
/// `mitglieder` löst „alle“ auf. Bei Serien wird nur das erste Vorkommen
/// geprüft (das ist, was der Nutzer gerade eingibt). Ganztägige Einträge
/// derselben Art (z. B. zwei Urlaube) gelten nicht als Konflikt, ebenso
/// Geburtstage.
List<Konflikt> findeKonflikte({
  required Termin neu,
  required Iterable<Termin> vorhandene,
  required List<String> mitglieder,
}) {
  if (neu.art == TerminArt.geburtstag) return const [];
  final betroffen = neu.fuerAlle ? mitglieder.toSet() : neu.personen.toSet();
  if (betroffen.isEmpty) return const [];
  final out = <Konflikt>[];
  for (final t in vorhandene) {
    if (t.id == neu.id) continue;
    if (t.art == TerminArt.geburtstag) continue;
    if (neu.ganztaegig && t.ganztaegig && t.art == neu.art) continue;
    final personen = t.fuerAlle ? mitglieder.toSet() : t.personen.toSet();
    final gemeinsam = betroffen.intersection(personen);
    if (gemeinsam.isEmpty) continue;
    for (final v in vorkommenIm(t, neu.start.toUtc(), neu.ende.toUtc())) {
      final art = t.art.istAbwesenheit ? KonfliktArt.urlaub : KonfliktArt.belegt;
      for (final p in gemeinsam) {
        out.add(Konflikt(personId: p, vorkommen: v, art: art));
      }
    }
  }
  out.sort((a, b) {
    final c = a.art.index.compareTo(b.art.index) * -1; // Urlaub zuerst
    return c != 0 ? c : a.vorkommen.start.compareTo(b.vorkommen.start);
  });
  return out;
}
