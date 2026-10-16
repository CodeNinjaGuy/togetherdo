/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../design/td_design.dart';
import '../../fairness/fairness.dart';
import '../../models/list_model.dart';
import '../../models/todo_model.dart';
import '../../repositories/list_repository.dart';
import '../../repositories/todo_repository.dart';
import '../../services/review_service.dart';
import '../../widgets/fairness/fairness_widgets.dart';
import '../../widgets/lists/list_visuals.dart';
import '../../widgets/todo/task_editor_sheet.dart';
import '../../widgets/todo/todo_item_widget.dart';
import '../fairness/fairness_screen.dart';

enum _GroupBy { status, person }

enum _SortBy { due, priority, created }

/// Aufgaben einer Liste: Kopf mit Fortschritt, Fairness-Karte, Filter,
/// animierte Aufgabenzeilen mit Abhaken, Wischen und Chat.
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key, required this.listId});

  final String listId;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  late final FirebaseTodoRepository _todoRepository;
  late final FirebaseListRepository _listRepository;

  _GroupBy _groupBy = _GroupBy.status;
  _SortBy _sortBy = _SortBy.due;
  bool _showDone = true;

  late final Stream<ListModel?> _listStream;
  late final Stream<List<TodoModel>> _todosStream;
  late final Stream<List<TodoModel>> _doneStream;

  /// Stand der laufenden Woche (für die Bewertungsanfrage nach Erfolg).
  FairnessStats? _weekStats;

  @override
  void initState() {
    super.initState();
    _todoRepository = context.read<TodoRepository>() as FirebaseTodoRepository;
    _listRepository = context.read<ListRepository>() as FirebaseListRepository;
    _listStream = _listRepository.getListByIdStream(widget.listId);
    _todosStream = _todoRepository.getTodosStream(widget.listId);
    _doneStream = _todoRepository.completedSinceStream(
      widget.listId,
      fairnessQueryStart(DateTime.now()),
    );
  }

  List<FairnessMember> _membersOf(ListModel list, AppLocalizations l10n) =>
      fairnessMembersOf(list, fallbackName: (i) => '${l10n.member} ${i + 1}');

  AuthAuthenticated? get _auth {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s : null;
  }

  void _openEditor(
    ListModel list,
    List<TodoModel> todos,
    bool canEdit, [
    TodoModel? todo,
  ]) {
    final auth = _auth;
    if (auth == null) return;
    showTaskEditorSheet(
      context,
      listId: widget.listId,
      members: _membersOf(list, AppLocalizations.of(context)!),
      listTodos: todos,
      currentUserId: auth.user.id,
      currentUserName: auth.user.displayName,
      todo: todo,
      canEdit: canEdit,
    );
  }

  void _openStats(ListModel list, String currentUserId) {
    Navigator.of(context).push(
      TdPageRoute(
        builder: (_) => FairnessScreen(
          listId: list.id,
          listName: list.name,
          members: _membersOf(list, AppLocalizations.of(context)!),
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  /// Eigene Aufgabe erfolgreich abgehakt: Erfolg für die Bewertungsanfrage.
  Future<void> _onCompleted() async {
    await ReviewService.instance.onTaskCompleted();
    final week = _weekStats;
    if (week != null && week.isBalanced) {
      await ReviewService.instance.onFairWeek(week.start);
    }
  }

  List<TodoModel> _sorted(Iterable<TodoModel> todos) {
    final list = todos.toList();
    switch (_sortBy) {
      case _SortBy.due:
        list.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case _SortBy.priority:
        list.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      case _SortBy.created:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final currentUserId = _auth?.user.id ?? '';

    return StreamBuilder<ListModel?>(
      stream: _listStream,
      builder: (context, listSnap) {
        final list = listSnap.data;
        final isOwner = list?.ownerId == currentUserId;
        final isMember = list?.memberIds.contains(currentUserId) ?? false;
        final canEdit = isOwner || (isMember && (list?.allowEdit ?? false));

        return StreamBuilder<List<TodoModel>>(
          stream: _todosStream,
          builder: (context, todoSnap) {
            final todos = todoSnap.data ?? const <TodoModel>[];
            return Scaffold(
              floatingActionButton: list != null && canEdit
                  ? FloatingActionButton.extended(
                      heroTag: 'fab-todo',
                      onPressed: () => _openEditor(list, todos, true),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.newTodoTitle),
                    )
                  : null,
              body: SafeArea(
                bottom: false,
                child: _body(
                  context,
                  l10n,
                  listSnap,
                  todoSnap,
                  currentUserId,
                  canEdit,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    AsyncSnapshot<ListModel?> listSnap,
    AsyncSnapshot<List<TodoModel>> todoSnap,
    String currentUserId,
    bool canEdit,
  ) {
    if (listSnap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = listSnap.data;
    if (list == null) {
      return Center(
        child: TdEmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.listNotFound,
          action: TdButton.secondary(
            label: l10n.navLists,
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.go('/lists'),
          ),
        ),
      );
    }
    if (todoSnap.hasError) {
      return Center(
        child: TdEmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.loadError,
          message: '${todoSnap.error}',
        ),
      );
    }
    final todos = todoSnap.data ?? const <TodoModel>[];
    final members = _membersOf(list, l10n);
    final shared = list.memberIds.isNotEmpty;
    final color = listColor(list);
    final done = todos.where((t) => t.isCompleted).length;
    final compact = context.tdIsCompact;

    final header = Row(
      children: [
        if (compact)
          Padding(
            padding: const EdgeInsets.only(right: TdSpace.sm),
            child: TdIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: l10n.navLists,
              size: 40,
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/lists'),
            ),
          ),
        Expanded(
          child: ListHeader(
            list: list,
            iconSize: compact ? 52 : 64,
            subtitle: l10n.memberCount(list.memberCount),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!canEdit)
                  Tooltip(
                    message: l10n.readOnlyMode,
                    triggerMode: TooltipTriggerMode.tap,
                    child: TdTag(
                      label: l10n.readOnly,
                      icon: Icons.lock_outline_rounded,
                      filled: false,
                    ),
                  ),
                if (shared) ...[
                  const SizedBox(width: TdSpace.sm),
                  TdIconButton(
                    icon: Icons.balance_rounded,
                    tooltip: l10n.fairnessShowStats,
                    size: 40,
                    onPressed: () => _openStats(list, currentUserId),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    final progress = TdCard(
      padding: const EdgeInsets.all(TdSpace.lg),
      child: Row(
        children: [
          TdRingProgress(
            value: todos.isEmpty ? 0 : done / todos.length,
            size: 54,
            stroke: 6,
            color: color,
            child: TdAnimatedCounter(
              value: todos.isEmpty ? 0 : done / todos.length * 100,
              format: (v) => '${v.round()}%',
              style: context.text.labelMedium,
            ),
          ),
          const SizedBox(width: TdSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.progress, style: context.text.titleMedium),
                const SizedBox(height: TdSpace.xs),
                Text(
                  l10n.doneOf(done, todos.length),
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: TdSpace.sm),
                TdProgressBar(
                  value: todos.isEmpty ? 0 : done / todos.length,
                  height: 8,
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.white, 0.3)!],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget? fairness;
    if (shared) {
      fairness = StreamBuilder<List<TodoModel>>(
        stream: _doneStream,
        builder: (context, doneSnap) {
          final doneTodos = doneSnap.data ?? const <TodoModel>[];
          final now = DateTime.now();
          _weekStats = FairnessStats.compute(
            period: FairnessPeriod.week,
            members: members,
            todos: doneTodos,
            now: now,
          );
          return FairnessCard(
            members: members,
            doneTodos: doneTodos,
            suggestion: suggestNextAssignee(
              members: members,
              todos: [...todos, ...doneTodos],
              now: now,
            ),
            currentUserId: currentUserId,
            onOpenStats: () => _openStats(list, currentUserId),
          );
        },
      );
    }

    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          TdChip(
            label: l10n.groupByStatus,
            icon: Icons.view_agenda_outlined,
            dense: true,
            selected: _groupBy == _GroupBy.status,
            onTap: () => setState(() => _groupBy = _GroupBy.status),
          ),
          const SizedBox(width: TdSpace.sm),
          TdChip(
            label: l10n.groupByUser,
            icon: Icons.people_outline_rounded,
            dense: true,
            selected: _groupBy == _GroupBy.person,
            onTap: () => setState(() => _groupBy = _GroupBy.person),
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: TdSpace.md),
            color: context.colors.outlineVariant,
          ),
          TdChip(
            label: l10n.sortByDueDate,
            icon: Icons.event_rounded,
            dense: true,
            selected: _sortBy == _SortBy.due,
            onTap: () => setState(() => _sortBy = _SortBy.due),
          ),
          const SizedBox(width: TdSpace.sm),
          TdChip(
            label: l10n.sortByPriority,
            icon: Icons.flag_outlined,
            dense: true,
            selected: _sortBy == _SortBy.priority,
            onTap: () => setState(() => _sortBy = _SortBy.priority),
          ),
          const SizedBox(width: TdSpace.sm),
          TdChip(
            label: l10n.sortByCreated,
            icon: Icons.history_rounded,
            dense: true,
            selected: _sortBy == _SortBy.created,
            onTap: () => setState(() => _sortBy = _SortBy.created),
          ),
        ],
      ),
    );

    Widget tile(TodoModel t, int i) => TodoItemWidget(
      key: ValueKey(t.id),
      todo: t,
      list: list,
      members: members,
      currentUserId: currentUserId,
      canEdit: canEdit,
      index: i,
      accent: color,
      onCompleted: _onCompleted,
      onTap: () => _openEditor(list, todos, canEdit, t),
    );

    final sections = <Widget>[];
    if (todos.isEmpty) {
      sections.add(
        TdEmptyState(
          icon: Icons.task_alt_rounded,
          title: l10n.noTodos,
          message: canEdit ? l10n.createFirstTodo : l10n.listIsEmpty,
          action: canEdit
              ? TdButton.primary(
                  label: l10n.newTodoTitle,
                  icon: Icons.add_rounded,
                  onPressed: () => _openEditor(list, todos, true),
                )
              : null,
        ),
      );
    } else if (_groupBy == _GroupBy.status) {
      final open = _sorted(todos.where((t) => !t.isCompleted));
      final finished = todos.where((t) => t.isCompleted).toList()
        ..sort(
          (a, b) => (b.completedAt ?? b.createdAt).compareTo(
            a.completedAt ?? a.createdAt,
          ),
        );
      sections.addAll([
        _SectionTitle(title: l10n.pending, count: open.length),
        if (open.isEmpty)
          TdEmptyState(
            compact: true,
            icon: Icons.self_improvement_rounded,
            title: l10n.allDoneTitle,
            message: l10n.allDoneMessage,
          )
        else
          TdAnimatedList<TodoModel>(
            items: open,
            keyOf: (t) => t.id,
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, t, i) => tile(t, i),
          ),
        if (finished.isNotEmpty) ...[
          TdPressable(
            onTap: () => setState(() => _showDone = !_showDone),
            child: _SectionTitle(
              title: l10n.completed,
              count: finished.length,
              muted: true,
              trailing: AnimatedRotation(
                turns: _showDone ? 0 : -0.25,
                duration: TdMotion.of(context, TdMotion.base),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: context.td.muted,
                ),
              ),
            ),
          ),
          TdReveal(
            visible: _showDone,
            child: TdAnimatedList<TodoModel>(
              items: finished,
              keyOf: (t) => t.id,
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, t, i) => tile(t, i),
            ),
          ),
        ],
      ]);
    } else {
      final groups = <String?, List<TodoModel>>{};
      for (final t in todos) {
        groups.putIfAbsent(t.assignedToUserId, () => []).add(t);
      }
      final keys = groups.keys.toList()
        ..sort((a, b) {
          if (a == null) return 1;
          if (b == null) return -1;
          final ia = members.indexWhere((m) => m.id == a);
          final ib = members.indexWhere((m) => m.id == b);
          return ia.compareTo(ib);
        });
      var i = 0;
      for (final k in keys) {
        final member = members.where((m) => m.id == k).firstOrNull;
        final items = _sorted(groups[k]!);
        final name = k == null
            ? l10n.nobody
            : member != null
            ? memberDisplayName(l10n, member, currentUserId)
            : (items.first.assignedToUserName ?? l10n.unknown);
        sections.addAll([
          _SectionTitle(
            title: name,
            count: items.where((t) => !t.isCompleted).length,
            leading: member != null
                ? MemberAvatar(member: member, size: 24)
                : Icon(Icons.groups_rounded, size: 20, color: context.td.muted),
          ),
          for (final t in items) tile(t, i++),
        ]);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TdSpace.page,
        TdSpace.md,
        TdSpace.page,
        120,
      ),
      children: [
        TdFadeSlideIn(index: 0, child: header),
        const SizedBox(height: TdSpace.xl),
        if (!compact && fairness != null)
          TdFadeSlideIn(
            index: 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: progress),
                const SizedBox(width: TdSpace.lg),
                Expanded(flex: 2, child: fairness),
              ],
            ),
          )
        else ...[
          TdFadeSlideIn(index: 1, child: progress),
          if (fairness != null) ...[
            const SizedBox(height: TdSpace.lg),
            TdFadeSlideIn(index: 2, child: fairness),
          ],
        ],
        const SizedBox(height: TdSpace.xl),
        filters,
        const SizedBox(height: TdSpace.sm),
        ...sections,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.count,
    this.muted = false,
    this.leading,
    this.trailing,
  });

  final String title;
  final int count;
  final bool muted;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TdSpace.xs,
        TdSpace.lg,
        TdSpace.xs,
        TdSpace.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: TdSpace.sm)],
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              color: muted ? context.td.muted : null,
            ),
          ),
          const SizedBox(width: TdSpace.sm),
          CountPill(count: count, muted: muted),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}
