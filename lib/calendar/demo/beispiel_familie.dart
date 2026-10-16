/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Beispielfamilie für Demo, Screenshots und Widget-Tests: vier Personen,
/// Arbeitsschichten, Urlaub, Arzttermine, Geburtstag, Schule – in zwei
/// Listen (Familie, WG). Alles relativ zu einem „Heute“.
library;

import '../../models/list_model.dart';
import '../../models/list_preview.dart';
import '../../models/todo_model.dart';
import '../../repositories/list_repository.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../repositories/termin_repository.dart';

const beispielZone = 'Europe/Vienna';

abstract final class Beispiel {
  static const ich = 'u-markus';
  static const anna = 'u-anna';
  static const lisa = 'u-lisa';
  static const tom = 'u-tom';
  static const mia = 'u-mia';

  static const familie = 'L-familie';
  static const wg = 'L-wg';

  static List<ListModel> listen() {
    final t = DateTime.utc(2026, 1, 1);
    return [
      ListModel(
        id: familie,
        name: 'Familie',
        ownerId: ich,
        ownerName: 'Markus',
        type: ListType.todo,
        createdAt: t,
        updatedAt: t,
        isShared: true,
        memberIds: const [anna, lisa, tom],
        memberNames: const ['Anna', 'Lisa', 'Tom'],
      ),
      ListModel(
        id: wg,
        name: 'WG Lisa',
        ownerId: lisa,
        ownerName: 'Lisa',
        type: ListType.shopping,
        createdAt: t,
        updatedAt: t,
        isShared: true,
        memberIds: const [ich, mia],
        memberNames: const ['Markus', 'Mia'],
      ),
    ];
  }

