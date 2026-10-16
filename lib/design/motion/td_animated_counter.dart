/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../tokens/td_tokens.dart';

/// Zahl, die beim Ändern vom alten zum neuen Wert hochzählt.
/// `format` erlaubt Prozent, Einheiten oder Dezimalstellen.
class TdAnimatedCounter extends StatefulWidget {
  const TdAnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = TdMotion.counter,
    this.curve = TdMotion.standard,
    this.format,
    this.textAlign,
  });

  final num value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String Function(num value)? format;
  final TextAlign? textAlign;

  @override
  State<TdAnimatedCounter> createState() => _TdAnimatedCounterState();
}

class _TdAnimatedCounterState extends State<TdAnimatedCounter> {
  late num _from = widget.value;

  @override
  void didUpdateWidget(TdAnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  @override
  Widget build(BuildContext context) {
    final format = widget.format ?? (num v) => v.round().toString();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from.toDouble(), end: widget.value.toDouble()),
      duration: TdMotion.of(context, widget.duration),
      curve: widget.curve,
      builder: (context, v, _) => Text(
        format(v),
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }
}
