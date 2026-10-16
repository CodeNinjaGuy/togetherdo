/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../../models/shopping_item_model.dart';
import 'product_thumbnail.dart';

/// Zeile eines Einkaufsartikels: Haken-Ring, Produktbild, Name, Menge,
/// Notiz und „gekauft von“. Tippen öffnet das Bearbeiten (wenn erlaubt).
///
/// Daten kommen rein, Aktionen gehen raus – kein Firebase in der Zeile,
/// damit sie in Tests und in der Debug-Demo läuft.
class ShoppingItemWidget extends StatefulWidget {
  const ShoppingItemWidget({
    super.key,
    required this.item,
    this.highlight = false,
    this.onHighlightEnd,
    this.canEdit = true,
    this.canToggle = true,
    this.onTogglePurchased,
    this.onTap,
    this.onDelete,
    this.currentUserName,
    this.index = 0,
  });

  final ShoppingItemModel item;

  /// Kurz aufblinken (nach Push-Benachrichtigung).
  final bool highlight;
  final VoidCallback? onHighlightEnd;

  /// Bearbeiten/Löschen erlaubt (Besitzer oder Mitglied mit allowEdit).
  final bool canEdit;

  /// Abhaken erlaubt (jedes Mitglied).
  final bool canToggle;
  final ValueChanged<bool>? onTogglePurchased;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// Anzeigename des angemeldeten Nutzers („von dir“).
  final String? currentUserName;

  /// Position in der Liste für gestaffeltes Einblenden.
  final int index;

  @override
  State<ShoppingItemWidget> createState() => _ShoppingItemWidgetState();
}

class _ShoppingItemWidgetState extends State<ShoppingItemWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: TdMotion.slow,
  );
  bool _highlighting = false;

  @override
  void initState() {
    super.initState();
    if (widget.highlight) _startHighlight();
  }

  @override
  void didUpdateWidget(covariant ShoppingItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !oldWidget.highlight && !_highlighting) {
      _startHighlight();
    }
  }

  Future<void> _startHighlight() async {
    _highlighting = true;
    for (var i = 0; i < 2; i++) {
      if (!mounted) return;
      await _pulse.forward();
      await _pulse.reverse();
    }
    if (!mounted) return;
    _highlighting = false;
    widget.onHighlightEnd?.call();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    final onToggle = widget.onTogglePurchased;
    if (onToggle == null) return;
    final next = !widget.item.isPurchased;
    HapticFeedback.lightImpact();
    onToggle(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.item;
    final scheme = context.colors;
    final td = context.td;
    final done = item.isPurchased;
    final canToggle = widget.canToggle && widget.onTogglePurchased != null;

    final boughtBy = item.purchasedBy;
    final boughtLabel = boughtBy == null
        ? null
        : '${l10n.boughtBy} ${boughtBy == widget.currentUserName ? l10n.byYou : boughtBy}';

    Widget row = Row(
      children: [
        _CheckRing(
          done: done,
          enabled: canToggle,
          onTap: canToggle ? _toggle : null,
        ),
        const SizedBox(width: TdSpace.md),
        Hero(
          tag: 'artikel-${item.id}',
          child: ProductThumbnail(
            imageUrl: item.imageUrl,
            size: 48,
            dimmed: done,
          ),
        ),
        const SizedBox(width: TdSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: TdMotion.of(context, TdMotion.base),
                style: context.text.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: done
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: scheme.onSurfaceVariant,
                  color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: TdSpace.xs),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TdSpace.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(
                        alpha: done ? 0.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(TdRadius.xs),
                    ),
                    child: Text(
                      item.displayQuantity,
                      style: context.text.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(width: TdSpace.sm),
                    Expanded(
                      child: Text(
                        item.notes!,
                        style: context.text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (done && boughtLabel != null) ...[
                const SizedBox(height: TdSpace.xs),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 14, color: scheme.primary),
                    const SizedBox(width: TdSpace.xs),
                    Flexible(
                      child: Text(
                        boughtLabel,
                        style: context.text.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.purchasedAt != null) ...[
                      const SizedBox(width: TdSpace.sm),
                      Icon(Icons.schedule_rounded, size: 14, color: td.muted),
                      const SizedBox(width: TdSpace.xs),
                      Text(
                        DateFormat.yMd(
                          Localizations.localeOf(context).toString(),
                        ).add_Hm().format(item.purchasedAt!),
                        style: context.text.labelSmall?.copyWith(
                          color: td.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        if (widget.canEdit && widget.onDelete != null) ...[
          const SizedBox(width: TdSpace.xs),
          TdIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.delete,
            size: 36,
            color: td.muted,
            onPressed: widget.onDelete,
          ),
        ],
      ],
    );

    final card = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return AnimatedOpacity(
          duration: TdMotion.of(context, TdMotion.base),
          opacity: done ? 0.7 : 1,
          child: Container(
            margin: const EdgeInsets.only(bottom: TdSpace.sm),
            decoration: BoxDecoration(
              color: Color.lerp(
                scheme.surface,
                td.success.withValues(alpha: 0.18),
                t,
              ),
              borderRadius: TdRadius.card,
              border: Border.all(
                color: Color.lerp(scheme.outlineVariant, td.success, t)!,
                width: 1 + t,
              ),
              boxShadow: t > 0
                  ? TdShadows.glow(td.success.withValues(alpha: t))
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(
              TdSpace.md,
              TdSpace.md,
              TdSpace.md,
              TdSpace.md,
            ),
            child: child,
          ),
        );
      },
      child: row,
    );

    final tappable = widget.canEdit && widget.onTap != null
        ? TdPressable(
            onTap: widget.onTap,
            scale: 0.985,
            borderRadius: TdRadius.card,
            child: card,
          )
        : card;

    return TdFadeSlideIn(index: widget.index, child: tappable);
  }
}

/// Runder Haken: leer mit Kante, gefüllt mit Verlauf und Haken, wenn
/// gekauft. Kurzer Überschwinger beim Wechsel.
class _CheckRing extends StatelessWidget {
  const _CheckRing({required this.done, required this.enabled, this.onTap});

  final bool done;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    final reduced = TdMotion.reduced(context);
    return TdPressable(
      onTap: onTap,
      enabled: enabled,
      scale: 0.85,
      child: AnimatedContainer(
        duration: TdMotion.of(context, TdMotion.base),
        curve: reduced ? Curves.linear : TdMotion.spring,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: done ? td.successGradient : null,
          color: done ? null : Colors.transparent,
          border: done
              ? null
              : Border.all(
                  color: enabled ? scheme.outline : scheme.outlineVariant,
                  width: 2,
                ),
        ),
        child: AnimatedScale(
          duration: TdMotion.of(context, TdMotion.base),
          curve: reduced ? Curves.linear : TdMotion.spring,
          scale: done ? 1 : 0,
          child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