  /// Termine rund um `heute` (reiner Tag). `montag` = Montag dieser Woche.
  static List<Termin> termine(DateTime heute) {
    final montag = wochenanfang(heute);
    DateTime z(DateTime tag, int h, [int m = 0]) =>
        utcVon(beispielZone, tag.year, tag.month, tag.day + 0, h, m);
    DateTime tag(int versatz) => montag.add(Duration(days: versatz));

    Termin t({
      required String id,
      required String titel,
      required TerminArt art,
      required DateTime start,
      required DateTime ende,
      List<String> personen = const [],
      bool ganztaegig = false,
      String? ort,
      String? notiz,
      Wiederholung? w,
      List<int> erinnerungen = const [30],
      String listId = familie,
      String erstelltVon = ich,
    }) => Termin(
      id: id,
      listId: listId,
      titel: titel,
      art: art,
      personen: personen,
      start: start,
      ende: ende,
      ganztaegig: ganztaegig,
      ort: ort,
      notiz: notiz,
      zeitzone: beispielZone,
      wiederholung: w,
      erinnerungen: erinnerungen,
      erstelltVon: erstelltVon,
      erstelltAm: DateTime.utc(2026, 1, 2),
      aktualisiertAm: DateTime.utc(2026, 1, 2),
    );

    return [
      // Lisa: Frühschicht Mo–Fr 6–14 (Serie ab vor 8 Wochen, endlos)
      t(
        id: 'T-lisa-schicht',
        titel: 'Frühschicht',
        art: TerminArt.arbeit,
        personen: const [lisa],
        start: z(tag(-56), 6),
        ende: z(tag(-56), 14),
        ort: 'Klinikum',
        w: const Wiederholung(typ: WiederholungTyp.woechentlich, wochentage: [1, 2, 3, 4, 5]),
        erinnerungen: const [],
      ),
      // Anna: Spätschicht Di/Do 14–22
      t(
        id: 'T-anna-schicht',
        titel: 'Spätschicht',
        art: TerminArt.arbeit,
        personen: const [anna],
        start: z(tag(-55), 14),
        ende: z(tag(-55), 22),
        w: const Wiederholung(typ: WiederholungTyp.woechentlich, wochentage: [2, 4]),
        erinnerungen: const [],
      ),
      // Ich: Büro Mo–Fr 9–17 (Homeoffice Freitag)
      t(
        id: 'T-ich-buero',
        titel: 'Büro',
        art: TerminArt.arbeit,
        personen: const [ich],
        start: z(tag(-56), 9),
        ende: z(tag(-56), 17),
        ort: 'SeeBubble',
        w: const Wiederholung(typ: WiederholungTyp.woechentlich, wochentage: [1, 2, 3, 4]),
        erinnerungen: const [],
      ),
      // Tom: Schule Mo–Fr 8–13
      t(
        id: 'T-tom-schule',
        titel: 'Schule',
        art: TerminArt.schule,
        personen: const [tom],
        start: z(tag(-56), 8),
        ende: z(tag(-56), 13, 15),
        w: const Wiederholung(typ: WiederholungTyp.woechentlich, wochentage: [1, 2, 3, 4, 5]),
        erinnerungen: const [],
      ),
      // Heute: Zahnarzt Anna 15:00
      t(
        id: 'T-zahnarzt',
        titel: 'Zahnarzt',
        art: TerminArt.arzt,
        personen: const [anna],
        start: z(heute, 15),
        ende: z(heute, 16),
        ort: 'Dr. Huber, Hauptstraße 12',
        notiz: 'Versicherungskarte mitnehmen',
        erinnerungen: const [60, 10],
      ),
      // Heute Abend: Familienessen (alle)
      t(
        id: 'T-essen',
        titel: 'Familienessen bei Oma',
        art: TerminArt.termin,
        start: z(heute, 18, 30),
        ende: z(heute, 21),
        ort: 'Oma',
      ),
      // Morgen: Kinderarzt Tom 10:30
      t(
        id: 'T-kinderarzt',
        titel: 'Kinderarzt – Impfung',
        art: TerminArt.arzt,
        personen: const [tom, ich],
        start: z(heute.add(const Duration(days: 1)), 10, 30),
        ende: z(heute.add(const Duration(days: 1)), 11, 15),
        ort: 'Dr. Lang',
        erstelltVon: anna,
      ),
      // Donnerstag: Elternabend 19:30
      t(
        id: 'T-elternabend',
        titel: 'Elternabend',
        art: TerminArt.schule,
        personen: const [anna, ich],
        start: z(tag(3), 19, 30),
        ende: z(tag(3), 21),
        ort: 'Volksschule, Klasse 3b',
      ),
      // Samstag: Fußballturnier Tom
      t(
        id: 'T-fussball',
        titel: 'Fußballturnier',
        art: TerminArt.termin,
        personen: const [tom, ich],
        start: z(tag(5), 9),
        ende: z(tag(5), 13),
        ort: 'Sportplatz Nord',
      ),
      // Ich: Urlaub nächste Woche Mo–Fr (ganztägig)
      t(
        id: 'T-urlaub-ich',
        titel: 'Urlaub',
        art: TerminArt.urlaub,
        personen: const [ich],
        start: z(tag(7), 0),
        ende: z(tag(12), 0),
        ganztaegig: true,
        erinnerungen: const [1440],
      ),
      // Alle: Sommerurlaub Italien
      t(
        id: 'T-urlaub-alle',
        titel: 'Sommerurlaub Italien',
        art: TerminArt.urlaub,
        start: utcVon(beispielZone, heute.year + (heute.month > 7 ? 1 : 0), 8, 3),
        ende: utcVon(beispielZone, heute.year + (heute.month > 7 ? 1 : 0), 8, 15),
        ganztaegig: true,
        ort: 'Gardasee',
        erinnerungen: const [10080],
      ),
      // Lisa: Urlaub in drei Wochen
      t(
        id: 'T-urlaub-lisa',
        titel: 'Kurztrip Wien',
        art: TerminArt.urlaub,
        personen: const [lisa],
        start: z(tag(18), 0),
        ende: z(tag(21), 0),
        ganztaegig: true,
        listId: wg,
        erstelltVon: lisa,
      ),
      // Geburtstag Anna jährlich (übermorgen)
      t(
        id: 'T-geb-anna',
        titel: 'Annas Geburtstag',
        art: TerminArt.geburtstag,
        start: z(heute.add(const Duration(days: 2)), 0),
        ende: z(heute.add(const Duration(days: 3)), 0),
        ganztaegig: true,
        w: const Wiederholung(typ: WiederholungTyp.jaehrlich),
        erinnerungen: const [1440],
      ),
      // Geburtstag Tom jährlich (in 5 Monaten)
      t(
        id: 'T-geb-tom',
        titel: 'Toms Geburtstag',
        art: TerminArt.geburtstag,
        start: utcVon(beispielZone, heute.year, heute.month + 5, 12),
        ende: utcVon(beispielZone, heute.year, heute.month + 5, 13),
        ganztaegig: true,
        w: const Wiederholung(typ: WiederholungTyp.jaehrlich),
      ),
      // WG: Putzplan Mia Sonntag
      t(
        id: 'T-wg-putzen',
        titel: 'Putzdienst Küche',
        art: TerminArt.sonstiges,
        personen: const [mia, lisa],
        start: z(tag(6), 10),
        ende: z(tag(6), 11),
        listId: wg,
        erstelltVon: lisa,
        w: const Wiederholung(typ: WiederholungTyp.woechentlich, intervall: 2),
      ),
      // Mittwoch: Zahnarztkontrolle Lisa (Konfliktkandidat zur Frühschicht)
      t(
        id: 'T-lisa-arzt',
        titel: 'Hautarzt',
        art: TerminArt.arzt,
        personen: const [lisa],
        start: z(tag(2), 16),
        ende: z(tag(2), 16, 45),
        listId: wg,
        erstelltVon: lisa,
      ),
    ];
  }

