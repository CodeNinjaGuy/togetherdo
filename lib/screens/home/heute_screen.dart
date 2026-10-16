/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/list/list_bloc.dart';
import '../../blocs/list/list_state.dart';
import '../../design/td_design.dart';
import '../../fairness/fairness.dart';
import '../../models/list_model.dart';
import '../../models/shopping_item_model.dart';
import '../../models/todo_model.dart';
import '../../models/user_model.dart';
import '../../navigation/kalender_platzhalter.dart';
import '../../repositories/shopping_repository.dart';
import '../../repositories/todo_repository.dart';
import '../../services/review_service.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/fairness/fairness_widgets.dart';
import '../../widgets/lists/list_sheets.dart';
import '../../widgets/lists/list_visuals.dart';
import '../../widgets/todo/task_editor_sheet.dart';
import '../../widgets/todo/todo_item_widget.dart';

/// Startseite „Heute“ mit echten Daten: Begrüßung und Fortschritt, heute
/// fällige Aufgaben aller Listen, Einkauf, Fairness und Kalender-Karte.
class HeuteScreen extends StatefulWidget {
  const HeuteScreen({super.key});

  @override
  State<HeuteScreen> createState() => _HeuteScreenState();
}

class _HeuteScreenState extends State<HeuteScreen> {
  List<ListModel> _lists = const [];
  String _todoKey = '';
  String _shopKey = '';
  Stream<List<TodoModel>>? _todos;
  Stream<List<ShoppingItemModel>>? _shopping;

  void _syncStreams(List<ListModel> lists) {
    _lists = lists;
    final todoIds = [
      for (final l in lists)
        if (l.type == ListType.todo) l.id,
    ]..sort();
    final shopIds = [
      for (final l in lists)
        if (l.type == ListType.shopping) l.id,
    ]..sort();
    final tk = todoIds.join(',');
    final sk = shopIds.join(',');
    if (tk != _todoKey) {
      _todoKey = tk;
      _todos = (context.read<TodoRepository>() as FirebaseTodoRepository)
          .todosForListsStream(todoIds);
    }
    if (sk != _shopKey) {
      _shopKey = sk;
      _shopping =
          (context.read<ShoppingRepository>() as FirebaseShoppingRepository)
              .openItemsForListsStream(shopIds);
    }
  }

  AuthAuthenticated? get _auth {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s : null;
  }

  List<FairnessMember> _membersOf(ListModel list, AppLocalizations l10n) =>
      fairnessMembersOf(list, fallbackName: (i) => '${l10n.member} ${i + 1}');

  bool _canEdit(ListModel list, String uid) =>
      list.ownerId == uid || (list.memberIds.contains(uid) && list.allowEdit);

  void _openTask(ListModel list, List<TodoModel> all, TodoModel? todo) {
    final auth = _auth;
    if (auth == null) return;
    final l10n = AppLocalizations.of(context)!;
    showTaskEditorSheet(
      context,
      listId: list.id,
      members: _membersOf(list, l10n),
      listTodos: all.where((t) => t.listId == list.id).toList(),
      currentUserId: auth.user.id,
      currentUserName: auth.user.displayName,
      todo: todo,
      canEdit: _canEdit(list, auth.user.id),
    );
  }

