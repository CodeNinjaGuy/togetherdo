/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../design/theme/td_theme_builder.dart';
import '../design/tokens/td_palette.dart';
import '../design/tokens/td_palettes.dart';

/// Alle Themes der App, gebaut aus dem Design-System (`lib/design`).
/// Die Schlüssel sind die gespeicherten Theme-Namen des `ThemeBloc`;
/// `Light` ist der Standard, `Dark` die dunkle Markenvariante.
class AppTheme {
  AppTheme._();

  static final Map<String, ThemeData> themes = {
    for (final TdPalette p in TdPalettes.all) p.id: TdThemeBuilder.build(p),
  };

  static const String defaultTheme = 'Light';

  /// Gespeicherter Name für „wie das System“: hell = [defaultTheme],
  /// dunkel = [darkTheme]; die App folgt dem Gerät.
  static const String systemTheme = 'System';
  static const String darkTheme = 'Dark';

  static bool isSystem(String name) => name == systemTheme;

  static ThemeData of(String name) =>
      themes[name] ?? themes[defaultTheme]!;
}
