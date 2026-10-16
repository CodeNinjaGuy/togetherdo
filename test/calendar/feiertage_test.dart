/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/calendar/logic/feiertage.dart';

bool hat(List<Feiertag> f, String nameDe) => f.any((x) => x.nameDe == nameDe);

DateTime? tagVon(List<Feiertag> f, String nameDe) =>
    f.where((x) => x.nameDe == nameDe).map((x) => x.tag).firstOrNull;

void main() {
  group('Osterformel', () {
    test('Ostersonntag 2026 ist der 5. April, weitere Jahre stimmen', () {
      expect(ostersonntag(2026), DateTime.utc(2026, 4, 5));
      expect(ostersonntag(2024), DateTime.utc(2024, 3, 31));
      expect(ostersonntag(2025), DateTime.utc(2025, 4, 20));
      expect(ostersonntag(2027), DateTime.utc(2027, 3, 28));
    });

    test('bewegliche Feiertage 2026 hängen am Osterdatum', () {
      final at = feiertageIm(2026, 'AT-9');
      expect(tagVon(at, 'Ostermontag'), DateTime.utc(2026, 4, 6));
      expect(tagVon(at, 'Christi Himmelfahrt'), DateTime.utc(2026, 5, 14));
      expect(tagVon(at, 'Pfingstmontag'), DateTime.utc(2026, 5, 25));
      expect(tagVon(at, 'Fronleichnam'), DateTime.utc(2026, 6, 4));
      final de = feiertageIm(2026, 'DE-BY');
      expect(tagVon(de, 'Karfreitag'), DateTime.utc(2026, 4, 3));
    });

    test('Buß- und Bettag ist ein Mittwoch vor dem 23.11.', () {
      expect(bussUndBettag(2026), DateTime.utc(2026, 11, 18));
      expect(bussUndBettag(2026).weekday, DateTime.wednesday);
      expect(hat(feiertageIm(2026, 'DE-SN'), 'Buß- und Bettag'), isTrue);
      expect(hat(feiertageIm(2026, 'DE-BY'), 'Buß- und Bettag'), isFalse);
    });
  });

  group('Österreich', () {
    test('Nationalfeiertag 26.10. und Fronleichnam in allen Ländern', () {
      for (final r in feiertagsRegionen.where((r) => r.land == 'AT')) {
        final f = feiertageIm(2026, r.code);
        expect(tagVon(f, 'Nationalfeiertag'), DateTime.utc(2026, 10, 26), reason: r.code);
        expect(hat(f, 'Fronleichnam'), isTrue, reason: r.code);
        expect(hat(f, 'Karfreitag'), isFalse, reason: r.code);
        expect(hat(f, 'Reformationstag'), isFalse, reason: r.code);
      }
    });

    test('Landesfeiertage: Wien Leopoldi, Kärnten zwei, Anzahl plausibel', () {
      expect(hat(feiertageIm(2026, 'AT-9'), 'Leopolditag'), isTrue);
      expect(hat(feiertageIm(2026, 'AT-1'), 'Leopolditag'), isFalse);
      expect(feiertageIm(2026, 'AT-9'), hasLength(14));
      expect(feiertageIm(2026, 'AT-2'), hasLength(15));
      expect(feiertageIm(2026, 'AT-6'), hasLength(14));
    });
  });

  group('Deutschland', () {
    test('Fronleichnam nur in Teilen, Reformationstag nur im Norden/Osten', () {
      final mitFronleichnam = <String>{};
      final mitReformation = <String>{};
      for (final r in feiertagsRegionen.where((r) => r.land == 'DE')) {
        final f = feiertageIm(2026, r.code);
        if (hat(f, 'Fronleichnam')) mitFronleichnam.add(r.code);
        if (hat(f, 'Reformationstag')) {
          mitReformation.add(r.code);
          expect(tagVon(f, 'Reformationstag'), DateTime.utc(2026, 10, 31));
        }
        // Bundesweit immer dabei.
        expect(tagVon(f, 'Tag der Deutschen Einheit'), DateTime.utc(2026, 10, 3), reason: r.code);
        expect(hat(f, 'Nationalfeiertag'), isFalse, reason: r.code);
      }
      expect(mitFronleichnam, {'DE-BW', 'DE-BY', 'DE-HE', 'DE-NW', 'DE-RP', 'DE-SL'});
      expect(mitReformation, {
        'DE-BB', 'DE-HB', 'DE-HH', 'DE-MV', 'DE-NI', 'DE-SN', 'DE-ST', 'DE-SH', 'DE-TH',
      });
    });

    test('Anzahl je Land plausibel (9 bundesweit, Bayern 12, Berlin 10)', () {
      expect(feiertageIm(2026, 'DE-BE'), hasLength(10));
      expect(feiertageIm(2026, 'DE-BY'), hasLength(12));
      expect(feiertageIm(2026, 'DE-HE'), hasLength(10));
      expect(feiertageIm(2026, 'DE-BB'), hasLength(12));
      for (final r in feiertagsRegionen.where((r) => r.land == 'DE')) {
        final n = feiertageIm(2026, r.code).length;
        expect(n, inInclusiveRange(9, 13), reason: r.code);
      }
    });
  });

  group('Allgemein', () {
    test('Listen sind sortiert, Regionen benannt, unbekannt leer', () {
      for (final r in feiertagsRegionen) {
        final f = feiertageIm(2026, r.code);
        for (var i = 1; i < f.length; i++) {
          expect(f[i].tag.isBefore(f[i - 1].tag), isFalse, reason: r.code);
        }
        expect(f.every((x) => x.tag.year == 2026), isTrue);
        expect(f.every((x) => x.nameEn.isNotEmpty), isTrue);
      }
      expect(feiertagsRegionen, hasLength(25));
      expect(regionName('AT-9'), 'Wien');
      expect(regionName('AT-9', sprache: 'en'), 'Vienna');
      expect(regionName('DE-BY', sprache: 'en'), 'Bavaria');
      expect(regionName('XX-1'), isNull);
      expect(feiertageIm(2026, 'XX-1'), isEmpty);
      expect(ferienIm(2026, 'AT-9'), isEmpty);
      expect(feiertageNachTag(2026, null), isEmpty);
      expect(feiertageNachTag(2026, 'AT-9')[DateTime.utc(2026, 10, 26)]?.nameDe, 'Nationalfeiertag');
    });
  });
}
