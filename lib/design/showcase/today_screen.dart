/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../td_design.dart';
import 'showcase_data.dart';
import 'showcase_strings.dart';
import 'showcase_theme_scope.dart';

/// Vorzeige-Entwurf des künftigen Startbildschirms „Heute“.
/// Läuft mit Beispieldaten, ohne Firebase. Zeigt den Stil: Begrüßung mit
/// Verlauf, Kennzahlen, heutige Aufgaben aller Listen (abhakbar mit
/// Konfetti), Einkauf, Fairness-Karte und Schnellaktion „Neue Aufgabe“.
class TdTodayScreen extends StatefulWidget {
  const TdTodayScreen({super.key, this.onOpenGallery, this.userName = 'Martin'});

  /// Öffnet die Design-Galerie (nur im Debug-Einstieg gesetzt).
  final VoidCallback? onOpenGallery;
  final String userName;

  @override
  State<TdTodayScreen> createState() => _TdTodayScreenState();
}

class _TdTodayScreenState extends State<TdTodayScreen> {
  final List<DemoTask> _tasks = DemoData.tasks();
  final List<DemoTask> _shopping = DemoData.shopping();
  int _tab = 0;
  int _doneThisWeek = 14;

  List<DemoTask> get _sortedTasks {
    final open = _tasks.where((t) => !t.done).toList()
      ..sort((a, b) => a.due.index.compareTo(b.due.index));
    final done = _tasks.where((t) => t.done).toList();
    return [...open, ...done];
  }

  void _toggle(DemoTask task, bool value) {
    setState(() {
      task.done = value;
      _doneThisWeek += value ? 1 : -1;
    });
  }

  void _delete(DemoTask task) {
    final index = _tasks.indexOf(task);
    setState(() => _tasks.remove(task));
    final s = ShowcaseStrings.of(context);
    TdToast.show(
      context,
      s.taskDeleted,
      variant: TdToastVariant.info,
      icon: Icons.delete_outline_rounded,
      actionLabel: s.undo,
      onAction: () => setState(() => _tasks.insert(index.clamp(0, _tasks.length), task)),
    );
  }

  Future<void> _newTask() async {
    final created = await showTdSheet<DemoTask>(
      context,
      title: ShowcaseStrings.of(context).newTask,
      builder: (ctx) => _NewTaskForm(),
    );
    if (created == null || !mounted) return;
    setState(() => _tasks.insert(0, created));
    TdToast.show(
      context,
      ShowcaseStrings.of(context).taskCreated(created.title),
      variant: TdToastVariant.success,
    );
  }

