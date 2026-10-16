/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/calendar/logic/monatsvorschau.dart';
import 'package:togetherdo/calendar/logic/zeit.dart';
import 'package:togetherdo/calendar/models/termin.dart';

import 'beispiel_zustand.dart';

void main() {
  setUpAll(kalenderZeitInit);

  group('Monatsvorschau Oktober 2026', () {
    final z = beispielZustand();
    final v = berechneMonatsvorschau(zustand: z, monat: DateTime.utc(2026, 10, 1));

    test('freie Wochenenden: alle außer 24./25. (Familienfest)', () {
      expect(
        v.freieWochenenden,
        [
          DateTime.utc(2026, 10, 3),
          DateTime.utc(2026, 10, 10),
          DateTime.utc(2026, 10, 17),
          DateTime.utc(2026, 10, 31),
        ],
      );
    });

    test('Highlights: Geburtstag und Arzt, keine Arbeit, sortiert', () {
      final arten = v.highlights.map((h) => h.art).toList();
      expect(arten, [TerminArt.geburtstag, TerminArt.arzt]);
      expect(v.highlights.first.erster, DateTime.utc(2026, 10, 5));
      expect(v.highlights.first.personen, ['u2']);
      expect(v.highlights.any((h) => h.art == TerminArt.arbeit), isFalse);
    });

    test('unterwegs: Martin 22 Arbeitstage × 8 h, Ben ein Termin', () {
      final martin = v.unterwegs.firstWhere((u) => u.mitglied.id == 'u1');
      expect(martin.arbeitsstunden, 22 * 8);
      expect(martin.urlaubstage, 0);
      expect(martin.termine, 1); // Familienfest (für alle)
      final ben = v.unterwegs.firstWhere((u) => u.mitglied.id == 'u3');
      expect(ben.termine, 2); // Zahnarzt + Familienfest
      expect(v.unterwegs.map((u) => u.mitglied.id), ['u1', 'u2', 'u3', 'u4']);
    });

    test('Dichte: Montage als Schlüssel, Werte 0..1, vollste Woche = 1', () {
      expect(v.dichte.keys.every((k) => k.weekday == DateTime.monday), isTrue);
      expect(v.dichte.values.every((w) => w >= 0 && w <= 1), isTrue);
      expect(v.dichte.values.reduce((a, b) => a > b ? a : b), 1.0);
      expect(v.dichte.containsKey(DateTime.utc(2026, 9, 28)), isTrue);
      expect(v.dichte.containsKey(DateTime.utc(2026, 10, 26)), isTrue);
    });

    test('kein gemeinsamer Urlaub im Oktober, nicht „ruhig“', () {
      expect(v.gemeinsamerUrlaub, isEmpty);
      expect(v.ruhig, isFalse);
    });
  });

  group('Monatsvorschau August 2026', () {
    final z = beispielZustand();
    final v = berechneMonatsvorschau(zustand: z, monat: DateTime.utc(2026, 8, 1));

    test('Urlaubstage je Person', () {
      int tage(String id) => v.unterwegs.firstWhere((u) => u.mitglied.id == id).urlaubstage;
      expect(tage('u1'), 7);
      expect(tage('u2'), 9);
      expect(tage('u3'), 5);
      expect(tage('u4'), 5);
    });

    test('alle frei 12.–16. August, Urlaube als Highlights', () {
      expect(v.gemeinsamerUrlaub, [Zeitraum(DateTime.utc(2026, 8, 12), DateTime.utc(2026, 8, 16))]);
      expect(v.gemeinsamerUrlaub.single.tage, 5);
      expect(v.highlights.where((h) => h.art == TerminArt.urlaub), hasLength(3));
      expect(v.highlights.first.mehrtaegig, isTrue);
    });

    test('Wochenende 15./16. ist nicht frei (Urlaub zählt als belegt)', () {
      expect(v.freieWochenenden.contains(DateTime.utc(2026, 8, 15)), isFalse);
      expect(v.freieWochenenden.contains(DateTime.utc(2026, 8, 1)), isTrue);
    });
  });

  group('gemeinsamerUrlaub', () {
    test('über die Jahresgrenze wird je Jahr beschnitten', () {
      final z = beispielZustand(
        termine: [
          ganztags(
            id: 'W',
            titel: 'Weihnachten',
            von: DateTime.utc(2026, 12, 28),
            bis: DateTime.utc(2027, 1, 3),
          ),
        ],
      );
      expect(gemeinsamerUrlaub(z, 2026), [
        Zeitraum(DateTime.utc(2026, 12, 28), DateTime.utc(2026, 12, 31)),
      ]);
      expect(gemeinsamerUrlaub(z, 2027), [
        Zeitraum(DateTime.utc(2027, 1, 1), DateTime.utc(2027, 1, 3)),
      ]);
    });

    test('nur wenn wirklich alle Urlaub haben; Personenfilter zählt', () {
      final z = beispielZustand();
      expect(gemeinsamerUrlaub(z, 2026), hasLength(1));
      final nurMartinAnna = z.copyWith(personenFilter: {'u1', 'u2'});
      expect(gemeinsamerUrlaub(nurMartinAnna, 2026), [
        Zeitraum(DateTime.utc(2026, 8, 12), DateTime.utc(2026, 8, 16)),
      ]);
      final nurAnna = z.copyWith(personenFilter: {'u2'});
      expect(gemeinsamerUrlaub(nurAnna, 2026), [
        Zeitraum(DateTime.utc(2026, 8, 12), DateTime.utc(2026, 8, 20)),
      ]);
    });

    test('ruhiger Monat ohne Einträge', () {
      final z = beispielZustand(termine: const []);
      final v = berechneMonatsvorschau(zustand: z, monat: DateTime.utc(2026, 3, 1));
      expect(v.ruhig, isTrue);
      expect(v.freieWochenenden, hasLength(4));
      expect(v.dichte.values.every((w) => w == 0), isTrue);
    });
  });
}