  static List<TodoModel> aufgaben(DateTime heute) {
    final montag = wochenanfang(heute);
    return [
      TodoModel(
        id: 'A1',
        title: 'Geschenk für Anna besorgen',
        description: '',
        createdAt: DateTime.utc(2026, 1, 2),
        dueDate: utcVon(beispielZone, heute.year, heute.month, heute.day + 1, 18),
        userId: ich,
        listId: familie,
        assignedToUserId: ich,
      ),
      TodoModel(
        id: 'A2',
        title: 'Impfpass suchen',
        description: '',
        createdAt: DateTime.utc(2026, 1, 2),
        dueDate: utcVon(beispielZone, heute.year, heute.month, heute.day, 20),
        userId: anna,
        listId: familie,
        assignedToUserId: anna,
      ),
      TodoModel(
        id: 'A3',
        title: 'Mietvertrag unterschreiben',
        description: '',
        createdAt: DateTime.utc(2026, 1, 2),
        dueDate: utcVon(beispielZone, montag.year, montag.month, montag.day + 4, 12),
        userId: lisa,
        listId: wg,
        isCompleted: true,
      ),
    ];
  }

  static SpeicherTerminRepository repository(DateTime heute) =>
      SpeicherTerminRepository(termine: termine(heute), aufgaben: aufgaben(heute));
}

/// Listen-Zugriff nur fürs Lesen der Beispiel-Listen.
class BeispielListRepository implements ListRepository {
  BeispielListRepository([List<ListModel>? listen]) : _listen = listen ?? Beispiel.listen();

  final List<ListModel> _listen;

  @override
  Future<List<ListModel>> getUserLists(String userId) async => _listen
      .where((l) => l.ownerId == userId || l.memberIds.contains(userId))
      .toList();

  @override
  Future<ListModel?> getListById(String listId) async =>
      _listen.where((l) => l.id == listId).firstOrNull;

  @override
  Stream<ListModel?> getListByIdStream(String listId) => Stream.fromFuture(getListById(listId));

  @override
  Future<ListModel> createList({
    required String name,
    required String ownerId,
    required String ownerName,
    required ListType type,
    bool allowEdit = true,
  }) => throw UnimplementedError();

  @override
  Future<ListModel> updateList(ListModel list) => throw UnimplementedError();

  @override
  Future<void> deleteList(String listId, String ownerId) => throw UnimplementedError();

  @override
  Future<void> leaveList(String listId, String userId) => throw UnimplementedError();

  @override
  Future<ListPreview> previewListByCode(String code) => throw UnimplementedError();

  @override
  Future<ListModel> joinListByCode({required String code, required String userName}) =>
      throw UnimplementedError();
}
