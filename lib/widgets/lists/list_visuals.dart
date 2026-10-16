/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../../design/td_design.dart';
import '../../fairness/fairness.dart';
import '../../models/list_model.dart';
import '../common/user_avatar.dart';
import '../fairness/fairness_widgets.dart';

/// Farbe einer Liste: fest je Liste (aus der ID abgeleitet), damit sie
/// überall gleich aussieht – in der Übersicht, auf „Heute“ und im Detail.
Color listColor(ListModel list) =>
    TdAvatarData(id: list.id, name: list.name).resolveColor();

IconData listIcon(ListModel list) => switch (list.type) {
  ListType.todo => Icons.checklist_rounded,
  ListType.shopping => Icons.shopping_basket_rounded,
};

Object listHeroTag(String listId) => 'list-icon-$listId';

/// Farbiges Symbol einer Liste; mit `hero` fliegt es zwischen Übersicht
/// und Detail.
class ListIconBadge extends StatelessWidget {
  const ListIconBadge({
    super.key,
    required this.list,
    this.size = 44,
    this.hero = true,
  });

  final ListModel list;
  final double size;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final color = listColor(list);
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.3)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: TdShadows.glow(color),
      ),
      alignment: Alignment.center,
      child: Icon(listIcon(list), color: Colors.white, size: size * 0.52),
    );
    if (!hero) return badge;
    return Hero(tag: listHeroTag(list.id), child: badge);
  }
}

/// Mitglieder einer Liste als Avatar-Reihe (Besitzer zuerst).
List<TdAvatarData> listMemberAvatars(ListModel list) {
  final cache = UserAvatarCache.instance;
  return [
    for (final m in fairnessMembersOf(list))
      avatarDataOf(m, imageUrl: cache.peek(m.id)),
  ];
}

/// Avatar-Stapel der Mitglieder; lädt fehlende Profilbilder nach.
class ListMembersStack extends StatefulWidget {
  const ListMembersStack({super.key, required this.list, this.size = 26});

  final ListModel list;
  final double size;

  @override
  State<ListMembersStack> createState() => _ListMembersStackState();
}

class _ListMembersStackState extends State<ListMembersStack> {
  @override
  void initState() {
    super.initState();
    _warm();
  }

  @override
  void didUpdateWidget(covariant ListMembersStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.list != widget.list) _warm();
  }

  void _warm() {
    final cache = UserAvatarCache.instance;
    for (final m in fairnessMembersOf(widget.list)) {
      if (!cache.contains(m.id)) {
        cache.urlFor(m.id).then((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      TdAvatarStack(people: listMemberAvatars(widget.list), size: widget.size);
}

/// Kopf einer Liste im Detail: Symbol (Hero), Name, Mitglieder.
class ListHeader extends StatelessWidget {
  const ListHeader({
    super.key,
    required this.list,
    this.subtitle,
    this.trailing,
    this.iconSize = 56,
  });

  final ListModel list;
  final String? subtitle;
  final Widget? trailing;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ListIconBadge(list: list, size: iconSize),
        const SizedBox(width: TdSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.name,
                style: context.text.headlineMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: TdSpace.xs),
              Row(
                children: [
                  ListMembersStack(list: list, size: 24),
                  if (subtitle != null) ...[
                    const SizedBox(width: TdSpace.sm),
                    Flexible(
                      child: Text(
                        subtitle!,
                        style: context.text.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: TdSpace.sm), trailing!],
      ],
    );
  }
}

/// Zähler-Pille neben Abschnittstiteln.
class CountPill extends StatelessWidget {
  const CountPill({super.key, required this.count, this.muted = false});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: TdSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? scheme.surfaceContainerHighest : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(TdRadius.pill),
      ),
      child: TdAnimatedCounter(
        value: count,
        style: context.text.labelMedium?.copyWith(
          color: muted ? context.td.muted : scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
