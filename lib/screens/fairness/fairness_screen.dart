/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../../fairness/fairness.dart';
import '../../models/todo_model.dart';
import '../../repositories/todo_repository.dart';
import '../../widgets/fairness/fairness_widgets.dart';

/// Statistik „Wer trägt wie viel“ einer Liste: Woche oder Monat, Anteil
/// je Mitglied nach Punkten und die zuletzt erledigten Aufgaben.
class FairnessScreen extends StatefulWidget {
  const FairnessScreen({
    super.key,
    required this.listId,
    required this.listName,
    required this.members,
    required this.currentUserId,
    this.initialPeriod = FairnessPeriod.week,
  });

  final String listId;
  final String listName;
  final List<FairnessMember> members;
  final String currentUserId;
  final FairnessPeriod initialPeriod;

  @override
  State<FairnessScreen> createState() => _FairnessScreenState();
}

class _FairnessScreenState extends State<FairnessScreen> {
  late FairnessPeriod _period = widget.initialPeriod;
  late final Stream<List<TodoModel>> _done;
  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final repo = context.read<TodoRepository>() as FirebaseTodoRepository;
    _done = repo.completedSinceStream(widget.listId, fairnessQueryStart(_now));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fairnessStatsTitle)),
      body: StreamBuilder<List<TodoModel>>(
        stream: _done,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${l10n.loadError}: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = FairnessStats.compute(
            period: _period,
            members: widget.members,
            todos: snap.data!,
            now: _now,
          );
          final recent =
              snap.data!
                  .where((t) => FairnessStats.countsAsDone(t, stats.start))
                  .toList()
                ..sort(
                  (a, b) =>
                      (b.completedAt ?? _now).compareTo(a.completedAt ?? _now),
                );
          return _buildBody(context, l10n, stats, recent);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    FairnessStats stats,
    List<TodoModel> recent,
  ) {
    String name(FairnessMember m) =>
        memberDisplayName(l10n, m, widget.currentUserId);
    final byId = {for (final m in widget.members) m.id: m};
    final locale = Localizations.localeOf(context).toLanguageTag();
    final timeFmt = DateFormat.MMMEd(locale).add_Hm();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TdSpace.page,
        TdSpace.lg,
        TdSpace.page,
        TdSpace.xxxl,
      ),
      children: [
        Text(widget.listName, style: context.text.headlineSmall),
        const SizedBox(height: TdSpace.md),
        Row(
          children: [
            TdChip(
              label: l10n.fairnessThisWeek,
              selected: _period == FairnessPeriod.week,
              onTap: () => setState(() => _period = FairnessPeriod.week),
            ),
            const SizedBox(width: TdSpace.sm),
            TdChip(
              label: l10n.fairnessThisMonth,
              selected: _period == FairnessPeriod.month,
              onTap: () => setState(() => _period = FairnessPeriod.month),
            ),
          ],
        ),
        const SizedBox(height: TdSpace.lg),
        TdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TdAnimatedCounter(
                    value: stats.totalPoints,
                    style: context.text.displaySmall,
                  ),
                  const SizedBox(width: TdSpace.sm),
                  Expanded(
                    child: Text(
                      '${l10n.fairnessPointsTotal} · '
                      '${l10n.fairnessTasks(stats.totalTasks)}',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.td.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TdSpace.lg),
              TdFairnessBar(
                key: ValueKey(_period),
                showLegend: false,
                shares: [
                  for (final s in stats.shares)
                    TdFairnessShare(
                      person: avatarDataOf(s.member),
                      value: s.points.toDouble(),
                    ),
                ],
              ),
              const SizedBox(height: TdSpace.lg),
              for (final s in stats.shares) ...[
                _MemberRow(
                  share: s,
                  name: name(s.member),
                  pointsLabel: l10n.fairnessPoints(s.points),
                  tasksLabel: l10n.fairnessTasks(s.tasks),
                  percentLabel: l10n.fairnessPercent((s.share * 100).round()),
                ),
                const SizedBox(height: TdSpace.md),
              ],
              if (stats.shares.length < 2)
                FairnessHint(text: l10n.fairnessShareList)
              else if (stats.isBalanced)
                FairnessHint(text: l10n.fairnessBalanced)
              else if (stats.isEmpty)
                FairnessHint(text: l10n.fairnessNothingYet),
              const SizedBox(height: TdSpace.sm),
              Text(
                l10n.fairnessPointsLegend,
                style: context.text.labelSmall?.copyWith(
                  color: context.td.muted,
                ),
              ),
            ],
          ),
        ),
        if (recent.isNotEmpty) ...[
          TdSectionHeader(title: l10n.fairnessRecentlyDone),
          TdCard(
            padding: const EdgeInsets.symmetric(vertical: TdSpace.sm),
            child: Column(
              children: [
                for (final t in recent.take(30))
                  ListTile(
                    leading: byId[t.completedByUserId] != null
                        ? MemberAvatar(member: byId[t.completedByUserId]!)
                        : TdAvatar(
                            data: TdAvatarData(
                              name: t.completedByUserName ?? '?',
                            ),
                            size: 32,
                          ),
                    title: Text(t.title),
                    subtitle: Text(
                      l10n.completedByAt(
                        byId[t.completedByUserId] != null
                            ? name(byId[t.completedByUserId]!)
                            : (t.completedByUserName ?? l10n.unknown),
                        timeFmt.format(t.completedAt ?? _now),
                      ),
                    ),
                    trailing: TdWeightTag(weight: tdWeightOf(t.effort)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.share,
    required this.name,
    required this.pointsLabel,
    required this.tasksLabel,
    required this.percentLabel,
  });

  final MemberShare share;
  final String name;
  final String pointsLabel;
  final String tasksLabel;
  final String percentLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MemberAvatar(member: share.member, size: 36),
        const SizedBox(width: TdSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: context.text.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(percentLabel, style: context.text.titleSmall),
                ],
              ),
              const SizedBox(height: TdSpace.xs),
              TdProgressBar(
                value: share.share,
                height: 8,
                color: share.member.id.isEmpty
                    ? null
                    : avatarDataOf(share.member).resolveColor(),
              ),
              const SizedBox(height: TdSpace.xs),
              Text(
                '$pointsLabel · $tasksLabel',
                style: context.text.labelSmall?.copyWith(
                  color: context.td.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