  void _openList(DemoList list) {
    final tasks = list.isShopping
        ? _shopping
        : _tasks.where((t) => t.listId == list.id).toList();
    Navigator.of(context).push(
      TdPageRoute(
        builder: (_) => TdListDetailScreen(
          list: list,
          tasks: tasks,
          onToggle: _toggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ShowcaseStrings.of(context);
    final destinations = [
      TdDestination(icon: Icons.wb_sunny_outlined, selectedIcon: Icons.wb_sunny_rounded, label: s.navToday),
      TdDestination(icon: Icons.checklist_rounded, label: s.navLists),
      TdDestination(icon: Icons.balance_outlined, selectedIcon: Icons.balance_rounded, label: s.navFair),
      TdDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: s.navProfile),
    ];

    return TdAdaptiveScaffold(
      destinations: destinations,
      selectedIndex: _tab,
      onSelected: (i) => setState(() => _tab = i),
      railHeader: const TdAvatar(data: DemoData.me, size: 40),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _newTask,
              icon: const Icon(Icons.add_rounded),
              label: Text(s.newTask),
            )
          : null,
      body: _tab == 0
          ? _buildToday(context, s)
          : Center(
              child: TdEmptyState(
                icon: destinations[_tab].selectedIcon,
                title: destinations[_tab].label,
                message: s.comingLater,
              ),
            ),
    );
  }

  Widget _buildToday(BuildContext context, ShowcaseStrings s) {
    final layout = context.tdLayout;
    final wide = layout != TdLayoutSize.compact;
    final openCount = _tasks.where((t) => !t.done).length;
    final total = _tasks.length;

    final header = _TodayHeader(
      userName: widget.userName,
      openCount: openCount,
      doneRatio: total == 0 ? 1 : (total - openCount) / total,
      onOpenGallery: widget.onOpenGallery,
    );

    final stats = _StatsRow(
      open: openCount,
      doneWeek: _doneThisWeek,
      myShare: _myShare(),
    );

    final tasksSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdSectionHeader(
          title: s.sectionToday,
          subtitle: openCount == 0 ? s.allDone : s.openToday(openCount),
        ),
        if (openCount == 0)
          TdEmptyState(
            compact: true,
            icon: Icons.self_improvement_rounded,
            title: s.emptyTitle,
            message: s.emptyMessage,
          ),
        TdAnimatedList<DemoTask>(
          items: _sortedTasks,
          keyOf: (t) => t.id,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, task, index) {
            final list = DemoData.listById(task.listId);
            return TdFadeSlideIn(
              index: index,
              child: TdTaskTile(
                heroTag: 'task-${task.id}',
                title: task.title,
                subtitle: task.subtitle,
                done: task.done,
                accent: list.color,
                assignee: task.assignee,
                onChanged: (v) => _toggle(task, v),
                onDelete: () => _delete(task),
                onTap: () => _openList(list),
                tags: [
                  TdTag(label: list.name, color: list.color, icon: list.icon),
                  _dueTag(task.due, s),
                  TdWeightTag(weight: task.weight),
                ],
              ),
            );
          },
        ),
      ],
    );

    final shoppingList = DemoData.lists.firstWhere((l) => l.isShopping);
    final shoppingSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdSectionHeader(
          title: s.sectionShopping,
          actionLabel: s.showAll,
          onAction: () => _openList(shoppingList),
        ),
        _ShoppingCard(
          list: shoppingList,
          items: _shopping,
          onToggle: _toggle,
          onOpen: () => _openList(shoppingList),
        ),
      ],
    );

    final fairnessSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdSectionHeader(title: s.sectionFairness, subtitle: s.thisWeek),
        _FairnessCard(),
      ],
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(TdSpace.page, TdSpace.lg, TdSpace.page, 120),
          sliver: SliverList.list(
            children: [
              TdFadeSlideIn(index: 0, child: header),
              const SizedBox(height: TdSpace.lg),
              TdFadeSlideIn(index: 1, child: stats),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: tasksSection),
                    const SizedBox(width: TdSpace.xl),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [fairnessSection, shoppingSection],
                      ),
                    ),
                  ],
                )
              else ...[
                tasksSection,
                shoppingSection,
                fairnessSection,
              ],
            ],
          ),
        ),
      ],
    );
  }

  double _myShare() {
    final total = DemoData.weekPoints.values.fold<double>(0, (a, b) => a + b);
    return total == 0 ? 0 : (DemoData.weekPoints['me'] ?? 0) / total * 100;
  }

  Widget _dueTag(DemoDue due, ShowcaseStrings s) {
    final td = context.td;
    return switch (due) {
      DemoDue.overdue => TdTag(label: s.overdue, color: td.danger, icon: Icons.schedule_rounded),
      DemoDue.tonight => TdTag(label: s.dueTonight, color: td.warning, icon: Icons.nightlight_round),
      DemoDue.today => TdTag(label: s.dueToday, icon: Icons.today_rounded, filled: false),
      DemoDue.later => const SizedBox.shrink(),
    };
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.userName,
    required this.openCount,
    required this.doneRatio,
    this.onOpenGallery,
  });

  final String userName;
  final int openCount;
  final double doneRatio;
  final VoidCallback? onOpenGallery;

  String _date(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    try {
      return DateFormat.yMMMMEEEEd(locale).format(DateTime.now());
    } catch (_) {
      return DateFormat.yMMMMEEEEd().format(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ShowcaseStrings.of(context);
    final scope = ShowcaseThemeScope.maybeOf(context);
    final hour = DateTime.now().hour;

    return TdCard(
      variant: TdCardVariant.gradient,
      padding: const EdgeInsets.all(TdSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _date(context),
                      style: context.text.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: TdSpace.xs),
                    Text(
                      s.greeting(userName, hour),
                      style: context.text.headlineLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: TdSpace.xs),
                    Text(
                      s.tagline,
                      style: context.text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TdSpace.lg),
              TdRingProgress(
                value: doneRatio,
                size: 68,
                stroke: 7,
                color: Colors.white,
                trackColor: Colors.white.withValues(alpha: 0.25),
                child: TdAnimatedCounter(
                  value: doneRatio * 100,
                  format: (v) => '${v.round()}%',
                  style: context.text.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: TdSpace.xl),
          Row(
            children: [
              TdAvatarStack(people: DemoData.people, size: 30),
              const SizedBox(width: TdSpace.md),
              Expanded(
                child: Text(
                  s.household,
                  style: context.text.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
              if (scope != null) ...[
                _GlassIconButton(
                  icon: scope.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  onTap: scope.toggleMode,
                ),
                const SizedBox(width: TdSpace.sm),
              ],
              if (onOpenGallery != null)
                _GlassIconButton(icon: Icons.palette_outlined, onTap: onOpenGallery!),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TdPressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: TdRadius.control,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.open, required this.doneWeek, required this.myShare});

  final int open;
  final int doneWeek;
  final double myShare;

  @override
  Widget build(BuildContext context) {
    final s = ShowcaseStrings.of(context);
    final td = context.td;
    final scheme = context.colors;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: open,
            label: s.statOpen,
            icon: Icons.radio_button_unchecked_rounded,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: TdSpace.md),
        Expanded(
          child: _StatCard(
            value: doneWeek,
            label: s.statDoneWeek,
            icon: Icons.check_circle_rounded,
            color: td.success,
          ),
        ),
        const SizedBox(width: TdSpace.md),
        Expanded(
          child: _StatCard(
            value: myShare,
            format: (v) => '${v.round()} %',
            label: s.statFairness,
            icon: Icons.balance_rounded,
            color: scheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.format,
  });

  final num value;
  final String label;
  final IconData icon;
  final Color color;
  final String Function(num)? format;

  @override
  Widget build(BuildContext context) {
    return TdCard(
      variant: TdCardVariant.elevated,
      padding: const EdgeInsets.all(TdSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: TdSpace.sm),
          TdAnimatedCounter(
            value: value,
            format: format,
            style: context.text.headlineMedium,
          ),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelSmall, maxLines: 2),
        ],
      ),
    );
  }
}

class _ShoppingCard extends StatelessWidget {
  const _ShoppingCard({
    required this.list,
    required this.items,
    required this.onToggle,
    required this.onOpen,
  });

  final DemoList list;
  final List<DemoTask> items;
  final void Function(DemoTask, bool) onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = ShowcaseStrings.of(context);
    final left = items.where((i) => !i.done).length;
    return TdCard(
      padding: const EdgeInsets.all(TdSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TdPressable(
            onTap: onOpen,
            scale: 0.98,
            child: Padding(
              padding: const EdgeInsets.all(TdSpace.xs),
              child: Row(
                children: [
                  Hero(
                    tag: 'list-icon-${list.id}',
                    child: _ListIcon(list: list, size: 40),
                  ),
                  const SizedBox(width: TdSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list.name, style: context.text.titleMedium),
                        Text(s.itemsLeft(left), style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: TdSpace.md),
          for (final item in items.where((i) => !i.done).take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: TdSpace.sm),
              child: TdTaskTile(
                dense: true,
                title: item.title,
                subtitle: item.subtitle,
                done: item.done,
                accent: list.color,
                leadingLabel: item.quantity,
                onChanged: (v) => onToggle(item, v),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListIcon extends StatelessWidget {
  const _ListIcon({required this.list, required this.size});

  final DemoList list;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [list.color, Color.lerp(list.color, Colors.white, 0.3)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: TdShadows.glow(list.color),
      ),
      alignment: Alignment.center,
      child: Icon(list.icon, color: Colors.white, size: size * 0.52),
    );
  }
}

class _FairnessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = ShowcaseStrings.of(context);
    final td = context.td;
    final shares = [
      for (final p in DemoData.people)
        TdFairnessShare(
          person: p.id == 'me' ? TdAvatarData(id: 'me', name: s.you, color: p.color) : p,
          value: DemoData.weekPoints[p.id] ?? 0,
        ),
    ];
    final top = shares.reduce((a, b) => a.value >= b.value ? a : b);
    final me = shares.firstWhere((x) => x.person.id == 'me');
    final hint = top.value > me.value * 1.2 ? s.fairnessHint(top.person.name) : s.fairnessBalanced;

    return TdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TdFairnessBar(shares: shares),
          const SizedBox(height: TdSpace.lg),
          Container(
            padding: const EdgeInsets.all(TdSpace.md),
            decoration: BoxDecoration(
              color: context.colors.secondaryContainer.withValues(alpha: td.isDark ? 0.5 : 1),
              borderRadius: TdRadius.control,
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: context.colors.secondary, size: 20),
                const SizedBox(width: TdSpace.md),
                Expanded(
                  child: Text(
                    hint,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Formular im Sheet: Titel, Liste, Aufwand, Person (mit Vorschlag).
class _NewTaskForm extends StatefulWidget {
  @override
  State<_NewTaskForm> createState() => _NewTaskFormState();
}

class _NewTaskFormState extends State<_NewTaskForm> {
  final _title = TextEditingController();
  String _listId = 'haus';
  TdWeight _weight = TdWeight.medium;
  TdAvatarData? _assignee = DemoData.leo; // wenigste Punkte → Vorschlag

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      DemoTask(
        id: 'new-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        listId: _listId,
        assignee: _assignee,
        weight: _weight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ShowcaseStrings.of(context);
    final lists = DemoData.lists.where((l) => !l.isShopping);
    final weightLabel = {
      TdWeight.light: s.weightLight,
      TdWeight.medium: s.weightMedium,
      TdWeight.heavy: s.weightHeavy,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TdTextField(
          controller: _title,
          label: s.taskTitleLabel,
          hint: s.taskTitleHint,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: TdSpace.xl),
        Text(s.listLabel, style: context.text.labelMedium),
        const SizedBox(height: TdSpace.sm),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final l in lists)
              TdChip(
                label: l.name,
                icon: l.icon,
                color: l.color,
                selected: _listId == l.id,
                onTap: () => setState(() => _listId = l.id),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.xl),
        Text(s.weightLabel, style: context.text.labelMedium),
        const SizedBox(height: TdSpace.sm),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final w in TdWeight.values)
              TdChip(
                label: weightLabel[w]!,
                leading: TdWeightTag(weight: w),
                selected: _weight == w,
                onTap: () => setState(() => _weight = w),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.xl),
        Text(s.assigneeLabel, style: context.text.labelMedium),
        const SizedBox(height: TdSpace.sm),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final p in DemoData.people)
              TdChip(
                label: p.id == 'me' ? s.you : p.name,
                leading: TdAvatar(data: p, size: 20),
                color: p.color,
                selected: _assignee?.id == p.id,
                onTap: () => setState(() => _assignee = p),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.sm),
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: context.colors.secondary),
            const SizedBox(width: TdSpace.xs),
            Text(
              '${s.suggestedTurn}: ${DemoData.leo.name}',
              style: context.text.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: TdSpace.xxl),
        Row(
          children: [
            Expanded(
              child: TdButton.secondary(
                label: s.cancel,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: TdSpace.md),
            Expanded(
              flex: 2,
              child: ValueListenableBuilder(
                valueListenable: _title,
                builder: (context, value, _) => TdButton.primary(
                  label: s.create,
                  icon: Icons.add_rounded,
                  expanded: true,
                  onPressed: value.text.trim().isEmpty ? null : _submit,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Detailseite einer Liste (Ziel des Hero-Übergangs).
class TdListDetailScreen extends StatefulWidget {
  const TdListDetailScreen({
    super.key,
    required this.list,
    required this.tasks,
    required this.onToggle,
  });

  final DemoList list;
  final List<DemoTask> tasks;
  final void Function(DemoTask, bool) onToggle;

  @override
  State<TdListDetailScreen> createState() => _TdListDetailScreenState();
}

class _TdListDetailScreenState extends State<TdListDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ShowcaseStrings.of(context);
    final list = widget.list;
    final done = widget.tasks.where((t) => t.done).length;
    final total = widget.tasks.length;

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(TdSpace.page, 0, TdSpace.page, TdSpace.xxxl),
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'list-icon-${list.id}',
                    child: _ListIcon(list: list, size: 64),
                  ),
                  const SizedBox(width: TdSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list.name, style: context.text.headlineMedium),
                        const SizedBox(height: TdSpace.xs),
                        Row(
                          children: [
                            TdAvatarStack(people: DemoData.people, size: 24),
                            const SizedBox(width: TdSpace.sm),
                            Text(
                              '${DemoData.people.length} ${s.detailMembers}',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TdSpace.xl),
              TdFadeSlideIn(
                child: TdCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(s.detailProgress, style: context.text.titleMedium)),
                          Text(s.doneOf(done, total), style: context.text.bodySmall),
                        ],
                      ),
                      const SizedBox(height: TdSpace.md),
                      TdProgressBar(
                        value: total == 0 ? 0 : done / total,
                        gradient: LinearGradient(
                          colors: [list.color, Color.lerp(list.color, Colors.white, 0.3)!],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: TdSpace.xl),
              for (final (i, task) in widget.tasks.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: TdSpace.sm),
                  child: TdFadeSlideIn(
                    index: i + 1,
                    child: TdTaskTile(
                      heroTag: 'task-${task.id}',
                      title: task.title,
                      subtitle: task.subtitle,
                      done: task.done,
                      accent: list.color,
                      assignee: task.assignee,
                      leadingLabel: task.quantity,
                      tags: list.isShopping ? const [] : [TdWeightTag(weight: task.weight)],
                      onChanged: (v) {
                        widget.onToggle(task, v);
                        setState(() {});
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
