/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'td_pressable.dart';

/// Auswahl-Chip (Filter, Liste, Person). Farbe wechselt weich.
class TdChip extends StatelessWidget {
  const TdChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.leading,
    this.color,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Beliebiges Widget vorne, z. B. ein Avatar.
  final Widget? leading;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final td = context.td;
    final accent = color ?? scheme.primary;
    final bg = selected
        ? accent.withValues(alpha: td.isDark ? 0.3 : 0.14)
        : scheme.surface;
    final fg = selected ? (td.isDark ? scheme.onSurface : _darken(accent)) : scheme.onSurface;
    final border = selected ? accent.withValues(alpha: 0.6) : scheme.outlineVariant;

    return TdPressable(
      onTap: onTap,
      enabled: onTap != null,
      scale: 0.94,
      haptic: true,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: TdMotion.of(context, TdMotion.base),
        curve: TdMotion.standard,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? TdSpace.md : TdSpace.lg,
          vertical: dense ? TdSpace.xs + 2 : TdSpace.sm + 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TdRadius.pill),
          border: Border.all(color: border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: TdSpace.sm)],
            if (icon != null) ...[
              Icon(icon, size: dense ? 14 : 16, color: selected ? accent : scheme.onSurfaceVariant),
              const SizedBox(width: TdSpace.xs + 2),
            ],
            Text(
              label,
              style: (dense ? context.text.labelSmall : context.text.labelMedium)
                  ?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }

  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
  }
}

/// Kleines, nicht klickbares Etikett (Listenname, Fälligkeit, Kategorie).
class TdTag extends StatelessWidget {
  const TdTag({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.filled = true,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final td = context.td;
    final accent = color ?? scheme.onSurfaceVariant;
    final fg = filled
        ? (td.isDark ? Color.lerp(accent, Colors.white, 0.35)! : TdChip._darken(accent))
        : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: TdSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? accent.withValues(alpha: td.isDark ? 0.24 : 0.12) : null,
        borderRadius: BorderRadius.circular(TdRadius.sm),
        border: filled ? null : Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label, style: context.text.labelSmall?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Gewicht einer Aufgabe – Grundlage für „fair verteilt“ (Stufe 3).
/// Hier nur die Darstellung; die Logik kommt mit dem Datenmodell.
enum TdWeight { light, medium, heavy }

/// Drei Punkte, so viele gefüllt wie das Gewicht schwer ist.
class TdWeightTag extends StatelessWidget {
  const TdWeightTag({super.key, required this.weight, this.label});

  final TdWeight weight;

  /// Übersetzter Text, z. B. „leicht“. Ohne Text nur die Punkte.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final td = context.td;
    final filled = switch (weight) {
      TdWeight.light => 1,
      TdWeight.medium => 2,
      TdWeight.heavy => 3,
    };
    final accent = switch (weight) {
      TdWeight.light => td.success,
      TdWeight.medium => td.warning,
      TdWeight.heavy => scheme.secondary,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? accent : scheme.outlineVariant,
            ),
          ),
        if (label != null) ...[
          const SizedBox(width: 3),
          Text(label!, style: context.text.labelSmall),
        ],
      ],
    );
  }
}
