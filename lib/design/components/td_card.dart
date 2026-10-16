/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'td_pressable.dart';

enum TdCardVariant {
  /// Weiße/dunkle Fläche mit feiner Kante.
  surface,

  /// Angehoben mit weichem Schatten.
  elevated,

  /// Halbtransparent mit Weichzeichner, für Flächen über Verläufen.
  glass,

  /// Markenverlauf, Text darauf hell.
  gradient,

  /// Nur Kante, kein Hintergrund.
  outlined,
}

/// Grundkarte der App. Mit `onTap` wird sie drückbar (schrumpft leicht).
class TdCard extends StatelessWidget {
  const TdCard({
    super.key,
    required this.child,
    this.variant = TdCardVariant.surface,
    this.padding = const EdgeInsets.all(TdSpace.lg),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.gradient,
    this.borderRadius,
    this.color,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final TdCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final Color? color;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    final radius = borderRadius ?? TdRadius.card;

    Widget content = Padding(padding: padding, child: child);

    final BoxDecoration decoration;
    switch (variant) {
      case TdCardVariant.surface:
        decoration = BoxDecoration(
          color: color ?? scheme.surface,
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant),
        );
      case TdCardVariant.elevated:
        decoration = BoxDecoration(
          color: color ?? scheme.surfaceContainerHigh,
          borderRadius: radius,
          boxShadow: td.shadowSoft,
        );
      case TdCardVariant.outlined:
        decoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        );
      case TdCardVariant.gradient:
        decoration = BoxDecoration(
          gradient: gradient ?? td.heroGradient,
          borderRadius: radius,
          boxShadow: TdShadows.glow(td.palette.primary),
        );
        content = DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white),
            child: content,
          ),
        );
      case TdCardVariant.glass:
        decoration = BoxDecoration(
          color: color ?? td.glassFill,
          borderRadius: radius,
          border: Border.all(color: td.glassBorder),
        );
        content = ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: content,
          ),
        );
    }

    Widget card = Container(
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: decoration,
      child: content,
    );

    if (onTap != null || onLongPress != null) {
      card = TdPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: card,
      );
    }
    return card;
  }
}
