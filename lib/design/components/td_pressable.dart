/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/td_tokens.dart';

/// Drück-Verhalten für Knöpfe und Karten: schrumpft beim Antippen leicht
/// und federt zurück. Ersetzt den Material-Ripple dort, wo eine Fläche
/// „greifbar“ wirken soll.
class TdPressable extends StatefulWidget {
  const TdPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = false,
    this.enabled = true,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final bool enabled;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  State<TdPressable> createState() => _TdPressableState();
}

class _TdPressableState extends State<TdPressable> {
  bool _down = false;

  bool get _active =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = TdMotion.reduced(context);
    final scale = (!_active || reduced) ? 1.0 : (_down ? widget.scale : 1.0);
    return Semantics(
      button: _active,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _active ? (_) => _set(true) : null,
        onTapUp: _active ? (_) => _set(false) : null,
        onTapCancel: _active ? () => _set(false) : null,
        onTap: _active
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap?.call();
              }
            : null,
        onLongPress: widget.onLongPress,
        child: MouseRegion(
          cursor: _active ? SystemMouseCursors.click : MouseCursor.defer,
          child: AnimatedScale(
            scale: scale,
            duration: _down ? TdMotion.instant : TdMotion.base,
            curve: _down ? Curves.easeOut : TdMotion.spring,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
