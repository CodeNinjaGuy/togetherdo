/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/td_design.dart';

/// Mengenwähler „− 2 +“. Die Zahl wechselt mit kurzer Überblendung und
/// leichtem Hüpfer; unter „Bewegung reduzieren“ nur Überblendung.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.5,
    this.max = 999,
    this.step = 1,
    this.unit,
    this.decreaseLabel,
    this.increaseLabel,
    this.compact = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;

  /// Einheit hinter der Zahl, z. B. „kg“.
  final String? unit;
  final String? decreaseLabel;
  final String? increaseLabel;
  final bool compact;

  static String format(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _set(double next) {
    final clamped = next.clamp(min, max).toDouble();
    if (clamped == value) return;
    HapticFeedback.selectionClick();
    onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final size = compact ? 36.0 : 44.0;
    final label = unit == null ? format(value) : '${format(value)} $unit';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(TdRadius.pill),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(TdSpace.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: decreaseLabel,
            size: size,
            enabled: value - step >= min - 1e-9,
            onTap: () => _set(value - step),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: compact ? 44 : 56),
            child: AnimatedSwitcher(
              duration: TdMotion.of(context, TdMotion.fast),
              switchInCurve: TdMotion.spring,
              switchOutCurve: TdMotion.exit,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: TdMotion.reduced(context)
                    ? child
                    : ScaleTransition(
                        scale: Tween(begin: 0.7, end: 1.0).animate(anim),
                        child: child,
                      ),
              ),
              child: Text(
                label,
                key: ValueKey(label),
                textAlign: TextAlign.center,
                style:
                    (compact
                            ? context.text.titleSmall
                            : context.text.titleMedium)
                        ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: increaseLabel,
            size: size,
            enabled: value + step <= max + 1e-9,
            onTap: () => _set(value + step),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final double size;
  final bool enabled;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    Widget button = TdPressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      scale: 0.88,
      semanticLabel: tooltip,
      child: AnimatedOpacity(
        duration: TdMotion.fast,
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: size * 0.5, color: scheme.primary),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}
