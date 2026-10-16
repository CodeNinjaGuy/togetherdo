/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Eigener Einstieg für den Kalender mit Beispielfamilie, ohne Firebase und
// ohne Anmeldung (Screenshots, Entwurf, Prüfung der Bewegungen):
//   flutter run -t lib/calendar/main_kalender.dart
// Schalter: --dart-define=KAL_DUNKEL=true (sonst wie System), --dart-define=KAL_SPRACHE=en
//           --dart-define=KAL_HEUTE=2026-10-16 (festes „Heute“ für Screenshots)
//           --dart-define=KAL_ANSICHT=monat (spuren | agenda | monat | jahr)

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../design/attachments/td_attachments.dart';
import '../l10n/app_localizations.dart';
import '../repositories/anhang_repository.dart';
import '../utils/app_theme.dart';
import 'demo/beispiel_familie.dart';
import 'bloc/kalender_cubit.dart';
import 'logic/zeit.dart';
import 'screens/calendar_screen.dart';

const bool _dunkel = bool.fromEnvironment('KAL_DUNKEL');
const String _sprache = String.fromEnvironment('KAL_SPRACHE', defaultValue: 'de');
const String _heuteText = String.fromEnvironment('KAL_HEUTE');
const String _ansichtText = String.fromEnvironment('KAL_ANSICHT', defaultValue: 'spuren');

void main() {
  kalenderZeitInit();
  runApp(const KalenderDemoApp());
}

class KalenderDemoApp extends StatelessWidget {
  const KalenderDemoApp({super.key, this.heute, this.dunkel, this.sprache});

  final DateTime? heute;
  final bool? dunkel;
  final String? sprache;

  @override
  Widget build(BuildContext context) {
    final heuteTag = heute ??
        (_heuteText.isNotEmpty ? nurTag(DateTime.parse(_heuteText)) : nurTag(DateTime.now()));
    final dark = dunkel ?? _dunkel;
    // Ohne Vorgabe folgt die Demo dem System (Simulator: `simctl ui … appearance dark`).
    return MaterialApp(
      title: 'ToGetherDo Kalender',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of('Light'),
      darkTheme: AppTheme.of('Dark'),
      themeMode: dark ? ThemeMode.dark : ThemeMode.system,
      locale: Locale(sprache ?? _sprache),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: CalendarScreen(
        userId: Beispiel.ich,
        termine: Beispiel.repository(heuteTag),
        listen: BeispielListRepository(),
        anhaenge: FakeAttachmentService(),
        anhangRepository: MockAnhangRepository(),
        heute: heuteTag,
        eingebettet: true,
        startAnsicht: KalenderAnsicht.values.firstWhere(
          (a) => a.name == _ansichtText,
          orElse: () => KalenderAnsicht.spuren,
        ),
      ),
    );
  }
}
