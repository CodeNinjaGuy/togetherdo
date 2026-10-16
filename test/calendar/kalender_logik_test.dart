/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/calendar/logic/freie_zeiten.dart';
import 'package:togetherdo/calendar/logic/ical.dart';
import 'package:togetherdo/calendar/logic/konflikte.dart';
import 'package:togetherdo/calendar/logic/wiederholung.dart';
import 'package:togetherdo/calendar/logic/zeit.dart';
import 'package:togetherdo/calendar/models/termin.dart';

const zone = 'Europe/Vienna';

Termin termin({
  String id = 'T1',
  required DateTime start,
  required DateTime ende,
  TerminArt art = TerminArt.termin,
  List<String> personen = const [],
  bool ganztaegig = false,
  Wiederholung? w,
  List<int> erinnerungen = const [],
}) => Termin(
  id: id,
  listId: 'L1',
  titel: 'Test',
  art: art,
  personen: personen,
  start: start,
  ende: ende,
  ganztaegig: ganztaegig,
  zeitzone: zone,
  wiederholung: w,
  erinnerungen: erinnerungen,
  erstelltVon: 'u1',
);

void main() {
  setUpAll(kalenderZeitInit);

  group('Zeit', () {
    test('Wanduhrzeit → UTC berücksichtigt Sommerzeit', () {
      expect(utcVon(zone, 2026, 1, 15, 6), DateTime.utc(2026, 1, 15, 5));
      expect(utcVon(zone, 2026, 7, 15, 6), DateTime.utc(2026, 7, 15, 4));
    });

    test('Tagesschlüssel in Ortszeit', () {
      // 23:30 UTC am 1.7. ist in Wien schon der 2.7.
      expect(tagSchluessel(DateTime.utc(2026, 7, 1, 23, 30), zone), '2026-07-02');
    });
  });

  group('Wiederholung', () {
    test('Einzeltermin: ein Vorkommen, nur bei Überlappung', () {
      final t = termin(
        start: DateTime.utc(2026, 10, 20, 13),
        ende: DateTime.utc(2026, 10, 20, 14),
      );
      expect(vorkommenIm(t, DateTime.utc(2026, 10, 20), DateTime.utc(2026, 10, 21)), hasLength(1));
      expect(vorkommenIm(t, DateTime.utc(2026, 10, 21), DateTime.utc(2026, 10, 22)), isEmpty);
      expect(sichtbarBis(t), t.ende);
    });

    test('Frühschicht Mo–Fr 6–14 bleibt über die Sommerzeit hinweg 6 Uhr Ortszeit', () {
      // Start Mo 2026-03-23 06:00 MEZ (= 05:00 UTC). Umstellung 2026-03-29.
      final t = termin(
        start: utcVon(zone, 2026, 3, 23, 6),
        ende: utcVon(zone, 2026, 3, 23, 14),
        art: TerminArt.arbeit,
        w: const Wiederholung(typ: WiederholungTyp.woechentlich, wochentage: [1, 2, 3, 4, 5]),
      );
      final v = vorkommenIm(t, DateTime.utc(2026, 3, 23), DateTime.utc(2026, 4, 4));
      expect(v, hasLength(10));
      // Vor der Umstellung 05:00 UTC …
      expect(v.first.start, DateTime.utc(2026, 3, 23, 5));
      // … nach der Umstellung 04:00 UTC, also weiterhin 06:00 Ortszeit.
      final mo30 = v.firstWhere((x) => lokal(x.start, zone).day == 30);
      expect(mo30.start, DateTime.utc(2026, 3, 30, 4));
      expect(lokal(mo30.start, zone).hour, 6);
      expect(lokal(mo30.ende, zone).hour, 14);
      // Wochenende frei.
      expect(v.where((x) => x.start.weekday >= 6), isEmpty);
    });

    test('Umstellung auf Winterzeit 2026-10-25: 6 Uhr bleibt 6 Uhr', () {
      final t = termin(
        start: utcVon(zone, 2026, 10, 19, 6),
        ende: utcVon(zone, 2026, 10, 19, 14),
        w: const Wiederholung(typ: WiederholungTyp.taeglich),
      );
      final v = vorkommenIm(t, DateTime.utc(2026, 10, 24), DateTime.utc(2026, 10, 27));
      for (final x in v) {
        expect(lokal(x.start, zone).hour, 6, reason: x.start.toString());
      }
      expect(v.map((x) => x.start.hour).toSet(), {4, 5});
    });

    test('Ganztägig mehrtägig (Urlaub) wiederholt sich jährlich mit richtiger Länge', () {
      final t = termin(
        start: utcVon(zone, 2026, 8, 3),
        ende: utcVon(zone, 2026, 8, 11),
        ganztaegig: true,
        art: TerminArt.urlaub,
        w: const Wiederholung(typ: WiederholungTyp.jaehrlich, anzahl: 3),
      );
      final v = vorkommenIm(t, DateTime.utc(2026), DateTime.utc(2040));
      expect(v, hasLength(3));
      expect(lokal(v[1].start, zone).year, 2027);
      expect(v[1].ende, utcVon(zone, 2027, 8, 11));
      expect(sichtbarBis(t), utcVon(zone, 2028, 8, 11));
    });

    test('Monatlich am 31. überspringt kurze Monate; Intervall und bisDatum', () {
      final t = termin(
        start: utcVon(zone, 2026, 1, 31, 10),
        ende: utcVon(zone, 2026, 1, 31, 11),
        w: Wiederholung(
          typ: WiederholungTyp.monatlich,
          intervall: 1,
          bisDatum: utcVon(zone, 2026, 6, 30),
        ),
      );
      final v = vorkommenIm(t, DateTime.utc(2026), DateTime.utc(2027));
      expect(v.map((x) => lokal(x.start, zone).month).toList(), [1, 3, 5]);
    });

    test('Ausnahmen werden übersprungen, zählen aber zur Anzahl', () {
      final t = termin(
        start: utcVon(zone, 2026, 10, 19, 9),
        ende: utcVon(zone, 2026, 10, 19, 10),
        w: const Wiederholung(
          typ: WiederholungTyp.taeglich,
          anzahl: 4,
          ausnahmen: ['2026-10-20'],
        ),
      );
      final v = vorkommenIm(t, DateTime.utc(2026, 10), DateTime.utc(2026, 11));
      expect(v.map((x) => lokal(x.start, zone).day).toList(), [19, 21, 22]);
    });

    test('Wöchentlich alle 2 Wochen ab Startwoche', () {
      final t = termin(
        start: utcVon(zone, 2026, 10, 14, 18), // Mittwoch
        ende: utcVon(zone, 2026, 10, 14, 19),
        w: const Wiederholung(typ: WiederholungTyp.woechentlich, intervall: 2),
      );
      final v = vorkommenIm(t, DateTime.utc(2026, 10), DateTime.utc(2026, 12));
      expect(v.map((x) => lokal(x.start, zone).day).take(3).toList(), [14, 28, 11]);
    });

    test('Endlose Serie ist bis 2200 sichtbar', () {
      final t = termin(
        start: utcVon(zone, 2026, 10, 14, 18),
        ende: utcVon(zone, 2026, 10, 14, 19),
        w: const Wiederholung(typ: WiederholungTyp.woechentlich),
      );
      expect(sichtbarBis(t), terminUnendlich);
    });

    test('Nächste Erinnerung: 30 min vor dem nächsten Vorkommen, Schlüssel stabil', () {
      final t = termin(
        start: utcVon(zone, 2026, 10, 19, 9),
        ende: utcVon(zone, 2026, 10, 19, 10),
        erinnerungen: const [30, 0],
        w: const Wiederholung(typ: WiederholungTyp.taeglich),
      );
      final e = naechsteErinnerung(t, DateTime.utc(2026, 10, 19, 6))!;
      expect(e.zeitpunkt, DateTime.utc(2026, 10, 19, 6, 30));
      expect(e.minuten, 30);
      expect(e.schluessel, '2026-10-19T07:00:00.000Z|30');
      final e2 = naechsteErinnerung(t, e.zeitpunkt)!;
      expect(e2.minuten, 0);
      expect(e2.zeitpunkt, DateTime.utc(2026, 10, 19, 7));
      final e3 = naechsteErinnerung(t, e2.zeitpunkt)!;
      expect(e3.zeitpunkt, DateTime.utc(2026, 10, 20, 6, 30));
    });

    test('Keine Erinnerung nach dem letzten Vorkommen', () {
      final t = termin(
        start: DateTime.utc(2026, 10, 19, 7),
        ende: DateTime.utc(2026, 10, 19, 8),
        erinnerungen: const [10],
      );
      expect(naechsteErinnerung(t, DateTime.utc(2026, 10, 19, 7)), isNull);
      expect(abgeleiteteFelder(t, jetzt: DateTime.utc(2026, 10, 1))['naechsteErinnerungAm'],
          DateTime.utc(2026, 10, 19, 6, 50));
    });
  });

  group('Freie Zeiten', () {
    test('findet gemeinsame Lücken zwischen Terminen zweier Personen', () {
      final a = termin(
        id: 'A',
        personen: ['anna'],
        start: utcVon(zone, 2026, 10, 20, 8),
        ende: utcVon(zone, 2026, 10, 20, 12),
      );
      final b = termin(
        id: 'B',
        personen: ['lisa'],
        start: utcVon(zone, 2026, 10, 20, 15),
        ende: utcVon(zone, 2026, 10, 20, 17),
      );
      final c = termin(
        id: 'C',
        personen: ['papa'],
        start: utcVon(zone, 2026, 10, 20, 12),
        ende: utcVon(zone, 2026, 10, 20, 13),
      );
      final von = utcVon(zone, 2026, 10, 20);
      final bis = utcVon(zone, 2026, 10, 21);
      final vorkommen = [a, b, c].expand((t) => vorkommenIm(t, von, bis));
      final frei = freieZeitfenster(
        vorkommen: vorkommen,
        personen: {'anna', 'lisa'},
        von: von,
        bis: bis,
        mindestDauer: const Duration(hours: 1),
        zeitzone: zone,
        tagVon: 8,
        tagBis: 20,
      );
      expect(frei, [
        Zeitfenster(utcVon(zone, 2026, 10, 20, 12), utcVon(zone, 2026, 10, 20, 15)),
        Zeitfenster(utcVon(zone, 2026, 10, 20, 17), utcVon(zone, 2026, 10, 20, 20)),
      ]);
    });

    test('Termine für „alle“ blockieren jede Person; Mindestdauer filtert', () {
      final alle = termin(
        start: utcVon(zone, 2026, 10, 20, 8),
        ende: utcVon(zone, 2026, 10, 20, 19, 30),
      );
      final von = utcVon(zone, 2026, 10, 20);
      final bis = utcVon(zone, 2026, 10, 21);
      final frei = freieZeitfenster(
        vorkommen: vorkommenIm(alle, von, bis),
        personen: {'x'},
        von: von,
        bis: bis,
        mindestDauer: const Duration(hours: 1),
        zeitzone: zone,
        tagVon: 8,
        tagBis: 20,
      );
      expect(frei, isEmpty);
    });

    test('verschmelzen fasst überlappende Fenster zusammen', () {
      final f = verschmelzen([
        Zeitfenster(DateTime.utc(2026, 1, 1, 10), DateTime.utc(2026, 1, 1, 12)),
        Zeitfenster(DateTime.utc(2026, 1, 1, 11), DateTime.utc(2026, 1, 1, 13)),
        Zeitfenster(DateTime.utc(2026, 1, 1, 14), DateTime.utc(2026, 1, 1, 15)),
      ]);
      expect(f, hasLength(2));
      expect(f.first.ende, DateTime.utc(2026, 1, 1, 13));
    });
  });

  group('Konflikte', () {
    final urlaub = termin(
      id: 'U',
      art: TerminArt.urlaub,
      ganztaegig: true,
      personen: ['papa'],
      start: utcVon(zone, 2026, 8, 3),
      ende: utcVon(zone, 2026, 8, 11),
    );
    final schicht = termin(
      id: 'S',
      art: TerminArt.arbeit,
      personen: ['lisa'],
      start: utcVon(zone, 2026, 8, 3, 6),
      ende: utcVon(zone, 2026, 8, 3, 14),
      w: const Wiederholung(typ: WiederholungTyp.woechentlich, wochentage: [1, 2, 3, 4, 5]),
    );

    test('Urlaub und Schicht werden gemeldet, Urlaub zuerst', () {
      final neu = termin(
        id: 'N',
        personen: ['papa', 'lisa'],
        start: utcVon(zone, 2026, 8, 5, 10),
        ende: utcVon(zone, 2026, 8, 5, 11),
      );
      final k = findeKonflikte(neu: neu, vorhandene: [urlaub, schicht], mitglieder: ['papa', 'lisa', 'anna']);
      expect(k.map((x) => '${x.personId}:${x.art.name}').toList(), ['papa:urlaub', 'lisa:belegt']);
    });

    test('„alle“ trifft jedes Mitglied; Geburtstage und gleiche ganztägige Art zählen nicht', () {
      final neu = termin(
        id: 'N',
        start: utcVon(zone, 2026, 8, 5, 10),
        ende: utcVon(zone, 2026, 8, 5, 11),
      );
      final k = findeKonflikte(neu: neu, vorhandene: [urlaub], mitglieder: ['papa', 'anna']);
      expect(k, hasLength(1));
      final geb = termin(id: 'G', art: TerminArt.geburtstag, ganztaegig: true,
          start: utcVon(zone, 2026, 8, 5), ende: utcVon(zone, 2026, 8, 6));
      expect(findeKonflikte(neu: neu, vorhandene: [geb], mitglieder: ['papa']), isEmpty);
      final urlaub2 = urlaub.copyWith(id: 'U2', personen: ['papa'], start: utcVon(zone, 2026, 8, 5), ende: utcVon(zone, 2026, 8, 6));
      expect(findeKonflikte(neu: urlaub2, vorhandene: [urlaub], mitglieder: ['papa']), isEmpty);
    });
  });

  group('iCal', () {
    test('Serie mit RRULE, EXDATE, Alarm und Faltung', () {
      final t = termin(
        start: utcVon(zone, 2026, 10, 19, 6),
        ende: utcVon(zone, 2026, 10, 19, 14),
        art: TerminArt.arbeit,
        erinnerungen: const [15],
        w: Wiederholung(
          typ: WiederholungTyp.woechentlich,
          wochentage: const [1, 2, 3, 4, 5],
          bisDatum: utcVon(zone, 2026, 12, 31),
          ausnahmen: const ['2026-10-26'],
        ),
      ).copyWith(titel: 'Frühschicht; mit Komma, und ' * 4, ort: 'Werk 2');
      final ics = terminAlsIcs(t);
      expect(ics, contains('BEGIN:VCALENDAR\r\n'));
      expect(ics, contains('DTSTART:20261019T040000Z'));
      expect(ics, contains('RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20261231T225959Z'));
      // Ausnahme am 26.10. (Winterzeit): 06:00 Ortszeit = 05:00 UTC.
      expect(ics, contains('EXDATE:20261026T050000Z'));
      expect(ics, contains('TRIGGER:-PT15M'));
      expect(ics, contains('LOCATION:Werk 2'));
      expect(ics, contains('\\;'));
      for (final zeile in ics.split('\r\n')) {
        expect(zeile.length, lessThanOrEqualTo(75), reason: zeile);
      }
    });

    test('Ganztägig als VALUE=DATE', () {
      final t = termin(
        start: utcVon(zone, 2026, 8, 3),
        ende: utcVon(zone, 2026, 8, 11),
        ganztaegig: true,
      );
      final ics = terminAlsIcs(t);
      expect(ics, contains('DTSTART;VALUE=DATE:20260803'));
      expect(ics, contains('DTEND;VALUE=DATE:20260811'));
    });
  });
}
