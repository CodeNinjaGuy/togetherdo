/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'td_pressable.dart';

enum TdButtonVariant {
  /// Markenverlauf mit Leuchten: die eine Hauptaktion pro Ansicht.
  primary,

  /// Fläche mit Kante.
  secondary,

  /// Getönte Fläche in Markenfarbe.
  tonal,

  /// Nur Text.
  ghost,

  /// Rot getönt, für Löschen.
  danger,
}

enum TdButtonSize { small, medium, large }

/// Knopf der App. Drückt sich beim Antippen leicht ein, zeigt bei
/// `loading` einen Kreis statt des Textes und behält dabei seine Breite.
class TdButton extends StatelessWidget {
  const TdButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = TdButtonVariant.primary,
    this.size = TdButtonSize.medium,
    this.loading = false,
    this.expanded = false,
    this.haptic = true,
  });

  const TdButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = TdButtonSize.medium,
    this.loading = false,
    this.expanded = false,
    this.haptic = true,
  }) : variant = TdButtonVariant.primary;

  const TdButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = TdButtonSize.medium,
    this.loading = false,
    this.expanded = false,
    this.haptic = true,
  }) : variant = TdButtonVariant.secondary;

  const TdButton.tonal({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = TdButtonSize.medium,
    this.loading = false,
    this.expanded = false,
    this.haptic = true,
  }) : variant = TdButtonVariant.tonal;

  const TdButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = TdButtonSize.medium,
    this.loading = false,
    this.expanded = false,
    this.haptic = false,
  }) : variant = TdButtonVariant.ghost;

  const TdButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = TdButtonSize.medium,
    this.loading = false,
    this.expanded = false,
    this.haptic = true,
  }) : variant = TdButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final TdButtonVariant variant;
  final TdButtonSize size;
  final bool loading;
  final bool expanded;
  final bool haptic;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    final text = context.text;

    final (height, hPad, textStyle, iconSize) = switch (size) {
      TdButtonSize.small => (40.0, TdSpace.lg, text.labelMedium, 18.0),
      TdButtonSize.medium => (52.0, TdSpace.xl, text.labelLarge, 20.0),
      TdButtonSize.large => (
        58.0,
        TdSpace.xxl,
        text.labelLarge?.copyWith(fontSize: 16),
        22.0,
      ),
    };

    Color fg;
    BoxDecoration decoration;
    switch (variant) {
      case TdButtonVariant.primary:
        fg = td.palette.onPrimary;
        decoration = BoxDecoration(
          gradient: td.primaryGradient,
          borderRadius: TdRadius.control,
          boxShadow: _enabled ? TdShadows.glow(scheme.primary) : null,
        );
      case TdButtonVariant.secondary:
        fg = scheme.onSurface;
        decoration = BoxDecoration(
          color: scheme.surface,
          borderRadius: TdRadius.control,
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        );
      case TdButtonVariant.tonal:
        fg = scheme.onPrimaryContainer;
        decoration = BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: TdRadius.control,
        );
      case TdButtonVariant.ghost:
        fg = scheme.primary;
        decoration = BoxDecoration(borderRadius: TdRadius.control);
      case TdButtonVariant.danger:
        fg = td.danger;
        decoration = BoxDecoration(
          color: td.danger.withValues(alpha: td.isDark ? 0.22 : 0.1),
          borderRadius: TdRadius.control,
        );
    }

    final labelWidget = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: fg),
          const SizedBox(width: TdSpace.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: textStyle?.copyWith(color: fg),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
    final child = AnimatedOpacity(
      duration: TdMotion.fast,
      opacity: _enabled || loading ? 1 : 0.45,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: decoration,
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: TdMotion.of(context, TdMotion.base),
          switchInCurve: TdMotion.standard,
          switchOutCurve: TdMotion.exit,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.0).animate(a),
              child: c,
            ),
          ),
          child: loading
              ? Stack(
                  key: const ValueKey('loading'),
                  alignment: Alignment.center,
                  children: [
                    // Unsichtbarer Text hält die Breite.
                    Opacity(opacity: 0, child: labelWidget),
                    SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: fg,
                      ),
                    ),
                  ],
                )
              : KeyedSubtree(key: const ValueKey('label'), child: labelWidget),
        ),
      ),
    );

    return TdPressable(
      onTap: _enabled ? onPressed : null,
      enabled: _enabled,
      haptic: haptic,
      semanticLabel: label,
      borderRadius: TdRadius.control,
      child: child,
    );
  }
}

/// Runder/abgerundeter Symbolknopf.
class TdIconButton extends StatelessWidget {
  const TdIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.filled = false,
    this.size = 44,
    this.color,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;
  final double size;
  final Color? color;

  /// Kleiner Zähler oben rechts, z. B. ungelesene Nachrichten.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fg = color ?? (filled ? scheme.onPrimaryContainer : scheme.onSurface);
    Widget button = TdPressable(
      onTap: onPressed,
      enabled: onPressed != null,
      scale: 0.9,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? scheme.primaryContainer : Colors.transparent,
          borderRadius: TdRadius.control,
          border: filled ? null : Border.all(color: scheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: size * 0.5, color: fg),
      ),
    );
    if (badge != null && badge! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.secondary,
                borderRadius: BorderRadius.circular(TdRadius.pill),
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: Text(
                badge! > 99 ? '99+' : '$badge',
                style: context.text.labelSmall?.copyWith(
                  color: scheme.onSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}
