/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/calendar/bloc/kalender_cubit.dart';
import 'package:togetherdo/calendar/demo/beispiel_familie.dart';
import 'package:togetherdo/calendar/logic/zeit.dart';
import 'package:togetherdo/calendar/models/termin.dart';
import 'package:togetherdo/calendar/screens/calendar_screen.dart';
import 'package:togetherdo/calendar/services/verfuegbarkeit.dart';
import 'package:togetherdo/calendar/widgets/heute_kalender_karte.dart';
import 'package:togetherdo/calendar/widgets/mail_einstellungen.dart';
import 'package:togetherdo/design/attachments/td_attachments.dart';
import 'package:togetherdo/design/td_design.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/utils/app_theme.dart';

/// Ein Freitag; die Beispielfamilie legt ihre Woche darum herum an.
final heute = DateTime.utc(2026, 10, 16);

Widget wrap(Widget child, {Size size = const Size(390, 844), bool dunkel = false}) =>
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: AppTheme.of(dunkel ? 'Dark' : 'Light'),
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: child,
      ),
    );

CalendarScreen bildschirm() => CalendarScreen(
  userId: Beispiel.ich,
  termine: Beispiel.repository(heute),
  listen: BeispielListRepository(),
  anhaenge: FakeAttachmentService(),
  heute: heute,
  jetzt: utcVon(beispielZone, 2026, 10, 16, 11, 20),
  eingebettet: true,
);

