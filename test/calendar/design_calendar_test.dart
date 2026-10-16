/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/calendar/models/termin.dart';
import 'package:togetherdo/design/calendar/td_calendar.dart';
import 'package:togetherdo/design/td_design.dart';
import 'package:togetherdo/utils/app_theme.dart';

Widget wrap(Widget child, {bool dunkel = false, bool reduziert = false}) => MediaQuery(
  data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduziert),
  child: MaterialApp(
    theme: AppTheme.of(dunkel ? 'Dark' : 'Light'),
    locale: const Locale('de'),
    supportedLocales: const [Locale('de'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: child),
  ),
);

void main() {
  setUpAll(() => TdTypography.useGoogleFonts = false);

  testWidgets('TdTerminBlock und TdTerminBand zeigen Titel in hell und dunkel', (tester) async {
    for (final dunkel in [false, true]) {
      await tester.pumpWidget(wrap(
        Column(children: [
          const SizedBox(height: 44, width: 200, child: TdTerminBlock(art: TerminArt.arzt, titel: 'Zahnarzt', zeit: '15:00 – 16:00')),
          const SizedBox(width: 200, child: TdTerminBand(art: TerminArt.urlaub, titel: 'Urlaub')),
        ]),
        dunkel: dunkel,
      ));
      expect(find.text('Zahnarzt'), findsOneWidget);
      expect(find.text('Urlaub'), findsOneWidget);
    }
  });

  testWidgets('TdAnsichtUmschalter meldet Auswahl', (tester) async {
    int? gewaehlt;
    await tester.pumpWidget(wrap(TdAnsichtUmschalter(
      index: 0,
      onChanged: (i) => gewaehlt = i,
      eintraege: const [
        TdUmschalterEintrag(label: 'Spuren', icon: Icons.view_timeline_rounded),
        TdUmschalterEintrag(label: 'Agenda', icon: Icons.view_agenda_rounded),
      ],
    )));
    await tester.tap(find.text('Agenda'));
    expect(gewaehlt, 1);
  });

  testWidgets('TdPersonenAuswahl schaltet Personen um, „Alle“ leert', (tester) async {
    final gewaehlt = <String>{'a'};
    String? umgeschaltet;
    var alle = false;
    await tester.pumpWidget(wrap(TdPersonenAuswahl(
      personen: const [TdPerson(id: 'a', name: 'Anna Berg'), TdPerson(id: 'b', name: 'Ben')],
      gewaehlt: gewaehlt,
      alleLabel: 'Alle',
      onAlle: () => alle = true,
      onToggle: (id) => umgeschaltet = id,
    )));
    expect(find.text('Anna'), findsOneWidget);
    await tester.tap(find.text('Ben'));
    expect(umgeschaltet, 'b');
    await tester.tap(find.text('Alle'));
    expect(alle, isTrue);
  });

  testWidgets('TdDatumStreifen wählt Tag; TdMonatsGitter liefert Zelle', (tester) async {
    DateTime? tag;
    Rect? zelle;
    await tester.pumpWidget(wrap(Column(children: [
      TdDatumStreifen(
        gewaehlt: DateTime.utc(2026, 10, 16),
        heute: DateTime.utc(2026, 10, 16),
        onGewaehlt: (t) => tag = t,
        locale: 'de',
      ),
      TdMonatsGitter(
        monat: DateTime.utc(2026, 10, 1),
        heute: DateTime.utc(2026, 10, 16),
        locale: 'de',
        kompakt: true,
        onTagGewaehlt: (t, r) {
          tag = t;
          zelle = r;
        },
      ),
    ])));
    await tester.tap(find.text('19').first); // Montag im Streifen
    expect(tag, DateTime.utc(2026, 10, 19));
    await tester.tap(find.text('31').last);
    expect(tag, DateTime.utc(2026, 10, 31));
    expect(zelle, isNot(Rect.zero));
  });

  testWidgets('TdJetztLinie steht still bei „Bewegung reduzieren“', (tester) async {
    await tester.pumpWidget(wrap(const SizedBox(height: 200, child: TdJetztLinie()), reduziert: true));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(TdJetztLinie), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Datum- und Zeitwähler öffnen und liefern Werte', (tester) async {
    DateTime? datum;
    TimeOfDay? zeit;
    await tester.pumpWidget(wrap(Builder(
      builder: (ctx) => Column(children: [
        TdZeitPille(
          icon: Icons.calendar_today_rounded,
          label: 'Datum',
          onTap: () async {
            datum = await showTdDatumWaehler(ctx,
                gewaehlt: DateTime(2026, 10, 16), heute: DateTime(2026, 10, 16),
                titel: 'Beginn', heuteLabel: 'Heute', morgenLabel: 'Morgen', fertigLabel: 'Fertig', locale: 'de');
          },
        ),
        TdZeitPille(
          icon: Icons.schedule_rounded,
          label: 'Zeit',
          onTap: () async {
            zeit = await showTdZeitWaehler(ctx,
                gewaehlt: const TimeOfDay(hour: 9, minute: 0), titel: 'Beginn', fertigLabel: 'Fertig');
          },
        ),
      ]),
    )));
    await tester.tap(find.text('Datum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morgen'));
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(datum, DateTime.utc(2026, 10, 17));
    await tester.tap(find.text('Zeit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15:00'));
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(zeit, const TimeOfDay(hour: 15, minute: 0));
  });
}
