/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../motion/td_confetti.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'td_avatar.dart';
import 'td_pressable.dart';

/// Zeile für Aufgabe oder Einkaufsartikel. Unabhängig vom Datenmodell:
/// Stufe 4 bildet `TodoModel`/`ShoppingItemModel` auf diese Felder ab.
///
/// - Abhaken: Ring füllt sich mit Verlauf, Haken zeichnet sich, kurzer
///   Überschwinger, Konfetti und Haptik; Titel streicht sich durch.
/// - Wischen nach rechts: abhaken/zurücknehmen. Nach links: löschen.
/// - `accent` färbt den Streifen links (Listenfarbe).
class TdTaskTile extends StatefulWidget {
  const TdTaskTile({
    super.key,
    required this.title,
    required this.done,
    this.onChanged,
    this.subtitle,
    this.onTap,
    this.onDelete,
    this.assignee,
    this.accent,
    this.tags = const [],
    this.trailing,
    this.leadingLabel,
    this.celebrate = true,
    this.heroTag,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final bool done;

  /// `null` = nicht abhakbar (keine Berechtigung).
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  /// `null` = nicht per Wischen löschbar.
  final VoidCallback? onDelete;
  final TdAvatarData? assignee;
  final Color? accent;

  /// Kleine Etiketten unter dem Titel (Liste, Fälligkeit, Gewicht).
  final List<Widget> tags;
  final Widget? trailing;

  /// Kurztext statt Haken-Ring, z. B. Menge „2 L“ beim Einkauf.
  final String? leadingLabel;
  final bool celebrate;
  final Object? heroTag;
  final bool dense;

  @override
  State<TdTaskTile> createState() => _TdTaskTileState();
}

class _TdTaskTileState extends State<TdTaskTile> {
  final _checkKey = GlobalKey();

  void _toggle() {
    final next = !widget.done;
    widget.onChanged?.call(next);
    if (next && widget.celebrate) {
      final ctx = _checkKey.currentContext;
      if (ctx != null) TdConfetti.burstFrom(ctx, count: 22);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final td = context.td;
    final canToggle = widget.onChanged != null;
    final accent = widget.accent ?? scheme.primary;

    Widget tile = AnimatedOpacity(
      duration: TdMotion.of(context, TdMotion.base),
      opacity: widget.done ? 0.62 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: TdRadius.card,
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                TdSpace.md + 4,
                widget.dense ? TdSpace.sm + 2 : TdSpace.md,
                TdSpace.md,
                widget.dense ? TdSpace.sm + 2 : TdSpace.md,
              ),
              child: Row(
                children: [
                  _Leading(
                    key: _checkKey,
                    done: widget.done,
                    enabled: canToggle,
                    label: widget.leadingLabel,
                    accent: accent,
                    onTap: canToggle ? _toggle : null,
                  ),
                  const SizedBox(width: TdSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StrikeText(
                          text: widget.title,
                          struck: widget.done,
                          style: context.text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          heroTag: widget.heroTag,
                        ),
                        if (widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: context.text.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (widget.tags.isNotEmpty) ...[
                          const SizedBox(height: TdSpace.sm),
                          Wrap(
                            spacing: TdSpace.sm,
                            runSpacing: TdSpace.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: widget.tags,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.assignee != null) ...[
                    const SizedBox(width: TdSpace.md),
                    TdAvatar(data: widget.assignee!, size: widget.dense ? 28 : 32),
                  ],
                  if (widget.trailing != null) ...[
                    const SizedBox(width: TdSpace.sm),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
            // Listenfarbe als Streifen am linken Rand.
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: AnimatedContainer(
                duration: TdMotion.of(context, TdMotion.base),
                color: widget.done ? accent.withValues(alpha: 0.4) : accent,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      tile = TdPressable(onTap: widget.onTap, scale: 0.985, child: tile);
    }

    final direction = widget.onDelete != null
        ? (canToggle ? DismissDirection.horizontal : DismissDirection.endToStart)
        : (canToggle ? DismissDirection.startToEnd : DismissDirection.none);
    if (direction == DismissDirection.none) return tile;

    return Dismissible(
      key: ValueKey('td-tile-${widget.heroTag ?? widget.title}-${identityHashCode(widget.onChanged)}'),
      direction: direction,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.45,
      },
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          _toggle();
          return false;
        }
        return true;
      },
      onDismissed: (_) => widget.onDelete?.call(),
      background: _SwipeBackground(
        color: td.success,
        icon: widget.done ? Icons.undo_rounded : Icons.check_rounded,
        alignment: AlignmentDirectional.centerStart,
      ),
      secondaryBackground: _SwipeBackground(
        color: td.danger,
        icon: Icons.delete_outline_rounded,
        alignment: AlignmentDirectional.centerEnd,
      ),
      child: tile,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.td.isDark ? 0.35 : 0.18),
        borderRadius: TdRadius.card,
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: TdSpace.xl),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

/// Haken-Ring oder Mengen-Etikett links in der Zeile.
class _Leading extends StatelessWidget {
  const _Leading({
    super.key,
    required this.done,
    required this.enabled,
    required this.accent,
    this.label,
    this.onTap,
  });

  final bool done;
  final bool enabled;
  final Color accent;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final check = TdCheck(value: done, enabled: enabled, onTap: onTap, accent: accent);
    if (label == null) return check;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        check,
        const SizedBox(width: TdSpace.sm),
        Container(
          constraints: const BoxConstraints(minWidth: 36),
          padding: const EdgeInsets.symmetric(horizontal: TdSpace.sm, vertical: TdSpace.xs),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(TdRadius.sm),
          ),
          alignment: Alignment.center,
          child: Text(label!, style: context.text.labelSmall),
        ),
      ],
    );
  }
}

/// Animierter Haken: Ring → gefüllter Kreis mit Verlauf, Haken wird
/// gezeichnet, kurzer Überschwinger. Eigenständig verwendbar.
class TdCheck extends StatefulWidget {
  const TdCheck({
    super.key,
    required this.value,
    this.onTap,
    this.enabled = true,
    this.size = 28,
    this.accent,
  });

  final bool value;
  final VoidCallback? onTap;
  final bool enabled;
  final double size;
  final Color? accent;

  @override
  State<TdCheck> createState() => _TdCheckState();
}

class _TdCheckState extends State<TdCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: TdMotion.slow,
    reverseDuration: TdMotion.base,
    value: widget.value ? 1 : 0,
  );

  @override
  void didUpdateWidget(TdCheck old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final reduced = TdMotion.reduced(context);
      if (reduced) {
        _c.value = widget.value ? 1 : 0;
      } else if (widget.value) {
        _c.forward();
      } else {
        _c.reverse();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final td = context.td;
    final accent = widget.accent ?? scheme.primary;
    final fill = LinearGradient(
      colors: [td.success, Color.lerp(td.success, accent, 0.5)!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Semantics(
      checked: widget.value,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(TdSpace.xs),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              // Überschwinger um 70 % des Weges.
              final bump = t < 0.7 ? 1.0 : 1 + 0.18 * (1 - ((t - 0.7) / 0.3)) * ((t - 0.7) / 0.3) * 4;
              return Transform.scale(
                scale: bump,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _CheckPainter(
                    t: t,
                    ring: widget.enabled ? scheme.outline : scheme.outlineVariant,
                    fill: fill,
                    check: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.t,
    required this.ring,
    required this.fill,
    required this.check,
  });

  final double t;
  final Color ring;
  final Gradient fill;
  final Color check;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final r = size.width / 2;
    final fillT = Curves.easeOutCubic.transform((t / 0.55).clamp(0, 1));
    final checkT = Curves.easeOutCubic.transform(((t - 0.4) / 0.6).clamp(0, 1));

    // Ring
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring.withValues(alpha: 1 - fillT),
    );

    // Füllung wächst von innen
    if (fillT > 0) {
      canvas.drawCircle(
        center,
        r * fillT,
        Paint()..shader = fill.createShader(rect),
      );
    }

    // Haken
    if (checkT > 0) {
      final p1 = Offset(size.width * 0.28, size.height * 0.52);
      final p2 = Offset(size.width * 0.44, size.height * 0.68);
      final p3 = Offset(size.width * 0.74, size.height * 0.36);
      final path = Path()..moveTo(p1.dx, p1.dy);
      final seg1 = (checkT / 0.45).clamp(0.0, 1.0);
      final seg2 = ((checkT - 0.45) / 0.55).clamp(0.0, 1.0);
      final a = Offset.lerp(p1, p2, seg1)!;
      path.lineTo(a.dx, a.dy);
      if (seg2 > 0) {
        final b = Offset.lerp(p2, p3, seg2)!;
        path.lineTo(b.dx, b.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.1
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = check,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.ring != ring;
}

/// Text mit animierter Durchstreichlinie, die von links nach rechts wächst.
class _StrikeText extends StatelessWidget {
  const _StrikeText({
    required this.text,
    required this.struck,
    this.style,
    this.heroTag,
  });

  final String text;
  final bool struck;
  final TextStyle? style;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    Widget label = Text(
      text,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    if (heroTag != null) {
      label = Hero(
        tag: heroTag!,
        flightShuttleBuilder: (_, _, _, _, _) =>
            DefaultTextStyle(style: style ?? const TextStyle(), child: Text(text)),
        child: Material(color: Colors.transparent, child: label),
      );
    }
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        label,
        Positioned.fill(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedFractionallySizedBox(
              duration: TdMotion.of(context, TdMotion.slow),
              curve: TdMotion.standard,
              widthFactor: struck ? 1 : 0,
              alignment: AlignmentDirectional.centerStart,
              child: Container(height: 2, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}
