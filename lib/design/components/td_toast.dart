/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

enum TdToastVariant { info, success, warning, error }

/// Kurze Rückmeldung, die von unten (Handy) bzw. oben rechts (breit)
/// hereingleitet und von selbst verschwindet. Läuft im Overlay, braucht
/// also keinen `ScaffoldMessenger`.
abstract final class TdToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    TdToastVariant variant = TdToastVariant.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        variant: variant,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        compact: context.tdIsCompact,
        onDismissed: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.variant,
    required this.duration,
    required this.onDismissed,
    required this.compact,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final TdToastVariant variant;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;
  final bool compact;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: TdMotion.slow,
    reverseDuration: TdMotion.base,
  );

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    if (!mounted) return;
    await _c.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    final (accent, icon) = switch (widget.variant) {
      TdToastVariant.info => (
        scheme.primary,
        widget.icon ?? Icons.info_outline_rounded,
      ),
      TdToastVariant.success => (
        td.success,
        widget.icon ?? Icons.check_circle_rounded,
      ),
      TdToastVariant.warning => (
        td.warning,
        widget.icon ?? Icons.warning_amber_rounded,
      ),
      TdToastVariant.error => (
        td.danger,
        widget.icon ?? Icons.error_outline_rounded,
      ),
    };

    final reduced = TdMotion.reduced(context);
    final curved = CurvedAnimation(
      parent: _c,
      curve: TdMotion.spring,
      reverseCurve: TdMotion.exit,
    );
    final offset = widget.compact
        ? const Offset(0, 0.4)
        : const Offset(0, -0.4);

    Widget card = Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.fromLTRB(
          TdSpace.lg,
          TdSpace.md,
          TdSpace.md,
          TdSpace.md,
        ),
        decoration: BoxDecoration(
          color: td.isDark ? scheme.surfaceContainerHigh : scheme.onSurface,
          borderRadius: TdRadius.control,
          boxShadow: td.shadowLifted,
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: TdSpace.md),
            Flexible(
              child: Text(
                widget.message,
                style: context.text.bodyMedium?.copyWith(
                  color: td.isDark ? scheme.onSurface : scheme.surface,
                ),
              ),
            ),
            if (widget.actionLabel != null) ...[
              const SizedBox(width: TdSpace.sm),
              TextButton(
                onPressed: () {
                  widget.onAction?.call();
                  _hide();
                },
                style: TextButton.styleFrom(foregroundColor: accent),
                child: Text(widget.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );

    card = GestureDetector(onTap: _hide, child: card);

    final animated = FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
      child: reduced
          ? card
          : SlideTransition(
              position: Tween(begin: offset, end: Offset.zero).animate(curved),
              child: card,
            ),
    );

    return SafeArea(
      child: Align(
        alignment: widget.compact ? Alignment.bottomCenter : Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(TdSpace.lg),
          child: animated,
        ),
      ),
    );
  }
}
