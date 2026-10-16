/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../motion/td_page_transitions.dart';
import '../tokens/td_palette.dart';
import '../tokens/td_tokens.dart';
import '../tokens/td_typography.dart';
import 'td_theme.dart';

/// Baut aus einer `TdPalette` das komplette Material-3-Theme.
/// Alle Bausteine der App (auch die Material-Standardwidgets) sehen damit
/// einheitlich aus: große weiche Radien, keine harten Linien, farbig
/// getönte Schatten, ruhige Typografie.
abstract final class TdThemeBuilder {
  static ThemeData build(TdPalette p) {
    final scheme = _scheme(p);
    final text = TdTypography.build(p);
    final td = TdTheme.fromPalette(p);
    final outline = p.outline ?? scheme.outlineVariant;

    final controlShape = RoundedRectangleBorder(
      borderRadius: TdRadius.control,
    );
    const controlPadding = EdgeInsets.symmetric(
      horizontal: TdSpace.xl,
      vertical: TdSpace.lg,
    );
    const controlMinSize = Size(64, 52);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: [td],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TdPageTransitionsBuilder(),
          TargetPlatform.iOS: TdPageTransitionsBuilder(),
          TargetPlatform.macOS: TdPageTransitionsBuilder(),
          TargetPlatform.windows: TdPageTransitionsBuilder(),
          TargetPlatform.linux: TdPageTransitionsBuilder(),
          TargetPlatform.fuchsia: TdPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: TdRadius.card,
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          padding: controlPadding,
          minimumSize: controlMinSize,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: controlShape,
          padding: controlPadding,
          minimumSize: controlMinSize,
          elevation: 0,
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          padding: controlPadding,
          minimumSize: controlMinSize,
          side: BorderSide(color: outline, width: 1.5),
          foregroundColor: p.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          padding: const EdgeInsets.symmetric(
            horizontal: TdSpace.lg,
            vertical: TdSpace.md,
          ),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: controlShape,
          foregroundColor: p.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TdRadius.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.isDark ? p.surfaceElevated : p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TdSpace.lg,
          vertical: TdSpace.lg,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: p.onSurfaceMuted),
        labelStyle: text.bodyMedium?.copyWith(color: p.onSurfaceMuted),
        floatingLabelStyle: text.labelMedium?.copyWith(color: p.primary),
        prefixIconColor: p.onSurfaceMuted,
        suffixIconColor: p.onSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: TdRadius.control,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TdRadius.control,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TdRadius.control,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: TdRadius.control,
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: TdRadius.control,
          borderSide: BorderSide(color: p.danger, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary.withValues(alpha: p.isDark ? 0.28 : 0.14),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TdRadius.pill),
        ),
        labelStyle: text.labelMedium?.copyWith(color: p.onSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: TdSpace.md,
          vertical: TdSpace.sm,
        ),
        showCheckmark: false,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: outline, width: 2),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : null,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : null,
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: TdRadius.control),
        iconColor: p.onSurfaceMuted,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primary.withValues(alpha: p.isDark ? 0.3 : 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TdRadius.pill),
        ),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(
            color: s.contains(WidgetState.selected)
                ? p.primary
                : p.onSurfaceMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? p.primary
                : p.onSurfaceMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: p.isDark ? 0.3 : 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TdRadius.pill),
        ),
        selectedIconTheme: IconThemeData(color: p.primary),
        unselectedIconTheme: IconThemeData(color: p.onSurfaceMuted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: p.primary),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: p.onSurfaceMuted,
        ),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: RoundedRectangleBorder(borderRadius: TdRadius.sheet),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TdRadius.xl),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.surfaceElevated : p.onSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: p.isDark ? p.onSurface : p.background,
        ),
        shape: RoundedRectangleBorder(borderRadius: TdRadius.control),
        elevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: TdRadius.control),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceElevated),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: TdRadius.control),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: outline,
        circularTrackColor: outline,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.onSurface,
          borderRadius: BorderRadius.circular(TdRadius.sm),
        ),
        textStyle: text.labelMedium?.copyWith(color: p.background),
      ),
    );
  }

  static ColorScheme _scheme(TdPalette p) {
    final seeded = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.brightness,
    );
    final outline = p.outline ?? seeded.outlineVariant;
    return seeded.copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primary.withValues(alpha: p.isDark ? 0.28 : 0.14),
      onPrimaryContainer: p.isDark ? p.onSurface : p.primary,
      secondary: p.secondary,
      onSecondary: _on(p.secondary),
      secondaryContainer: p.secondary.withValues(alpha: p.isDark ? 0.28 : 0.16),
      onSecondaryContainer: p.isDark ? p.onSurface : _darken(p.secondary),
      tertiary: p.tertiary,
      onTertiary: _on(p.tertiary),
      tertiaryContainer: p.tertiary.withValues(alpha: p.isDark ? 0.28 : 0.16),
      onTertiaryContainer: p.isDark ? p.onSurface : _darken(p.tertiary),
      error: p.danger,
      onError: _on(p.danger),
      surface: p.surface,
      onSurface: p.onSurface,
      onSurfaceVariant: p.onSurfaceMuted,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceElevated,
      surfaceContainerHighest: p.surfaceElevated,
      outline: Color.lerp(outline, p.onSurfaceMuted, 0.4),
      outlineVariant: outline,
      surfaceTint: Colors.transparent,
    );
  }

  static Color _on(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1C1B22);

  static Color _darken(Color c) =>
      HSLColor.fromColor(c).withLightness(0.28).toColor();
}
