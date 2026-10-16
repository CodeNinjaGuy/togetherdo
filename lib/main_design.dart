/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Eigener Einstieg für den Design-Entwurf, ohne Firebase und ohne Anmeldung:
//   flutter run -t lib/main_design.dart
// Zeigt den Startbildschirm „Heute“ mit Beispieldaten und die Galerie.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design/showcase/design_gallery_screen.dart';
import 'design/showcase/showcase_theme_scope.dart';
import 'design/showcase/today_screen.dart';
import 'design/td_design.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const DesignShowcaseApp());
}

class DesignShowcaseApp extends StatefulWidget {
  const DesignShowcaseApp({super.key});

  @override
  State<DesignShowcaseApp> createState() => _DesignShowcaseAppState();
}

class _DesignShowcaseAppState extends State<DesignShowcaseApp> {
  ThemeMode _mode = ThemeMode.system;
  String _lightId = 'Light';
  String _darkId = 'Dark';

  bool _isDark(BuildContext context) => switch (_mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToGetherDo Design',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(_lightId),
      darkTheme: AppTheme.of(_darkId),
      themeMode: _mode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      builder: (context, child) {
        final dark = _isDark(context);
        return ShowcaseThemeScope(
          isDark: dark,
          paletteId: dark ? _darkId : _lightId,
          toggleMode: () =>
              setState(() => _mode = dark ? ThemeMode.light : ThemeMode.dark),
          setPalette: (id) => setState(() {
            final p = TdPalettes.byId(id);
            if (p.isDark) {
              _darkId = id;
              _mode = ThemeMode.dark;
            } else {
              _lightId = id;
              _mode = ThemeMode.light;
            }
          }),
          child: child!,
        );
      },
      home: Builder(
        builder: (context) => TdTodayScreen(
          onOpenGallery: () => Navigator.of(context).push(
            TdPageRoute(
              builder: (_) => TdDesignGalleryScreen(
                initialPaletteId:
                    ShowcaseThemeScope.maybeOf(context)?.paletteId ?? 'Light',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
