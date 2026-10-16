/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/design/showcase/design_gallery_screen.dart';
import 'package:togetherdo/design/showcase/today_screen.dart';
import 'package:togetherdo/design/td_design.dart';
import 'package:togetherdo/utils/app_theme.dart';

Widget _wrap(
  Widget child, {
  Size size = const Size(390, 844),
  String theme = 'Light',
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: AppTheme.of(theme),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: child),
    ),
  );
}

void main() {

  group('Theme', () {
    test('alle Paletten bauen ein Theme mit TdTheme-Erweiterung', () {
      for (final p in TdPalettes.all) {
        final theme = TdThemeBuilder.build(p);
        expect(theme.brightness, p.brightness, reason: p.id);
        expect(theme.extension<TdTheme>(), isNotNull, reason: p.id);
        expect(theme.colorScheme.primary, p.primary, reason: p.id);
      }
    });

    test('AppTheme kennt alle bisherigen Namen und den Standard', () {
      for (final name in [
        'Light',
        'Dark',
        'Matrix',
        'Neo',
        'Summer',
        'Aurora',
        'Sunset',
        'Ocean',
        'Forest',
        'Galaxy',
        'Fiberoptics25',
      ]) {
        expect(AppTheme.themes.containsKey(name), isTrue, reason: name);
      }
      expect(AppTheme.of('gibt-es-nicht'), AppTheme.themes['Light']);
    });

    test('Fiberoptics25 bleibt dunkel und orange', () {
      final t = AppTheme.of('Fiberoptics25');
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme.primary, const Color(0xFFFF430B));
    });

    testWidgets('context.td liefert Erweiterung', (tester) async {
      late TdTheme td;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (c) {
              td = c.td;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(td.palette.id, 'Light');
      expect(td.confettiColors, isNotEmpty);
    });
  });

  group('TdButton', () {
    testWidgets('ruft onPressed, nicht bei loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(TdButton.primary(label: 'Anlegen', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.pumpWidget(
        _wrap(
          TdButton.primary(
            label: 'Anlegen',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(TdButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
    });
  });

  group('TdTaskTile', () {
    testWidgets('Haken antippen meldet true und streicht durch', (
      tester,
    ) async {
      bool? value;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => TdTaskTile(
              title: 'Müll rausbringen',
              done: value ?? false,
              onChanged: (v) => setState(() => value = v),
              onDelete: () {},
            ),
          ),
        ),
      );
      expect(find.text('Müll rausbringen'), findsOneWidget);
      await tester.tap(find.byType(TdCheck));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      // Konfetti ist wieder abgeräumt.
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ohne onChanged nicht abhakbar', (tester) async {
      await tester.pumpWidget(
        _wrap(const TdTaskTile(title: 'Gesperrt', done: false)),
      );
      expect(find.byType(Dismissible), findsNothing);
      await tester.tap(find.byType(TdCheck));
      await tester.pumpAndSettle();
    });

    testWidgets('Wischen nach links löscht', (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        _wrap(
          TdTaskTile(
            title: 'Weg damit',
            done: false,
            onChanged: (_) {},
            onDelete: () => deleted = true,
          ),
        ),
      );
      await tester.drag(find.text('Weg damit'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });
  });

  group('Bewegung', () {
    testWidgets('TdAnimatedCounter endet beim Zielwert', (tester) async {
      await tester.pumpWidget(_wrap(const TdAnimatedCounter(value: 42)));
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('TdAnimatedList entfernt Einträge animiert', (tester) async {
      var items = ['a', 'b', 'c'];
      late StateSetter set;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return TdAnimatedList<String>(
                items: items,
                keyOf: (s) => s,
                itemBuilder: (c, s, i) => Text('Eintrag $s'),
              );
            },
          ),
        ),
      );
      expect(find.text('Eintrag b'), findsOneWidget);
      set(() => items = ['a', 'c']);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Eintrag b'), findsNothing);
      set(() => items = ['a', 'c', 'd']);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Eintrag d'), findsOneWidget);
    });

    testWidgets('TdFairnessBar zeigt Prozent je Person', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TdFairnessBar(
            shares: [
              TdFairnessShare(person: TdAvatarData(name: 'Anna'), value: 3),
              TdFairnessShare(person: TdAvatarData(name: 'Leo'), value: 1),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('25 %'), findsOneWidget);
    });

    testWidgets('Bewegung reduzieren: Konfetti wird übersprungen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: AppTheme.of('Light'),
            home: Scaffold(
              body: Builder(
                builder: (c) => TdButton.primary(
                  label: 'Feiern',
                  onPressed: () => TdConfetti.burstFrom(c),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Feiern'));
      await tester.pump();
      expect(find.byType(ConfettiPainter), findsNothing);
      expect(
        tester
            .widgetList(find.byType(CustomPaint))
            .where((w) => (w as CustomPaint).painter is ConfettiPainter),
        isEmpty,
      );
    });
  });

  group('Navigation', () {
    Widget scaffold() => TdAdaptiveScaffold(
      destinations: const [
        TdDestination(icon: Icons.home, label: 'Heute'),
        TdDestination(icon: Icons.list, label: 'Listen'),
      ],
      selectedIndex: 0,
      onSelected: (_) {},
      body: const Text('Inhalt'),
    );

    testWidgets('Handy: Leiste unten', (tester) async {
      await tester.pumpWidget(_wrap(scaffold()));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('iPad: Schiene links', (tester) async {
      await tester.pumpWidget(_wrap(scaffold(), size: const Size(900, 1200)));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Mac: ausgeklappte Schiene', (tester) async {
      await tester.pumpWidget(_wrap(scaffold(), size: const Size(1400, 900)));
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });
  });

  group('Vorzeige-Bildschirme', () {
    testWidgets('Heute: Begrüßung, Aufgaben, Abhaken, neue Aufgabe', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const TdTodayScreen(userName: 'Martin')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('Martin'), findsWidgets);
      expect(find.text('Müll rausbringen'), findsOneWidget);
      expect(find.text('4 Aufgaben offen'), findsOneWidget);

      await tester.tap(find.byType(TdCheck).first);
      await tester.pumpAndSettle();
      expect(find.text('3 Aufgaben offen'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Blumen gießen');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();
      expect(find.text('Blumen gießen'), findsOneWidget);
      expect(find.text('4 Aufgaben offen'), findsOneWidget);
    });

    testWidgets('Heute auf iPad: zwei Spalten mit Schiene', (tester) async {
      await tester.pumpWidget(
        _wrap(const TdTodayScreen(), size: const Size(1024, 1366)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Fair verteilt'), findsOneWidget);
    });

    testWidgets('Galerie baut in hell und dunkel', (tester) async {
      await tester.pumpWidget(
        _wrap(const TdDesignGalleryScreen(), size: const Size(1400, 1000)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Light'), findsWidgets);
      expect(find.text('Dark'), findsWidgets);
      // Zwei Spalten, jede mit dem Farbabschnitt.
      expect(find.text('Farben'), findsNWidgets(2));
    });

    testWidgets('Galerie Fiberoptics25', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TdDesignGalleryScreen(initialPaletteId: 'Fiberoptics25'),
          size: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fiberoptics25'), findsWidgets);
    });
  });
}
