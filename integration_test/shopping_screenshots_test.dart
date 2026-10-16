/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Screenshots der Einkaufsliste mit Scanner und Spracheingabe (Demo-Modus,
// ohne Firebase und ohne Kamera), hell und dunkel. Läuft im Simulator.
//
// `takeScreenshot` liefert im iOS-Simulator weiße Bilder und erreicht den
// Treiber erst am Ende. Deshalb legt der Test je Bild eine Markierung
// `shot-<name>.req` im tmp-Ordner der App ab und wartet, bis ein Wächter
// auf dem Mac sie entfernt hat (siehe tool/screenshot_watcher.sh):
//
//   tool/screenshot_watcher.sh <udid> <ablage> &
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/shopping_screenshots_test.dart -d <udid>

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/screens/shopping/shopping_demo_screen.dart';
import 'package:togetherdo/utils/app_theme.dart';

Widget _app(String theme) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.of(theme),
  locale: const Locale('de', 'DE'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
  home: const ShoppingDemoScreen(),
);

/// Lässt echte Zeit vergehen (Übergänge, Netzbilder, Drehbuch-Timer) und
/// baut danach ein paar Bilder.
Future<void> _real(
  WidgetTester tester, [
  Duration d = const Duration(milliseconds: 700),
]) async {
  await tester.runAsync(() => Future<void>.delayed(d));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) => _real(tester);

/// Tippt einen Text an, nachdem er in den sichtbaren Bereich gerollt wurde
/// (Sheets mit Tastatur).
Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await _real(tester, const Duration(milliseconds: 300));
  await tester.tap(finder, warnIfMissed: false);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await _real(tester, const Duration(milliseconds: 300));
    final marker = File('${Directory.systemTemp.path}/shot-$name.req');
    await tester.runAsync(() async {
      await marker.writeAsString(name);
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (marker.existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    });
  }

  for (final (theme, suffix) in [('Light', 'hell'), ('Dark', 'dunkel')]) {
    testWidgets('Einkaufsliste, Scanner, Sprache ($suffix)', (tester) async {
      await tester.pumpWidget(_app(theme));
      await _real(tester, const Duration(seconds: 4));
      await shot(tester, '01-einkaufsliste-$suffix');

      // Scanner (Demo-Kamera) und Treffer-Karte.
      await tester.tap(find.byTooltip('Strichcode scannen').first);
      await _settle(tester);
      await shot(tester, '02-scanner-$suffix');
      await _tapText(tester, 'Demo-Treffer');
      await _real(tester, const Duration(seconds: 3));
      await shot(tester, '03-scanner-treffer-$suffix');
      await _tapText(tester, 'Hinzufügen');
      await _settle(tester);
      await shot(tester, '04-scanner-zaehler-$suffix');
      // Rückmeldung unten ausblenden lassen, sie läge sonst über dem Knopf.
      await _real(tester, const Duration(milliseconds: 2500));

      // Zweiter Code bekannt, dritter unbekannt → benennen.
      await _tapText(tester, 'Demo-Treffer');
      await _real(tester, const Duration(seconds: 2));
      await _tapText(tester, 'Weiter scannen');
      await _settle(tester);
      await _tapText(tester, 'Demo-Treffer');
      await _real(tester, const Duration(seconds: 2));
      await shot(tester, '05-scanner-unbekannt-$suffix');
      await _tapText(tester, 'Weiter scannen');
      await _settle(tester);
      await _tapText(tester, 'Fertig');
      await _settle(tester);

      // Bearbeiten-Sheet (Tippen auf ersten Artikel).
      await _tapText(tester, 'Nutella');
      await _real(tester, const Duration(seconds: 2));
      await shot(tester, '06-bearbeiten-$suffix');
      await _tapText(tester, 'Speichern');
      await _settle(tester);

      // Spracheingabe: zuhören, dann Ergebnis.
      await tester.tap(find.byTooltip('Spracheingabe').first);
      await _real(tester, const Duration(milliseconds: 900));
      await shot(tester, '07-sprache-zuhoeren-$suffix');
      await _real(tester, const Duration(seconds: 3));
      await shot(tester, '08-sprache-ergebnis-$suffix');
      await tester.tap(find.textContaining('Artikel hinzufügen'));
      await _real(tester, const Duration(seconds: 2));
      await shot(tester, '09-einkaufsliste-nach-sprache-$suffix');
    });
  }
}
