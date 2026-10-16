/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/td_tokens.dart';

/// Blendet ein Kind beim ersten Aufbau ein: Deckkraft 0→1 und ein kurzer
/// Weg von unten. Mit `index` lassen sich Listen staffeln. Unter
/// „Bewegung reduzieren“ nur Überblendung.
class TdFadeSlideIn extends StatefulWidget {
  const TdFadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay,
    this.duration = TdMotion.slow,
    this.offset = const Offset(0, 0.08),
    this.enabled = true,
  });

  final Widget child;
  final int index;
  final Duration? delay;
  final Duration duration;
  final Offset offset;
  final bool enabled;

  @override
  State<TdFadeSlideIn> createState() => _TdFadeSlideInState();
}

class _TdFadeSlideInState extends State<TdFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) _c.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.enabled) return;
    _started = true;
    if (TdMotion.reduced(context)) {
      _c.duration = TdMotion.fast;
    }
    final delay = widget.delay ?? TdMotion.stagger(widget.index);
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = TdMotion.reduced(context);
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    if (reduced) return FadeTransition(opacity: fade, child: widget.child);
    final slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: TdMotion.standard));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}

/// Sanft wachsender/schrumpfender Platz für ein Kind, das ein- oder
/// ausgeblendet wird (z. B. Fehlerzeile unter einem Feld).
class TdReveal extends StatelessWidget {
  const TdReveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = TdMotion.of(context, TdMotion.base);
    return AnimatedSize(
      duration: d,
      curve: TdMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: d,
        opacity: visible ? 1 : 0,
        child: visible ? child : const SizedBox(width: double.infinity),
      ),
    );
  }
}
