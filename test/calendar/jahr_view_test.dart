/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/calendar/views/jahr_view.dart';
import 'package:togetherdo/calendar/widgets/feiertags_region_wahl.dart';
import 'package:togetherdo/calendar/widgets/monatsvorschau_karte.dart';
import 'package:togetherdo/design/td_design.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/utils/app_theme.dart';

import 'beispiel_zustand.dart';

final heute = DateTime.utc(2026, 10, 16);

Widget _wrap(
  Widget child, {
  Size size = const Size(390, 844),
  String theme = 'Light',
  bool reduced = false,
}) => MediaQuery(
  data: MediaQueryData(size: size, disableAnimations: reduced),
  child: MaterialApp(
    theme: AppTheme.of(theme),
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  ),
);

void main() {
  setUpAll(() {
    TdTypography.useGoogleFonts = false;
  });

  group('JahrView', () {
    for (final (theme, size) in [
      ('Light', const Size(390, 844)),
      ('Dark', const Size(390, 844)),
      ('Light', const Size(1024, 768)),
      ('Dark', const Size(1024, 768)),
    ]) {
      testWidgets('baut $theme bei ${size.width.toInt()} px', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _wrap(
            JahrView(
              zustand: beispielZustand(feiertagsRegion: 'AT-9'),
              onMonat: (_, _) {},
              onZeitraum: (_, _) {},
              heute: heute,
            ),
            size: size,
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('2026'), findsOneWidget);
        expect(find.byKey(const Key('jahr-band')), findsOneWidget);
        expect(find.byKey(const Key('jahr-monat-1')), findsOneWidget);
        // Gemeinsamer Urlaub 12.–16. Aug. als Chip.
        expect(find.textContaining('12.–16. Aug'), findsOneWidget);
      });
    }

    testWidgets('Tipp auf einen Monat ruft onMonat mit Monat und Rechteck', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      DateTime? monat;
      Rect? rect;
      await tester.pumpWidget(
        _wrap(
          JahrView(
            zustand: beispielZustand(),
            onMonat: (m, r) {
              monat = m;
              rect = r;
            },
            onZeitraum: (_, _) {},
            heute: heute,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final kachel = find.byKey(const Key('jahr-monat-8'));
      await tester.ensureVisible(kachel);
      await tester.pumpAndSettle();
      await tester.tap(kachel);
      await tester.pumpAndSettle();
      expect(monat, DateTime.utc(2026, 8, 1));
      expect(rect, isNotNull);
      expect(rect!.width, greaterThan(50));
    });

    testWidgets('zwei Tipps im Jahresband wählen einen Zeitraum', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      DateTime? von;
      DateTime? bis;
      await tester.pumpWidget(
        _wrap(
          JahrView(
            zustand: beispielZustand(),
            onMonat: (_, _) {},
            onZeitraum: (a, b) {
              von = a;
              bis = b;
            },
            heute: heute,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final band = tester.getRect(find.byKey(const Key('jahr-band')));
      final y = band.center.dy;
      // Erster Tipp links (Frühjahr), zweiter weiter rechts.
      await tester.tapAt(Offset(band.left + 100, y));
      await tester.pumpAndSettle();
      expect(find.textContaining('Anfang gewählt'), findsOneWidget);
      expect(von, isNull);
      await tester.tapAt(Offset(band.left + 160, y));
      await tester.pumpAndSettle();
      expect(von, isNotNull);
      expect(bis, isNotNull);
      expect(bis!.isAfter(von!), isTrue);
      expect(von!.year, 2026);
      expect(find.textContaining('Anfang gewählt'), findsNothing);
    });

    testWidgets('Lange drücken und ziehen wählt einen Zeitraum (auch rückwärts)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      DateTime? von;
      DateTime? bis;
      await tester.pumpWidget(
        _wrap(
          JahrView(
            zustand: beispielZustand(),
            onMonat: (_, _) {},
            onZeitraum: (a, b) {
              von = a;
              bis = b;
            },
            heute: heute,
          ),
          size: const Size(1024, 768),
        ),
      );
      await tester.pumpAndSettle();
      final band = tester.getRect(find.byKey(const Key('jahr-band')));
      final y = band.center.dy;
      final g = await tester.startGesture(Offset(band.left + 600, y));
      await tester.pump(const Duration(milliseconds: 700));
      await g.moveTo(Offset(band.left + 500, y));
      await tester.pump();
      expect(find.textContaining('Urlaub:'), findsOneWidget);
      await g.up();
      await tester.pumpAndSettle();
      expect(von, isNotNull);
      expect(bis!.isAfter(von!), isTrue);
      expect(bis!.difference(von!).inDays, greaterThan(20));
    });

    testWidgets('Pfeil wechselt das Jahr; reduzierte Bewegung baut ohne Fehler', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          JahrView(
            zustand: beispielZustand(),
            onMonat: (_, _) {},
            onZeitraum: (_, _) {},
            heute: heute,
          ),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nächstes Jahr'));
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);
      expect(find.text('2026'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('MonatsvorschauKarte', () {
    testWidgets('zeigt freie Wochenenden als Chips und meldet den Samstag', (tester) async {
      DateTime? tag;
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: MonatsvorschauKarte(
              zustand: beispielZustand(),
              monat: DateTime.utc(2026, 10, 1),
              heute: heute,
              onTag: (t) => tag = t,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Was kommt im Oktober'), findsOneWidget);
      expect(find.text('3./4.'), findsOneWidget);
      expect(find.text('10./11.'), findsOneWidget);
      expect(find.text('24./25.'), findsNothing);
      expect(find.textContaining('Zahnarzt Ben'), findsOneWidget);
      expect(find.textContaining('176 Std. Arbeit'), findsOneWidget);
      await tester.tap(find.text('3./4.'));
      await tester.pumpAndSettle();
      expect(tag, DateTime.utc(2026, 10, 3));
    });

    testWidgets('ruhiger Monat', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MonatsvorschauKarte(
            zustand: beispielZustand(termine: const []),
            monat: DateTime.utc(2026, 3, 1),
            heute: heute,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ruhiger Monat'), findsOneWidget);
    });
  });

  group('FeiertagsRegionWahl', () {
    testWidgets('Land wählen setzt Standardregion und zeigt Bundesländer', (tester) async {
      String? gewaehlt = 'AT-9';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setState) => FeiertagsRegionWahl(
              region: gewaehlt,
              onChanged: (r) => setState(() => gewaehlt = r),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Wien'), findsOneWidget);
      await tester.tap(find.text('Deutschland'));
      await tester.pumpAndSettle();
      expect(gewaehlt, 'DE-BE');
      expect(find.text('Bayern'), findsOneWidget);
      await tester.tap(find.text('Bayern'));
      await tester.pumpAndSettle();
      expect(gewaehlt, 'DE-BY');
      await tester.tap(find.text('Keine'));
      await tester.pumpAndSettle();
      expect(gewaehlt, isNull);
      expect(find.text('Bayern'), findsNothing);
    });
  });
}
