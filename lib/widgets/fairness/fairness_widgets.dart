/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../../fairness/fairness.dart';
import '../../models/todo_model.dart';
import '../common/user_avatar.dart';

/// Übersetzter Name des Aufwands.
String effortLabel(AppLocalizations l10n, TaskEffort effort) =>
    switch (effort) {
      TaskEffort.light => l10n.effortLight,
      TaskEffort.medium => l10n.effortMedium,
      TaskEffort.heavy => l10n.effortHeavy,
    };

/// Aufwand → Darstellung im Design-System.
TdWeight tdWeightOf(TaskEffort effort) => switch (effort) {
  TaskEffort.light => TdWeight.light,
  TaskEffort.medium => TdWeight.medium,
  TaskEffort.heavy => TdWeight.heavy,
};

/// Anzeigename: die angemeldete Person heißt „Du“.
String memberDisplayName(
  AppLocalizations l10n,
  FairnessMember member,
  String currentUserId,
) => member.id == currentUserId ? l10n.fairnessYou : member.name;

/// Darstellung eines Mitglieds; die Farbe hängt an der Position in der
/// Liste, damit sich Mitglieder nie dieselbe Farbe teilen.
TdAvatarData avatarDataOf(FairnessMember m, {String? imageUrl}) => TdAvatarData(
  id: m.id,
  name: m.name,
  imageUrl: imageUrl,
  color: TdAvatarData.palette[m.index % TdAvatarData.palette.length],
);

/// Avatar eines Mitglieds; das Profilbild kommt aus dem gemeinsamen
/// Zwischenspeicher, sonst Initialen auf fester Farbe.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.size = 32});

  final FairnessMember member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cache = UserAvatarCache.instance;
    if (cache.contains(member.id)) {
      return TdAvatar(
        data: avatarDataOf(member, imageUrl: cache.peek(member.id)),
        size: size,
      );
    }
    return FutureBuilder<String?>(
      future: cache.urlFor(member.id),
      builder: (context, snap) => TdAvatar(
        data: avatarDataOf(member, imageUrl: snap.data),
        size: size,
      ),
    );
  }
}

/// Fairness-Karte über der Aufgabenliste: gestapelter Balken je Mitglied,
/// Umschalter Woche/Monat und ein Satz, wer als Nächstes dran ist.
class FairnessCard extends StatefulWidget {
  const FairnessCard({
    super.key,
    required this.members,
    required this.doneTodos,
    required this.suggestion,
    required this.currentUserId,
    required this.onOpenStats,
    this.now,
  });

  final List<FairnessMember> members;

  /// Erledigte Aufgaben seit [fairnessQueryStart].
  final List<TodoModel> doneTodos;
  final FairnessSuggestion? suggestion;
  final String currentUserId;
  final VoidCallback onOpenStats;

  /// Nur für Tests/Vorschau.
  final DateTime? now;

  @override
  State<FairnessCard> createState() => _FairnessCardState();
}

class _FairnessCardState extends State<FairnessCard> {
  FairnessPeriod _period = FairnessPeriod.week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stats = FairnessStats.compute(
      period: _period,
      members: widget.members,
      todos: widget.doneTodos,
      now: widget.now ?? DateTime.now(),
    );

    final String hint;
    if (stats.isEmpty) {
      hint = l10n.fairnessNothingYet;
    } else if (stats.isBalanced) {
      hint = l10n.fairnessBalanced;
    } else {
      final top = stats.top!;
      final next = widget.suggestion?.member;
      final me = widget.currentUserId;
      hint = [
        top.member.id == me
            ? l10n.fairnessTopCarrierYou
            : l10n.fairnessTopCarrier(top.member.name),
        if (next != null && next.id != top.member.id)
          next.id == me
              ? l10n.fairnessNextTurnYou
              : l10n.fairnessNextTurn(next.name),
      ].join(' ');
    }

    return TdCard(
      onTap: widget.onOpenStats,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.balance_rounded,
                size: 20,
                color: context.colors.primary,
              ),
              const SizedBox(width: TdSpace.sm),
              Expanded(
                child: Text(
                  l10n.fairnessTitle,
                  style: context.text.titleMedium,
                ),
              ),
              TdChip(
                label: l10n.fairnessWeek,
                dense: true,
                selected: _period == FairnessPeriod.week,
                onTap: () => setState(() => _period = FairnessPeriod.week),
              ),
              const SizedBox(width: TdSpace.xs),
              TdChip(
                label: l10n.fairnessMonth,
                dense: true,
                selected: _period == FairnessPeriod.month,
                onTap: () => setState(() => _period = FairnessPeriod.month),
              ),
            ],
          ),
          const SizedBox(height: TdSpace.lg),
          TdFairnessBar(
            key: ValueKey(_period),
            percentFormat: (p) => l10n.fairnessPercent(p.round()),
            shares: [
              for (final s in stats.shares)
                TdFairnessShare(
                  person: avatarDataOf(
                    s.member,
                    imageUrl: UserAvatarCache.instance.peek(s.member.id),
                  ),
                  value: s.points.toDouble(),
                ),
            ],
          ),
          const SizedBox(height: TdSpace.lg),
          FairnessHint(text: hint),
        ],
      ),
    );
  }
}

/// Hinweiszeile mit Funkel-Symbol (wie im Design-Entwurf „Heute“).
class FairnessHint extends StatelessWidget {
  const FairnessHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Container(
      padding: const EdgeInsets.all(TdSpace.md),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(
          alpha: td.isDark ? 0.18 : 0.08,
        ),
        borderRadius: TdRadius.control,
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: context.colors.primary,
            size: 20,
          ),
          const SizedBox(width: TdSpace.md),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
