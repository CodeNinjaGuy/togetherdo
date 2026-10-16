/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

/// Leerzustand: Symbol auf weichem Farbfleck, der leicht schwebt,
/// Überschrift, kurzer Satz und optional eine Aktion. Statt kalter
/// „Keine Einträge“-Meldung ein freundlicher Startpunkt.
class TdEmptyState extends StatefulWidget {
  const TdEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  State<TdEmptyState> createState() => _TdEmptyStateState();
}

class _TdEmptyStateState extends State<TdEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TdMotion.reduced(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    final size = widget.compact ? 72.0 : 112.0;

    return Padding(
      padding: EdgeInsets.all(widget.compact ? TdSpace.lg : TdSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _float,
            builder: (context, child) {
              final dy = Curves.easeInOut.transform(_float.value) * 8 - 4;
              return Transform.translate(offset: Offset(0, dy), child: child);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary.withValues(
                          alpha: td.isDark ? 0.35 : 0.16,
                        ),
                        scheme.secondary.withValues(
                          alpha: td.isDark ? 0.3 : 0.14,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  right: size * 0.08,
                  top: size * 0.1,
                  child: _dot(scheme.secondary, size * 0.12),
                ),
                Positioned(
                  left: size * 0.05,
                  bottom: size * 0.18,
                  child: _dot(scheme.tertiary, size * 0.09),
                ),
                Icon(widget.icon, size: size * 0.42, color: scheme.primary),
              ],
            ),
          ),
          SizedBox(height: widget.compact ? TdSpace.lg : TdSpace.xl),
          Text(
            widget.title,
            style: widget.compact
                ? context.text.titleMedium
                : context.text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (widget.message != null) ...[
            const SizedBox(height: TdSpace.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                widget.message!,
                style: context.text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (widget.action != null) ...[
            const SizedBox(height: TdSpace.xl),
            widget.action!,
          ],
        ],
      ),
    );
  }

  Widget _dot(Color c, double d) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c.withValues(alpha: 0.8),
    ),
  );
}
