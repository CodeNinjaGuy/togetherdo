/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Beispielzustand für Vorschau- und Jahres-Tests: vier Mitglieder,
/// Urlaube im August (davon 12.–16. alle), Geburtstag, Arbeitsserie Mo–Fr,
/// ein Arzttermin und ein Samstagstermin im Oktober 2026.
library;

import 'package:togetherdo/calendar/bloc/kalender_cubit.dart';
import 'package:togetherdo/calendar/logic/zeit.dart';
import 'package:togetherdo/calendar/models/termin.dart';
import 'package:togetherdo/models/list_model.dart';

const beispielZone = 'Europe/Vienna';

Termin beispielTermin({
  required String id,
  required String titel,
  required DateTime start,
  required DateTime ende,
  TerminArt art = TerminArt.termin,
  List<String> personen = const [],
  bool ganztaegig = false,
  Wiederholung? w,
}) => Termin(
  id: id,
  listId: 'L1',
  titel: titel,
  art: art,
  personen: personen,
  start: start,
  ende: ende,
  ganztaegig: ganztaegig,
  zeitzone: beispielZone,
  wiederholung: w,
  erstelltVon: 'u1',
);

/// Ganztägiger Termin von `von` bis `bis` (einschließlich), Wanduhr Wien.
Termin ganztags({
  required String id,
  required String titel,
  required DateTime von,
  required DateTime bis,
  TerminArt art = TerminArt.urlaub,
  List<String> personen = const [],
  Wiederholung? w,
}) => beispielTermin(
  id: id,
  titel: titel,
  art: art,
  personen: personen,
  ganztaegig: true,
  start: utcVon(beispielZone, von.year, von.month, von.day),
  ende: utcVon(beispielZone, bis.year, bis.month, bis.day + 1),
  w: w,
);

KalenderZustand beispielZustand({List<Termin>? termine, String? feiertagsRegion}) {
  kalenderZeitInit();
  final liste = ListModel(
    id: 'L1',
    name: 'Familie',
    ownerId: 'u1',
    ownerName: 'Martin',
    type: ListType.todo,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    memberIds: const ['u2', 'u3', 'u4'],
    memberNames: const ['Anna', 'Ben', 'Clara'],
  );
  return KalenderZustand(
    userId: 'u1',
    fokus: DateTime.utc(2026, 10, 16),
    listen: [liste],
    aktiveListen: const {'L1'},
    laedt: false,
    zeitzone: beispielZone,
    feiertagsRegion: feiertagsRegion,
    termine: termine ?? beispielTermine(),
  );
}

List<Termin> beispielTermine() => [
  ganztags(
    id: 'U1',
    titel: 'Urlaub Martin',
    von: DateTime.utc(2026, 8, 10),
    bis: DateTime.utc(2026, 8, 16),
    personen: const ['u1'],
  ),
  ganztags(
    id: 'U2',
    titel: 'Urlaub Anna',
    von: DateTime.utc(2026, 8, 12),
    bis: DateTime.utc(2026, 8, 20),
    personen: const ['u2'],
  ),
  ganztags(
    id: 'U3',
    titel: 'Kinder frei',
    von: DateTime.utc(2026, 8, 12),
    bis: DateTime.utc(2026, 8, 16),
    personen: const ['u3', 'u4'],
  ),
  ganztags(
    id: 'G1',
    titel: 'Anna Geburtstag',
    art: TerminArt.geburtstag,
    von: DateTime.utc(2020, 10, 5),
    bis: DateTime.utc(2020, 10, 5),
    personen: const ['u2'],
    w: const Wiederholung(typ: WiederholungTyp.jaehrlich),
  ),
  beispielTermin(
    id: 'A1',
    titel: 'Arbeit',
    art: TerminArt.arbeit,
    personen: const ['u1'],
    start: utcVon(beispielZone, 2026, 1, 5, 8),
    ende: utcVon(beispielZone, 2026, 1, 5, 16),
    w: const Wiederholung(typ: WiederholungTyp.woechentlich, wochentage: [1, 2, 3, 4, 5]),
  ),
  beispielTermin(
    id: 'Z1',
    titel: 'Zahnarzt Ben',
    art: TerminArt.arzt,
    personen: const ['u3'],
    start: utcVon(beispielZone, 2026, 10, 7, 10),
    ende: utcVon(beispielZone, 2026, 10, 7, 11),
  ),
  beispielTermin(
    id: 'T1',
    titel: 'Familienfest',
    start: utcVon(beispielZone, 2026, 10, 24, 14),
    ende: utcVon(beispielZone, 2026, 10, 24, 18),
  ),
];