void main() {
  setUpAll(() {
    TdTypography.useGoogleFonts = false;
    kalenderZeitInit();
  });

  group('Cubit', () {
    test('lädt Listen, Mitglieder und Termine; Filter wirken', () async {
      final cubit = KalenderCubit(
        userId: Beispiel.ich,
        termine: Beispiel.repository(heute),
        listen: BeispielListRepository(),
        heute: heute,
        zeitzone: beispielZone,
      );
      await cubit.starten();
      await Future<void>.delayed(Duration.zero);
      final z = cubit.state;
      expect(z.listen, hasLength(2));
      expect(z.mitglieder.map((m) => m.name), containsAll(['Markus', 'Anna', 'Lisa', 'Tom', 'Mia']));
      expect(z.mitglieder.first.id, Beispiel.ich, reason: 'ich zuerst');
      expect(z.termine, isNotEmpty);
      final von = utcVon(beispielZone, 2026, 10, 16);
      final bis = utcVon(beispielZone, 2026, 10, 17);
      final heuteVorkommen = z.vorkommen(von, bis);
      expect(heuteVorkommen.map((v) => v.termin.titel), containsAll(['Zahnarzt', 'Familienessen bei Oma', 'Frühschicht']));
      cubit.artUmschalten(TerminArt.arzt);
      expect(cubit.state.vorkommen(von, bis).map((v) => v.termin.titel).toList(), ['Zahnarzt']);
      cubit.artenFilterLeeren();
      cubit.personUmschalten(Beispiel.tom);
      final tomHeute = cubit.state.vorkommen(von, bis).map((v) => v.termin.titel).toList();
      expect(tomHeute, contains('Schule'));
      expect(tomHeute, contains('Familienessen bei Oma'), reason: '„alle“ zählt für Tom');
      expect(tomHeute, isNot(contains('Zahnarzt')));
      cubit.listeUmschalten(Beispiel.wg);
      expect(cubit.state.aktiveListen, {Beispiel.familie});
      expect(z.darfBearbeiten(z.termine.firstWhere((t) => t.id == 'T-kinderarzt')), isTrue, reason: 'Besitzer der Liste');
      final konflikte = cubit.konflikte(
        Termin(
          id: 'neu', listId: Beispiel.familie, titel: 'Test', personen: const [Beispiel.anna],
          start: utcVon(beispielZone, 2026, 10, 16, 15, 30), ende: utcVon(beispielZone, 2026, 10, 16, 16, 30),
          erstelltVon: Beispiel.ich,
        ),
      );
      expect(konflikte.map((k) => k.vorkommen.termin.titel), contains('Zahnarzt'));
      await cubit.close();
    });

    test('Verfügbarkeit: Urlaub macht abwesend', () async {
      final repo = Beispiel.repository(heute);
      final v = Verfuegbarkeit(repository: repo, listIds: [Beispiel.familie, Beispiel.wg], zeitzone: beispielZone);
      // Markus hat ab Montag 19.10. Urlaub.
      expect(await v.abwesend(Beispiel.ich, DateTime(2026, 10, 20)), isTrue);
      expect(await v.abwesend(Beispiel.ich, DateTime(2026, 10, 16)), isFalse);
      expect(await v.abwesend(Beispiel.anna, DateTime(2026, 10, 20)), isFalse);
      // Sommerurlaub „alle“ im August.
      expect(await v.abwesend(Beispiel.tom, DateTime(2027, 8, 5)), isTrue);
    });
  });

  group('CalendarScreen', () {
    testWidgets('Spuren: Personen, Blöcke und Band sichtbar (hell)', (tester) async {
      await tester.pumpWidget(wrap(bildschirm()));
      await tester.pumpAndSettle();
      expect(find.text('Zahnarzt'), findsWidgets);
      expect(find.text('Markus'), findsWidgets);
      expect(find.text('Anna'), findsWidgets);
      expect(find.text('Frühschicht'), findsWidgets);
    });

    testWidgets('Umschalten auf Agenda und Monat (dunkel, iPad)', (tester) async {
      await tester.pumpWidget(wrap(bildschirm(), size: const Size(1024, 1366), dunkel: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Heute'), findsWidgets);
      expect(find.text('Familienessen bei Oma'), findsWidgets);
      expect(find.text('Impfpass suchen'), findsOneWidget, reason: 'Aufgabe mit Fälligkeit');
      await tester.tap(find.text('Monat'));
      await tester.pumpAndSettle();
      expect(find.text('Oktober 2026'), findsWidgets);
    });

    testWidgets('Filter öffnen, Neuer Termin öffnet Formular mit Schnelleingabe', (tester) async {
      await tester.pumpWidget(wrap(bildschirm()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Arten'), findsOneWidget);
      await tester.tap(find.text('Neuer Termin'));
      await tester.pumpAndSettle();
      expect(find.text('Wiederholung'), findsOneWidget);
      // Schnelleingabe zerlegt und füllt das Formular.
      await tester.enterText(find.byType(TextField).first, 'Zahnarzt Anna Dienstag 15 Uhr');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Übernehmen'), findsOneWidget);
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(find.text('15:00'), findsWidgets);
    });

    testWidgets('Detail-Sheet mit Anhängen und Aktionen', (tester) async {
      await tester.pumpWidget(wrap(bildschirm()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zahnarzt').first);
      await tester.pumpAndSettle();
      expect(find.text('Dr. Huber, Hauptstraße 12'), findsOneWidget);
      expect(find.text('Anhänge'), findsOneWidget);
      expect(find.text('Bearbeiten'), findsOneWidget);
    });

    testWidgets('„Wann haben alle Zeit?“ zeigt freie Fenster', (tester) async {
      await tester.pumpWidget(wrap(bildschirm()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Wann haben alle Zeit?'));
      await tester.pumpAndSettle();
      expect(find.text('Dauer'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsWidgets);
    });
  });

  group('Bausteine', () {
    testWidgets('HeuteKalenderKarte zeigt nächste Termine', (tester) async {
      await tester.pumpWidget(wrap(Scaffold(
        body: HeuteKalenderKarte(
          listIds: const [Beispiel.familie, Beispiel.wg],
          repository: Beispiel.repository(heute),
          jetzt: utcVon(beispielZone, 2026, 10, 16, 12),
          onOeffnen: () {},
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Nächste Termine'), findsOneWidget);
      expect(find.text('Zahnarzt'), findsOneWidget);
      expect(find.textContaining('Heute'), findsWidgets);
    });

    testWidgets('MailEinstellungen schaltet um', (tester) async {
      final speicher = SpeicherMailEinstellungen();
      await tester.pumpWidget(wrap(Scaffold(
        body: SingleChildScrollView(child: MailEinstellungen(userId: 'u', speicher: speicher)),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beides'));
      await tester.pumpAndSettle();
      expect(speicher.werte.erinnerungen, 'beide');
    });
  });
}
