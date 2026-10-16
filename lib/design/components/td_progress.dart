/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/td_animated_counter.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'td_avatar.dart';

/// Waagerechter Balken, der beim Erscheinen und bei jeder Änderung
/// weich auf den neuen Wert wächst.
class TdProgressBar extends StatelessWidget {
  const TdProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color,
    this.gradient,
    this.trackColor,
    this.duration = TdMotion.counter,
  });

  /// 0…1
  final double value;
  final double height;
  final Color? color;
  final Gradient? gradient;
  final Color? trackColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final td = context.td;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: trackColor ?? scheme.outlineVariant,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: TdMotion.of(context, duration),
          curve: TdMotion.emphasized,
          builder: (context, v, _) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  color: gradient == null ? (color ?? scheme.primary) : null,
                  gradient:
                      gradient ?? (color == null ? td.primaryGradient : null),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anteil einer Person am Fairness-Balken.
@immutable
class TdFairnessShare {
  const TdFairnessShare({required this.person, required this.value});

  final TdAvatarData person;

  /// Punkte, Anzahl oder Gewicht – wird relativ zur Summe dargestellt.
  final double value;
}

/// Gestapelter Balken „wer hat wie viel getragen“, darunter Legende mit
/// Avataren und animierten Prozentwerten. Herzstück von „fair verteilt“.
class TdFairnessBar extends StatelessWidget {
  const TdFairnessBar({
    super.key,
    required this.shares,
    this.height = 14,
    this.showLegend = true,
    this.percentFormat,
  });

  final List<TdFairnessShare> shares;
  final double height;
  final bool showLegend;

  /// Formatierung der Prozentzahl (für Übersetzung/Locale), Standard „42 %“.
  final String Function(num percent)? percentFormat;

  @override
  Widget build(BuildContext context) {
    final total = shares.fold<double>(0, (s, e) => s + e.value);
    final scheme = context.colors;
    final fmt = percentFormat ?? (num p) => '${p.round()} %';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Container(
            height: height,
            color: scheme.outlineVariant,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: TdMotion.of(context, TdMotion.counter),
              curve: TdMotion.emphasized,
              builder: (context, t, _) => Row(
                children: [
                  for (var i = 0; i < shares.length; i++)
                    Flexible(
                      flex: total == 0
                          ? 1
                          : math.max(
                              1,
                              (shares[i].value / total * 1000 * t).round(),
                            ),
                      child: Container(
                        margin: EdgeInsets.only(
                          right: i < shares.length - 1 ? 2 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: shares[i].person.resolveColor(),
                          borderRadius: BorderRadius.circular(height),
                        ),
                      ),
                    ),
                  if (t < 1)
                    Flexible(
                      flex: math.max(1, (1000 * (1 - t)).round()),
                      child: const SizedBox(),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: TdSpace.md),
          Wrap(
            spacing: TdSpace.lg,
            runSpacing: TdSpace.sm,
            children: [
              for (final s in shares)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TdAvatar(data: s.person, size: 22),
                    const SizedBox(width: TdSpace.sm),
                    Text(s.person.name, style: context.text.labelMedium),
                    const SizedBox(width: TdSpace.xs),
                    TdAnimatedCounter(
                      value: total == 0 ? 0 : s.value / total * 100,
                      format: fmt,
                      style: context.text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Kreisförmiger Fortschritt (z. B. „3 von 7 heute“), animiert.
class TdRingProgress extends StatelessWidget {
  const TdRingProgress({
    super.key,
    required this.value,
    this.size = 72,
    this.stroke = 8,
    this.color,
    this.trackColor,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: TdMotion.of(context, TdMotion.counter),
      curve: TdMotion.emphasized,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: v,
            stroke: stroke,
            color: color ?? scheme.primary,
            track: trackColor ?? scheme.outlineVariant,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, trackPaint);
    if (value <= 0) return;
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.7), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