  Future<void> _newTask(List<TodoModel> all) async {
    final uid = _auth?.user.id ?? '';
    final candidates = [
      for (final l in _lists)
        if (l.type == ListType.todo && _canEdit(l, uid)) l,
    ];
    if (candidates.isEmpty) {
      await showCreateListSheet(context);
      return;
    }
    if (candidates.length == 1) {
      _openTask(candidates.first, all, null);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final chosen = await showTdSheet<ListModel>(
      context,
      title: l10n.chooseList,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final l in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: TdSpace.sm),
              child: TdCard(
                onTap: () => Navigator.of(ctx).pop(l),
                padding: const EdgeInsets.all(TdSpace.md),
                child: Row(
                  children: [
                    ListIconBadge(list: l, size: 40, hero: false),
                    const SizedBox(width: TdSpace.md),
                    Expanded(
                      child: Text(l.name, style: ctx.text.titleMedium),
                    ),
                    Icon(Icons.chevron_right_rounded, color: ctx.td.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (chosen != null && mounted) _openTask(chosen, all, null);
  }

  Future<void> _toggleShopping(ShoppingItemModel item, bool value) async {
    final auth = _auth;
    final repo = context.read<ShoppingRepository>();
    try {
      await repo.updateItem(
        ShoppingItemModel(
          id: item.id,
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          isPurchased: value,
          purchasedBy: value ? auth?.user.displayName : null,
          purchasedAt: value ? DateTime.now() : null,
          createdAt: item.createdAt,
          userId: item.userId,
          notes: item.notes,
          listId: item.listId,
          ean: item.ean,
          imageUrl: item.imageUrl,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      TdToast.show(
        context,
        AppLocalizations.of(context)!.saveFailed,
        variant: TdToastVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final auth = context.watch<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return const SizedBox.shrink();
    final user = auth.user;

    return BlocBuilder<ListBloc, ListState>(
      buildWhen: (_, s) => s is ListLoadSuccess || s is ListLoadFailure,
      builder: (context, state) {
        if (state is ListLoadSuccess) _syncStreams(state.lists);
        final lists = _lists;
        final loading = state is! ListLoadSuccess && lists.isEmpty;

        return StreamBuilder<List<TodoModel>>(
          stream: _todos,
          builder: (context, todoSnap) {
            final todos = todoSnap.data ?? const <TodoModel>[];
            return StreamBuilder<List<ShoppingItemModel>>(
              stream: _shopping,
              builder: (context, shopSnap) {
                final items = shopSnap.data ?? const <ShoppingItemModel>[];
                return Scaffold(
                  floatingActionButton: lists.isEmpty
                      ? null
                      : FloatingActionButton.extended(
                          heroTag: 'fab-heute',
                          onPressed: () => _newTask(todos),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.newTodoTitle),
                        ),
                  body: SafeArea(
                    bottom: false,
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : _content(context, l10n, user, lists, todos, items),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n,
    UserModel user,
    List<ListModel> lists,
    List<TodoModel> todos,
    List<ShoppingItemModel> items,
  ) {
    final uid = user.id;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day + 1);
    final startOfToday = DateTime(now.year, now.month, now.day);
    final weekStart = fairnessPeriodStart(FairnessPeriod.week, now);
    final byListId = {for (final l in lists) l.id: l};

    final dueToday =
        todos
            .where(
              (t) =>
                  !t.isCompleted &&
                  t.dueDate != null &&
                  t.dueDate!.isBefore(endOfToday),
            )
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final forMe = todos
        .where(
          (t) => !t.isCompleted && t.dueDate == null && t.assignedToUserId == uid,
        )
        .take(5)
        .toList();
    final doneToday = todos
        .where(
          (t) =>
              t.isCompleted &&
              t.completedAt != null &&
              !t.completedAt!.isBefore(startOfToday),
        )
        .length;
    final doneWeekByMe = todos
        .where(
          (t) =>
              t.isCompleted &&
              t.completedByUserId == uid &&
              (t.completedAt == null || !t.completedAt!.isBefore(weekStart)),
        )
        .length;

    // Fairness über alle geteilten Listen: Punkte je Person diese Woche.
    final sharedLists = lists
        .where((l) => l.type == ListType.todo && l.memberIds.isNotEmpty)
        .toList();
    final points = <String, double>{};
    final names = <String, FairnessMember>{};
    for (final l in sharedLists) {
      final members = _membersOf(l, l10n);
      for (final m in members) {
        names.putIfAbsent(m.id, () => m);
      }
      final stats = FairnessStats.compute(
        period: FairnessPeriod.week,
        members: members,
        todos: todos.where((t) => t.listId == l.id),
        now: now,
      );
      for (final s in stats.shares) {
        points[s.member.id] = (points[s.member.id] ?? 0) + s.points;
      }
    }
    final totalPoints = points.values.fold<double>(0, (a, b) => a + b);
    final myShare = totalPoints == 0 ? 0.0 : (points[uid] ?? 0) / totalPoints;

    final people = <TdAvatarData>[
      for (final m in names.values)
        avatarDataOf(m, imageUrl: UserAvatarCache.instance.peek(m.id)),
    ];
    if (people.isEmpty) {
      people.add(
        TdAvatarData(id: uid, name: user.displayName, imageUrl: user.avatarUrl),
      );
    }

    final todayTotal = dueToday.length + doneToday;
    final header = _Header(
      name: user.displayName,
      openCount: dueToday.length,
      doneRatio: todayTotal == 0 ? 1 : doneToday / todayTotal,
      people: people,
    );

    final stats = _StatsRow(
      open: dueToday.length,
      doneWeek: doneWeekByMe,
      share: sharedLists.isEmpty ? null : myShare * 100,
    );

    Widget tile(TodoModel t, int i) {
      final list = byListId[t.listId];
      if (list == null) return const SizedBox.shrink();
      return TodoItemWidget(
        key: ValueKey(t.id),
        todo: t,
        list: list,
        members: _membersOf(list, l10n),
        currentUserId: uid,
        canEdit: _canEdit(list, uid),
        index: i,
        accent: listColor(list),
        showListTag: true,
        onCompleted: ReviewService.instance.onTaskCompleted,
        onTap: () => _openTask(list, todos, t),
      );
    }

    final tasksSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdSectionHeader(
          title: l10n.sectionToday,
          subtitle: dueToday.isEmpty
              ? l10n.allDone
              : l10n.openToday(dueToday.length),
        ),
        if (dueToday.isEmpty)
          TdEmptyState(
            compact: true,
            icon: Icons.self_improvement_rounded,
            title: l10n.emptyTodayTitle,
            message: l10n.emptyTodayMessage,
          )
        else
          TdAnimatedList<TodoModel>(
            items: dueToday,
            keyOf: (t) => t.id,
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, t, i) => tile(t, i),
          ),
        if (forMe.isNotEmpty) ...[
          TdSectionHeader(title: l10n.sectionForYou, subtitle: l10n.noDueDate),
          TdAnimatedList<TodoModel>(
            items: forMe,
            keyOf: (t) => t.id,
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, t, i) => tile(t, i + dueToday.length),
          ),
        ],
      ],
    );

    final shoppingLists = lists.where((l) => l.type == ListType.shopping);
    ListModel? shopList;
    var best = -1;
    for (final l in shoppingLists) {
      final n = items.where((i) => i.listId == l.id).length;
      if (n > best) {
        best = n;
        shopList = l;
      }
    }
    final shoppingSection = shopList == null
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TdSectionHeader(
                title: l10n.sectionShopping,
                actionLabel: l10n.showAll,
                onAction: () => context.go('/shopping/${shopList!.id}'),
              ),
              _ShoppingCard(
                list: shopList,
                items: items.where((i) => i.listId == shopList!.id).toList(),
                onToggle: _toggleShopping,
                onOpen: () => context.go('/shopping/${shopList!.id}'),
              ),
            ],
          );

    final fairnessSection = sharedLists.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TdSectionHeader(
                title: l10n.sectionFairness,
                subtitle: l10n.fairnessThisWeek,
              ),
              _FairnessOverview(
                shares: [
                  for (final m in names.values)
                    TdFairnessShare(
                      person: m.id == uid
                          ? TdAvatarData(
                              id: uid,
                              name: l10n.fairnessYou,
                              color: avatarDataOf(m).resolveColor(),
                              imageUrl: UserAvatarCache.instance.peek(uid),
                            )
                          : avatarDataOf(
                              m,
                              imageUrl: UserAvatarCache.instance.peek(m.id),
                            ),
                      value: points[m.id] ?? 0,
                    ),
                ],
                uid: uid,
                total: totalPoints,
              ),
            ],
          );

    final calendarSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdSectionHeader(title: l10n.navCalendar),
        HeuteKalenderSlot(
          listIds: [for (final l in lists) l.id],
          onOpen: () => context.go('/kalender'),
        ),
      ],
    );

    if (lists.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          TdSpace.page,
          TdSpace.lg,
          TdSpace.page,
          120,
        ),
        children: [
          TdFadeSlideIn(index: 0, child: header),
          const SizedBox(height: TdSpace.xl),
          TdEmptyState(
            icon: Icons.playlist_add_rounded,
            title: l10n.noLists,
            message: l10n.createOrJoinList,
            action: Wrap(
              spacing: TdSpace.sm,
              runSpacing: TdSpace.sm,
              alignment: WrapAlignment.center,
              children: [
                TdButton.primary(
                  label: l10n.createList,
                  icon: Icons.add_rounded,
                  onPressed: () => showCreateListSheet(context),
                ),
                TdButton.secondary(
                  label: l10n.joinList,
                  icon: Icons.group_add_rounded,
                  onPressed: () => showJoinListSheet(context),
                ),
              ],
            ),
          ),
          calendarSection,
        ],
      );
    }

    final wide = context.tdLayout != TdLayoutSize.compact;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TdSpace.page,
        TdSpace.lg,
        TdSpace.page,
        120,
      ),
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
                  children: [calendarSection, fairnessSection, shoppingSection],
                ),
              ),
            ],
          )
        else ...[
          tasksSection,
          calendarSection,
          shoppingSection,
          fairnessSection,
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.openCount,
    required this.doneRatio,
    required this.people,
  });

  final String name;
  final int openCount;
  final double doneRatio;
  final List<TdAvatarData> people;

  String _date(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMMEEEEd(locale).format(DateTime.now());
  }

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 11) return l10n.greetingMorning(name);
    if (hour < 18) return l10n.greetingDay(name);
    return l10n.greetingEvening(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      _greeting(l10n),
                      style: context.text.headlineLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: TdSpace.xs),
                    Text(
                      l10n.tagline,
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
              TdAvatarStack(people: people, size: 30),
              const SizedBox(width: TdSpace.md),
              Expanded(
                child: Text(
                  l10n.teamCount(people.length),
                  style: context.text.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.open,
    required this.doneWeek,
    required this.share,
  });

  final int open;
  final int doneWeek;
  final double? share;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final td = context.td;
    final scheme = context.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              value: open,
              label: l10n.statOpen,
              icon: Icons.radio_button_unchecked_rounded,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: TdSpace.md),
          Expanded(
            child: _StatCard(
              value: doneWeek,
              label: l10n.statDoneWeek,
              icon: Icons.check_circle_rounded,
              color: td.success,
            ),
          ),
          if (share != null) ...[
            const SizedBox(width: TdSpace.md),
            Expanded(
              child: _StatCard(
                value: share!,
                format: (v) => l10n.fairnessPercent(v.round()),
                label: l10n.statFairness,
                icon: Icons.balance_rounded,
                color: scheme.secondary,
              ),
            ),
          ],
        ],
      ),
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

  final ListModel list;
  final List<ShoppingItemModel> items;
  final void Function(ShoppingItemModel, bool) onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = listColor(list);
    final sorted = items.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
                  ListIconBadge(list: list, size: 40),
                  const SizedBox(width: TdSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list.name, style: context.text.titleMedium),
                        Text(
                          l10n.itemsLeft(items.length),
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (sorted.isNotEmpty) const SizedBox(height: TdSpace.md),
          for (final item in sorted.take(3))
            Padding(
              key: ValueKey(item.id),
              padding: const EdgeInsets.only(bottom: TdSpace.sm),
              child: TdTaskTile(
                dense: true,
                title: item.name,
                subtitle: item.notes,
                done: item.isPurchased,
                accent: color,
                leadingLabel: item.displayQuantity,
                celebrate: false,
                onChanged: (v) => onToggle(item, v),
              ),
            ),
        ],
      ),
    );
  }
}

class _FairnessOverview extends StatelessWidget {
  const _FairnessOverview({
    required this.shares,
    required this.uid,
    required this.total,
  });

  final List<TdFairnessShare> shares;
  final String uid;
  final double total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String hint;
    if (total < FairnessStats.minPointsForVerdict) {
      hint = l10n.fairnessNothingYet;
    } else {
      final top = shares.reduce((a, b) => a.value >= b.value ? a : b);
      final fair = total / shares.length;
      final balanced = shares.every(
        (s) => (s.value - fair).abs() / total <= FairnessStats.tolerance,
      );
      hint = balanced
          ? l10n.fairnessBalanced
          : (top.person.id == uid
                ? l10n.fairnessTopCarrierYou
                : l10n.fairnessTopCarrier(top.person.name));
    }
    return TdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TdFairnessBar(
            shares: shares,
            percentFormat: (p) => l10n.fairnessPercent(p.round()),
          ),
          const SizedBox(height: TdSpace.lg),
          FairnessHint(text: hint),
        ],
      ),
    );
  }
}
