/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

/// Stellt dem Vorzeige-Einstieg (`main_design.dart`) einen Umschalter für
/// Hell/Dunkel und Palette bereit. In der echten App übernimmt das der
/// `ThemeBloc`; dort ist dieser Scope nicht vorhanden (`maybeOf` = null).
class ShowcaseThemeScope extends InheritedWidget {
  const ShowcaseThemeScope({
    super.key,
    required this.isDark,
    required this.paletteId,
    required this.toggleMode,
    required this.setPalette,
    required super.child,
  });

  final bool isDark;
  final String paletteId;
  final VoidCallback toggleMode;
  final ValueChanged<String> setPalette;

  static ShowcaseThemeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShowcaseThemeScope>();

  @override
  bool updateShouldNotify(ShowcaseThemeScope old) =>
      old.isDark != isDark || old.paletteId != paletteId;
}
