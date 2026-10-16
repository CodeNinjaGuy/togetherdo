/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Tests für die Schnelleingabe des Kalenders: Titel, Art, Personen, Zeiten
// und Wiederholungen auf Deutsch und Englisch.

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/calendar/logic/schnelleingabe_parser.dart';
import 'package:togetherdo/calendar/models/termin.dart';

/// Bezugszeit: Freitag, 16. Oktober 2026, 10:00.
final jetzt = DateTime(2026, 10, 16, 10, 0);
const mitgliederDe = ['Anna', 'Lisa', 'Papa', 'Mama'];
const mitgliederEn = ['Anna', 'Lisa', 'Dad', 'Mom'];

SchnelleingabeErgebnis de(String text, {DateTime? wann}) =>
    zerlegeSchnelleingabe(text, jetzt: wann ?? jetzt, mitglieder: mitgliederDe);

SchnelleingabeErgebnis en(String text, {DateTime? wann}) =>
    zerlegeSchnelleingabe(
      text,
      jetzt: wann ?? jetzt,
      mitglieder: mitgliederEn,
      sprache: 'en',
    );

void main() {
  group('Deutsch: Beispiele aus der Vorgabe', () {
    test('Zahnarzt Anna Dienstag 15 Uhr', () {
      final e = de('Zahnarzt Anna Dienstag 15 Uhr');
      expect(e.titel, 'Zahnarzt');
      expect(e.art, TerminArt.arzt);
      expect(e.personenNamen, ['Anna']);
      expect(e.start, DateTime(2026, 10, 20, 15, 0));
      expect(e.ende, DateTime(2026, 10, 20, 16, 0));
      expect(e.ganztaegig, isFalse);
      expect(e.wiederholung, isNull);
      expect(e.unbekannt, isEmpty);
    });

    test('Papa Urlaub 3. bis 10. August (nächstes Jahr, Ende exklusiv)', () {
      final e = de('Papa Urlaub 3. bis 10. August');
      expect(e.titel, 'Urlaub');
      expect(e.art, TerminArt.urlaub);
      expect(e.personenNamen, ['Papa']);
      expect(e.start, DateTime(2027, 8, 3));
      expect(e.ende, DateTime(2027, 8, 11));
      expect(e.ganztaegig, isTrue);
    });

    test('Lisa Frühschicht Mo–Fr 6–14 Uhr', () {
      final e = de('Lisa Frühschicht Mo–Fr 6–14 Uhr');
      expect(e.titel, 'Frühschicht');
      expect(e.art, TerminArt.arbeit);
      expect(e.personenNamen, ['Lisa']);
      expect(e.start, DateTime(2026, 10, 19, 6, 0));
      expect(e.ende, DateTime(2026, 10, 19, 14, 0));
      expect(e.ganztaegig, isFalse);
      expect(e.wiederholung?.typ, WiederholungTyp.woechentlich);
      expect(e.wiederholung?.wochentage, [1, 2, 3, 4, 5]);
    });

    test('Elternabend Kita Donnerstag 19:30 2 Stunden', () {
      final e = de('Elternabend Kita Donnerstag 19:30 2 Stunden');
      expect(e.titel, 'Elternabend Kita');
      expect(e.art, TerminArt.schule);
      expect(e.start, DateTime(2026, 10, 22, 19, 30));
      expect(e.ende, DateTime(2026, 10, 22, 21, 30));
    });

    test('Omas Geburtstag 12.3. jährlich', () {
      final e = de('Omas Geburtstag 12.3. jährlich');
      expect(e.titel, 'Omas Geburtstag');
      expect(e.art, TerminArt.geburtstag);
      expect(e.ganztaegig, isTrue);
      expect(e.start, DateTime(2027, 3, 12));
      expect(e.ende, DateTime(2027, 3, 13));
      expect(e.wiederholung?.typ, WiederholungTyp.jaehrlich);
      expect(e.unbekannt, ['Omas']);
      expect(e.personenNamen, isEmpty);
    });
  });

  group('Deutsch: Uhrzeiten', () {
    test('nur Uhrzeit heute in der Zukunft → heute', () {
      final e = de('Telefonat 15:00 Uhr');
      expect(e.titel, 'Telefonat');
      expect(e.start, DateTime(2026, 10, 16, 15, 0));
      expect(e.ende, DateTime(2026, 10, 16, 16, 0));
      expect(e.ganztaegig, isFalse);
    });

    test('nur Uhrzeit, heute schon vorbei → morgen', () {
      final e = de('Telefonat 9 Uhr');
      expect(e.start, DateTime(2026, 10, 17, 9, 0));
    });

    test('Schreibvariante 15h', () {
      expect(de('Besprechung 15h').start, DateTime(2026, 10, 16, 15, 0));
    });

    test('Schreibvariante um 15', () {
      final e = de('Besprechung um 15');
      expect(e.start, DateTime(2026, 10, 16, 15, 0));
      expect(e.titel, 'Besprechung');
    });

    test('halb 3 → 14:30', () {
      expect(de('Kaffee halb 3').start, DateTime(2026, 10, 16, 14, 30));
    });

    test('um 3 → 15 Uhr, um 9 → 9 Uhr, 3 Uhr morgens bleibt 3', () {
      expect(de('Abholen um 3').start, DateTime(2026, 10, 16, 15, 0));
      expect(de('Abholen um 9 morgen').start, DateTime(2026, 10, 17, 9, 0));
      final frueh = de('Flug morgen 3 Uhr früh');
      expect(frueh.start, DateTime(2026, 10, 17, 3, 0));
      expect(frueh.titel, 'Flug');
    });

    test('von 8 bis 12 und 8-12', () {
      final a = de('Workshop von 8 bis 12');
      expect(
        a.start,
        DateTime(2026, 10, 16, 8, 0).add(const Duration(days: 1)),
      );
      expect(a.ende, DateTime(2026, 10, 17, 12, 0));
      expect(a.titel, 'Workshop');
      final b = de('Workshop Montag 8-12');
      expect(b.start, DateTime(2026, 10, 19, 8, 0));
      expect(b.ende, DateTime(2026, 10, 19, 12, 0));
    });

    test('Dauer 30 Minuten und 1,5 Stunden', () {
      final a = de('Anruf 11 Uhr 30 Minuten');
      expect(a.ende, DateTime(2026, 10, 16, 11, 30));
      final b = de('Training Dienstag 18 Uhr 1,5 Stunden');
      expect(b.ende, DateTime(2026, 10, 20, 19, 30));
      expect(b.titel, 'Training');
    });

    test('Uhrzeit mit Punkt „9.30 Uhr“ ist keine Datumsangabe', () {
      final e = de('Frühstück morgen 9.30 Uhr');
      expect(e.start, DateTime(2026, 10, 17, 9, 30));
      expect(e.titel, 'Frühstück');
    });
  });

  group('Deutsch: Datum', () {
    test('3.8. ohne Jahr liegt zurück → nächstes Jahr', () {
      final e = de('Grillfest 3.8.');
      expect(e.start, DateTime(2027, 8, 3));
      expect(e.ende, DateTime(2027, 8, 4));
      expect(e.ganztaegig, isTrue);
    });

    test('03.08.2026 mit Jahr bleibt in der Vergangenheit', () {
      expect(de('Grillfest 03.08.2026').start, DateTime(2026, 8, 3));
    });

    test('3. August mit Uhrzeit', () {
      final e = de('Konzert 3. August 20 Uhr');
      expect(e.start, DateTime(2027, 8, 3, 20, 0));
      expect(e.ende, DateTime(2027, 8, 3, 21, 0));
      expect(e.titel, 'Konzert');
    });

    test('Jahreswechsel im Dezember: 5. Januar → nächstes Jahr', () {
      final dez = DateTime(2026, 12, 20, 9, 0);
      final e = de('Skikurs 5. Januar', wann: dez);
      expect(e.start, DateTime(2027, 1, 5));
    });

    test('Bereich über den Jahreswechsel: 28.12. bis 3.1.', () {
      final e = de('Urlaub 28.12. bis 3.1.');
      expect(e.start, DateTime(2026, 12, 28));
      expect(e.ende, DateTime(2027, 1, 4));
      expect(e.art, TerminArt.urlaub);
    });

    test('Bereich kurz „3.–10.8.“ und „vom 3. bis 10. August“', () {
      final a = de('Ferien 3.–10.8.');
      expect(a.start, DateTime(2027, 8, 3));
      expect(a.ende, DateTime(2027, 8, 11));
      final b = de('Mama Urlaub vom 3. bis 10. August');
      expect(b.start, DateTime(2027, 8, 3));
      expect(b.ende, DateTime(2027, 8, 11));
      expect(b.personenNamen, ['Mama']);
      expect(b.titel, 'Urlaub');
    });

    test('heute, morgen, übermorgen, in 3 Tagen', () {
      expect(de('Putzen heute').start, DateTime(2026, 10, 16));
      expect(de('Putzen morgen').start, DateTime(2026, 10, 17));
      expect(de('Putzen übermorgen').start, DateTime(2026, 10, 18));
      expect(de('Putzen in 3 Tagen').start, DateTime(2026, 10, 19));
      expect(de('Putzen in drei Tagen').titel, 'Putzen');
    });

    test('nächste Woche → Montag; nächste Woche Mittwoch', () {
      expect(de('Abgabe nächste Woche').start, DateTime(2026, 10, 19));
      expect(de('Abgabe nächste Woche Mittwoch').start, DateTime(2026, 10, 21));
    });

    test('am Wochenende → Samstag ganztägig', () {
      final e = de('Ausflug am Wochenende');
      expect(e.start, DateTime(2026, 10, 17));
      expect(e.ende, DateTime(2026, 10, 18));
      expect(e.titel, 'Ausflug');
    });

    test('Wochentag heute (Freitag) ohne Uhrzeit zählt heute', () {
      expect(de('Pizza Freitag').start, DateTime(2026, 10, 16));
      expect(de('Pizza Freitag 9 Uhr').start, DateTime(2026, 10, 23, 9, 0));
      expect(
        de('Pizza nächsten Freitag 9 Uhr').start,
        DateTime(2026, 10, 23, 9, 0),
      );
    });

    test('Kurzform „Di“ nur großgeschrieben, „so“ bleibt ein Wort', () {
      expect(de('Probe Di 18 Uhr').start, DateTime(2026, 10, 20, 18, 0));
      final e = de('Treffen so gegen 15 Uhr');
      expect(e.start, DateTime(2026, 10, 16, 15, 0));
      expect(e.titel, 'Treffen so gegen');
    });
  });

  group('Deutsch: Wiederholungen', () {
    test('jeden Montag', () {
      final e = de('Klavier jeden Montag 16 Uhr');
      expect(e.wiederholung?.typ, WiederholungTyp.woechentlich);
      expect(e.wiederholung?.wochentage, [1]);
      expect(e.wiederholung?.intervall, 1);
      expect(e.start, DateTime(2026, 10, 19, 16, 0));
      expect(e.titel, 'Klavier');
    });

    test('jeden 2. Dienstag → Intervall 2', () {
      final e = de('Müll jeden 2. Dienstag');
      expect(e.wiederholung?.typ, WiederholungTyp.woechentlich);
      expect(e.wiederholung?.intervall, 2);
      expect(e.wiederholung?.wochentage, [2]);
      expect(e.start, DateTime(2026, 10, 20));
    });

    test('täglich, wöchentlich, monatlich', () {
      expect(
        de('Tabletten täglich 8 Uhr').wiederholung?.typ,
        WiederholungTyp.taeglich,
      );
      final w = de('Putzplan wöchentlich');
      expect(w.wiederholung?.typ, WiederholungTyp.woechentlich);
      expect(w.wiederholung?.wochentage, [5]);
      expect(w.start, DateTime(2026, 10, 16));
      expect(
        de('Miete monatlich').wiederholung?.typ,
        WiederholungTyp.monatlich,
      );
    });

    test('alle 2 Wochen Donnerstag', () {
      final e = de('Biotonne alle 2 Wochen Donnerstag');
      expect(e.wiederholung?.typ, WiederholungTyp.woechentlich);
      expect(e.wiederholung?.intervall, 2);
      expect(e.wiederholung?.wochentage, [4]);
      expect(e.titel, 'Biotonne');
    });

    test('Montag bis Freitag ausgeschrieben, Mo-Fr ohne Uhrzeit', () {
      final a = de('Schule Montag bis Freitag');
      expect(a.wiederholung?.wochentage, [1, 2, 3, 4, 5]);
      expect(a.art, TerminArt.schule);
      expect(a.start, DateTime(2026, 10, 16)); // Freitag zählt ganztägig
      final b = de('Papa Spätschicht Mo-Fr 14-22 Uhr');
      expect(b.wiederholung?.wochentage, [1, 2, 3, 4, 5]);
      expect(b.start, DateTime(2026, 10, 16, 14, 0));
      expect(b.ende, DateTime(2026, 10, 16, 22, 0));
      expect(b.personenNamen, ['Papa']);
    });

    test('Di und Do ohne „jeden“ gilt als wöchentlich', () {
      final e = de('Fußball Di und Do 17 Uhr');
      expect(e.wiederholung?.wochentage, [2, 4]);
      expect(e.start, DateTime(2026, 10, 20, 17, 0));
      expect(e.titel, 'Fußball');
    });
  });

  group('Deutsch: Personen und Titel', () {
    test('nur Titel', () {
      final e = de('Reifen wechseln');
      expect(e.titel, 'Reifen wechseln');
      expect(e.start, isNull);
      expect(e.ende, isNull);
      expect(e.ganztaegig, isTrue);
      expect(e.art, isNull);
      expect(e.personenNamen, isEmpty);
    });

    test('leere Eingabe', () {
      final e = de('   ');
      expect(e.titel, '');
      expect(e.start, isNull);
    });

    test('Anna und Lisa, Groß/Kleinschreibung egal, gebeugt „Annas“', () {
      final a = de('Schwimmen anna und LISA Samstag');
      expect(a.personenNamen, ['Anna', 'Lisa']);
      expect(a.titel, 'Schwimmen');
      expect(a.start, DateTime(2026, 10, 17));
      final b = de('Annas Zahnarzt Montag 10 Uhr');
      expect(b.personenNamen, ['Anna']);
      expect(b.titel, 'Zahnarzt');
      expect(b.art, TerminArt.arzt);
    });

    test('alle → personenNamen leer, Merker alle', () {
      final e = de('Essen mit alle Sonntag 12 Uhr');
      expect(e.alle, isTrue);
      expect(e.personenNamen, isEmpty);
      expect(e.titel, 'Essen');
      expect(e.start, DateTime(2026, 10, 18, 12, 0));
    });

    test('Füllwörter fallen weg, Titel groß am Anfang', () {
      final e = de('treffen mit der Lehrerin am Dienstag um 16 Uhr');
      expect(e.titel, 'Treffen Lehrerin');
      expect(e.start, DateTime(2026, 10, 20, 16, 0));
    });

    test('Spitzname Opa ohne Mitglied → unbekannt, bleibt im Titel', () {
      final e = de('Opa besuchen Sonntag');
      expect(e.unbekannt, ['Opa']);
      expect(e.titel, 'Opa besuchen');
    });

    test('„um 9 am Dienstag“: am ist Füllwort, Dienstag ist kein Dienst', () {
      final e = de('Zahnarzttermin um 9 am Dienstag');
      expect(e.titel, 'Zahnarzttermin');
      expect(e.art, TerminArt.arzt);
      expect(e.start, DateTime(2026, 10, 20, 9, 0));
      expect(de('Dienstag 15 Uhr').art, isNull);
    });

    test('zwei Namen ohne „und“, Spitzname ohne Mitglied mit Uhrzeit', () {
      final a = de('Anna Lisa Kino Samstag 20 Uhr');
      expect(a.personenNamen, ['Anna', 'Lisa']);
      expect(a.titel, 'Kino');
      final b = de('Kaffee mit Oma 15 Uhr');
      expect(b.unbekannt, ['Oma']);
      expect(b.titel, 'Kaffee Oma');
      expect(b.start, DateTime(2026, 10, 16, 15, 0));
    });

    test('ISO-Datum und „jeden Montag und Mittwoch“', () {
      expect(de('Urlaub 2026-12-24').start, DateTime(2026, 12, 24));
      final e = de('Sport jeden Montag und Mittwoch 18:00');
      expect(e.wiederholung?.wochentage, [1, 3]);
      expect(e.start, DateTime(2026, 10, 19, 18, 0));
      expect(e.titel, 'Sport');
    });

    test('Mitglied mit Spitznamen Mama wird erkannt', () {
      final e = de('Mama Arzt Mittwoch 8:15');
      expect(e.personenNamen, ['Mama']);
      expect(e.unbekannt, isEmpty);
      expect(e.art, TerminArt.arzt);
      expect(e.start, DateTime(2026, 10, 21, 8, 15));
    });
  });

  group('Englisch', () {
    test('Dentist Anna Tuesday 3 pm', () {
      final e = en('Dentist Anna Tuesday 3 pm');
      expect(e.titel, 'Dentist');
      expect(e.art, TerminArt.arzt);
      expect(e.personenNamen, ['Anna']);
      expect(e.start, DateTime(2026, 10, 20, 15, 0));
      expect(e.ende, DateTime(2026, 10, 20, 16, 0));
    });

    test('Dad vacation Aug 3 to Aug 10', () {
      final e = en('Dad vacation Aug 3 to Aug 10');
      expect(e.titel, 'Vacation');
      expect(e.art, TerminArt.urlaub);
      expect(e.personenNamen, ['Dad']);
      expect(e.start, DateTime(2027, 8, 3));
      expect(e.ende, DateTime(2027, 8, 11));
      expect(e.ganztaegig, isTrue);
    });

    test('Lisa early shift Mon–Fri 6–14', () {
      final e = en('Lisa early shift Mon–Fri 6–14');
      expect(e.titel, 'Early shift');
      expect(e.art, TerminArt.arbeit);
      expect(e.personenNamen, ['Lisa']);
      expect(e.start, DateTime(2026, 10, 19, 6, 0));
      expect(e.ende, DateTime(2026, 10, 19, 14, 0));
      expect(e.wiederholung?.wochentage, [1, 2, 3, 4, 5]);
    });

    test('Team meeting every Monday 9:00 for 90 minutes', () {
      final e = en('Team meeting every Monday 9:00 for 90 minutes');
      expect(e.titel, 'Team meeting');
      expect(e.wiederholung?.typ, WiederholungTyp.woechentlich);
      expect(e.wiederholung?.wochentage, [1]);
      expect(e.start, DateTime(2026, 10, 19, 9, 0));
      expect(e.ende, DateTime(2026, 10, 19, 10, 30));
      expect(e.unbekannt, isEmpty);
    });

    test('3:15pm, 9am, at 9, half past 3', () {
      expect(en('Call 3:15pm').start, DateTime(2026, 10, 16, 15, 15));
      expect(en('Call tomorrow 9am').start, DateTime(2026, 10, 17, 9, 0));
      expect(en('Call at 9').start, DateTime(2026, 10, 17, 9, 0));
      expect(en('Call half past 3').start, DateTime(2026, 10, 16, 15, 30));
    });

    test('from 3 to 10 August, 3rd of August, August 3rd 2026', () {
      final a = en('Camp from 3 to 10 August');
      expect(a.start, DateTime(2027, 8, 3));
      expect(a.ende, DateTime(2027, 8, 11));
      expect(a.titel, 'Camp');
      expect(en('Camp 3rd of August').start, DateTime(2027, 8, 3));
      expect(en('Camp August 3rd, 2026').start, DateTime(2026, 8, 3));
    });

    test('today, tomorrow, next Tuesday, this weekend, in 2 weeks', () {
      expect(en('Laundry today').start, DateTime(2026, 10, 16));
      expect(en('Laundry tomorrow').start, DateTime(2026, 10, 17));
      expect(en('Laundry next Tuesday').start, DateTime(2026, 10, 20));
      expect(en('Hike this weekend').start, DateTime(2026, 10, 17));
      expect(en('Dentist in 2 weeks').start, DateTime(2026, 10, 30));
    });

    test('daily, weekly, monthly, yearly, every weekday, every other week', () {
      expect(
        en('Pills daily 8 am').wiederholung?.typ,
        WiederholungTyp.taeglich,
      );
      expect(
        en('Report weekly').wiederholung?.typ,
        WiederholungTyp.woechentlich,
      );
      expect(en('Rent monthly').wiederholung?.typ, WiederholungTyp.monatlich);
      final b = en('Mom birthday March 12 yearly');
      expect(b.wiederholung?.typ, WiederholungTyp.jaehrlich);
      expect(b.art, TerminArt.geburtstag);
      expect(b.personenNamen, ['Mom']);
      expect(b.start, DateTime(2027, 3, 12));
      expect(en('School every weekday').wiederholung?.wochentage, [
        1,
        2,
        3,
        4,
        5,
      ]);
      final o = en('Cleaning every other week');
      expect(o.wiederholung?.typ, WiederholungTyp.woechentlich);
      expect(o.wiederholung?.intervall, 2);
    });

    test('everyone and an unknown capitalised name', () {
      final a = en('Dinner with everyone Sunday 6 pm');
      expect(a.alle, isTrue);
      expect(a.titel, 'Dinner');
      expect(a.start, DateTime(2026, 10, 18, 18, 0));
      final b = en('Dinner with Tom Sunday');
      expect(b.unbekannt, ['Tom']);
      expect(b.titel, 'Dinner Tom');
    });

    test('from 8 to 12 and 3 to 5 pm, for 2 hours', () {
      final a = en('Workshop Monday from 8 to 12');
      expect(a.start, DateTime(2026, 10, 19, 8, 0));
      expect(a.ende, DateTime(2026, 10, 19, 12, 0));
      final b = en('Workshop Monday 3 to 5 pm');
      expect(b.start, DateTime(2026, 10, 19, 15, 0));
      expect(b.ende, DateTime(2026, 10, 19, 17, 0));
      final c = en('Workshop Monday at 10 for 2 hours');
      expect(c.ende, DateTime(2026, 10, 19, 12, 0));
      expect(c.titel, 'Workshop');
    });

    test('on Mondays, Tue and Thu, Dec 24 - 26', () {
      final a = en('Dentist on Mondays 4pm');
      expect(a.wiederholung?.wochentage, [1]);
      expect(a.start, DateTime(2026, 10, 19, 16, 0));
      final b = en('Soccer Tue and Thu 5 pm');
      expect(b.wiederholung?.wochentage, [2, 4]);
      expect(b.start, DateTime(2026, 10, 20, 17, 0));
      final c = en('Trip Dec 24 - 26');
      expect(c.start, DateTime(2026, 12, 24));
      expect(c.ende, DateTime(2026, 12, 27));
      expect(c.titel, 'Trip');
    });

    test('unknown language falls back to English rules', () {
      final e = zerlegeSchnelleingabe(
        'Dentist Anna Tuesday 3 pm',
        jetzt: jetzt,
        mitglieder: mitgliederEn,
        sprache: 'fr',
      );
      expect(e.start, DateTime(2026, 10, 20, 15, 0));
    });
  });
}
