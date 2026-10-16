/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Verfügbarkeit für „fair verteilt“: Wer ist an einem Tag abwesend
/// (Urlaub)? Abwesende werden bei „wer ist dran“ nicht vorgeschlagen.
///
/// Schnittstelle laut Vertrag: `abwesend(userId, tag) → bool`. Die reine
/// Prüfung (`abwesendIn`) arbeitet auf geladenen Terminen; die Klasse lädt
/// die Termine der Listen einmal und hält sie kurz im Speicher.
library;

import 'dart:async';

import '../logic/wiederholung.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../repositories/termin_repository.dart';

/// `true`, wenn `userId` am Kalendertag `tag` (lokal in `zeitzone`) einen
/// Urlaub hat – als Person eingetragen oder weil der Urlaub „alle“ betrifft.
bool abwesendIn(
  Iterable<Termin> termine,
  String userId,
  DateTime tag, {
  String zeitzone = 'Europe/Vienna',
  Set<String> mitgliederDerListe = const {},
}) {
  final von = utcVon(zeitzone, tag.year, tag.month, tag.day);
  final bis = utcVon(zeitzone, tag.year, tag.month, tag.day + 1);
  for (final t in termine) {
    if (!t.art.istAbwesenheit) continue;
    final betrifft = t.fuerAlle
        ? (mitgliederDerListe.isEmpty || mitgliederDerListe.contains(userId))
        : t.personen.contains(userId);
    if (!betrifft) continue;
    if (vorkommenIm(t, von, bis).isNotEmpty) return true;
  }
  return false;
}

class Verfuegbarkeit {
  Verfuegbarkeit({
    required TerminRepository repository,
    required List<String> listIds,
    String? zeitzone,
    this.haltedauer = const Duration(minutes: 5),
  }) : _repo = repository,
       _listIds = listIds,
       _zeitzone = zeitzone ?? standardZeitzone();

  final TerminRepository _repo;
  final List<String> _listIds;
  final String _zeitzone;
  final Duration haltedauer;

  List<Termin>? _termine;
  DateTime? _geladenAm;

  Future<List<Termin>> _laden() async {
    final jetzt = DateTime.now();
    if (_termine != null && _geladenAm != null && jetzt.difference(_geladenAm!) < haltedauer) {
      return _termine!;
    }
    final ab = jetzt.toUtc().subtract(const Duration(days: 1));
    _termine = await _repo.beobachten(_listIds, ab: ab).first;
    _geladenAm = jetzt;
    return _termine!;
  }

  /// Laut Vertrag: Ist die Person an diesem Tag abwesend (Urlaub)?
  Future<bool> abwesend(String userId, DateTime tag) async {
    final termine = await _laden();
    return abwesendIn(termine, userId, tag, zeitzone: _zeitzone);
  }

  /// Alle Mitglieder, die an `tag` abwesend sind.
  Future<Set<String>> abwesende(Iterable<String> userIds, DateTime tag) async {
    final termine = await _laden();
    return {
      for (final u in userIds)
        if (abwesendIn(termine, u, tag, zeitzone: _zeitzone)) u,
    };
  }

  void verwerfen() {
    _termine = null;
    _geladenAm = null;
  }
}
