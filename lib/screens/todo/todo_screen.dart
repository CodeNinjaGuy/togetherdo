/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../design/td_design.dart';
import '../../fairness/fairness.dart';
import '../../services/review_service.dart';
import '../../widgets/fairness/fairness_widgets.dart';
import '../../widgets/todo/task_editor_sheet.dart';
import '../../widgets/todo/todo_item_widget.dart';
import '../fairness/fairness_screen.dart';
import '../../repositories/todo_repository.dart';
import '../../repositories/list_repository.dart';
import '../../models/todo_model.dart';
import '../../models/list_model.dart';

class TodoScreen extends StatefulWidget {
  final String listId;

  const TodoScreen({super.key, required this.listId});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  late final FirebaseTodoRepository _todoRepository;
  late final FirebaseListRepository _listRepository;

  // Gruppierung und Sortierung
  String _groupBy = 'status'; // 'status' oder 'user'
  String _sortBy = 'dueDate'; // 'dueDate', 'priority', 'createdAt'

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

  void _openEditor(
    ListModel list,
    List<TodoModel> todos,
    String currentUserId, [
    TodoModel? todo,
  ]) {
    showTaskEditorSheet(
      context,
      listId: widget.listId,
      members: _membersOf(list, AppLocalizations.of(context)!),
      listTodos: todos,
      currentUserId: currentUserId,
      todo: todo,
    );
  }

  void _openStats(ListModel list, String currentUserId) {
    Navigator.of(context).push(
      MaterialPageRoute(
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

  // Sortiere Todos nach ausgewähltem Kriterium
  List<TodoModel> _sortTodos(List<TodoModel> todos) {
    switch (_sortBy) {
      case 'dueDate':
        return todos..sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case 'priority':
        return todos
          ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
      case 'createdAt':
        return todos..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      default:
        return todos;
    }
  }

  // Gruppiere Todos nach ausgewähltem Kriterium
  Map<String, List<TodoModel>> _groupTodos(List<TodoModel> todos) {
    if (_groupBy == 'user') {
      final grouped = <String, List<TodoModel>>{};

      for (final todo in todos) {
        String groupKey;
        if (todo.assignedToUserId != null) {
          groupKey =
              todo.assignedToUserName ?? AppLocalizations.of(context)!.unknown;
        } else {
          groupKey = AppLocalizations.of(context)!.general;
        }

        grouped.putIfAbsent(groupKey, () => []).add(todo);
      }

      // Sortiere die Gruppen alphabetisch
      final sortedGroups = <String, List<TodoModel>>{};
      final sortedKeys = grouped.keys.toList()..sort();
      for (final key in sortedKeys) {
        sortedGroups[key] = _sortTodos(grouped[key]!);
      }

      return sortedGroups;
    } else {
      // Gruppierung nach Status (Standard)
      final pendingTodos = todos.where((todo) => !todo.isCompleted).toList();
      final completedTodos = todos.where((todo) => todo.isCompleted).toList();

      return {
        AppLocalizations.of(context)!.pending: _sortTodos(pendingTodos),
        AppLocalizations.of(context)!.completed: _sortTodos(completedTodos),
      };
    }
  }

  // Berechne Fortschritt für eine Gruppe
  Map<String, int> _calculateProgress(
    String groupName,
    List<TodoModel> todos, [
    List<TodoModel>? allTodos,
  ]) {
    if (_groupBy == 'user') {
      // Bei Benutzer-Gruppierung: Zeige Fortschritt innerhalb der Gruppe
      final total = todos.length;
      final completed = todos.where((todo) => todo.isCompleted).length;

      return {'total': total, 'completed': completed};
    } else {
      // Bei Status-Gruppierung: Zeige Gesamtfortschritt
      if (allTodos != null) {
        final total = allTodos.length;
        final completed = allTodos.where((todo) => todo.isCompleted).length;

        return {'total': total, 'completed': completed};
      } else {
        return {'total': 0, 'completed': 0};
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';

    return StreamBuilder<ListModel?>(
      stream: _listStream,
      builder: (context, listSnapshot) {
        final list = listSnapshot.data;
        final isOwner = list?.ownerId == currentUserId;
        final isMember = list?.memberIds.contains(currentUserId) ?? false;
        final canEdit = isOwner || (isMember && (list?.allowEdit ?? false));

        return StreamBuilder<List<TodoModel>>(
          stream: _todosStream,
          builder: (context, todoSnapshot) {
            final todos = todoSnapshot.data ?? const <TodoModel>[];
            return Scaffold(
              appBar: AppBar(
                title: Text(list?.name ?? l10n.myTodos),
                actions: [
                  if (list != null && list.memberIds.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.balance_rounded),
                      tooltip: l10n.fairnessShowStats,
                      onPressed: () => _openStats(list, currentUserId),
                    ),
                  if (authState is AuthAuthenticated)
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const AuthLogoutRequested(),
                        );
                      },
                      tooltip: l10n.logout,
                    ),
                ],
              ),
              floatingActionButton: list != null && canEdit
                  ? FloatingActionButton(
                      onPressed: () => _openEditor(list, todos, currentUserId),
                      child: const Icon(Icons.add),
                    )
                  : null,
              body: _buildBody(
                context,
                l10n,
                listSnapshot,
                todoSnapshot,
                currentUserId,
                canEdit,
                isOwner,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    AsyncSnapshot<ListModel?> listSnapshot,
    AsyncSnapshot<List<TodoModel>> todoSnapshot,
    String currentUserId,
    bool canEdit,
    bool isOwner,
  ) {
    if (listSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = listSnapshot.data;
    if (list == null) {
      return Center(child: Text(l10n.listNotFound));
    }

    return Column(
      children: [
        // Gruppierung und Sortierung
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _groupBy,
                  decoration: InputDecoration(
                    labelText: l10n.grouping,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'status',
                      child: Text(l10n.groupByStatus),
                    ),
                    DropdownMenuItem(
                      value: 'user',
                      child: Text(l10n.groupByUser),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _groupBy = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  decoration: InputDecoration(
                    labelText: l10n.sorting,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'dueDate',
                      child: Text(l10n.sortByDueDate),
                    ),
                    DropdownMenuItem(
                      value: 'priority',
                      child: Text(l10n.sortByPriority),
                    ),
                    DropdownMenuItem(
                      value: 'createdAt',
                      child: Text(l10n.sortByCreated),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sortBy = value);
                  },
                ),
              ),
            ],
          ),
        ),
        // Listen-Info Header
        if (!canEdit && !isOwner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.readOnlyMode,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _buildTodoList(
            context,
            l10n,
            list,
            todoSnapshot,
            currentUserId,
            canEdit,
          ),
        ),
      ],
    );
  }

  Widget _buildTodoList(
    BuildContext context,
    AppLocalizations l10n,
    ListModel list,
    AsyncSnapshot<List<TodoModel>> snapshot,
    String currentUserId,
    bool canEdit,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(child: Text('${l10n.loadError}: ${snapshot.error}'));
    }
    final todos = snapshot.data ?? <TodoModel>[];
    final shared = list.memberIds.isNotEmpty;

    Widget? fairness;
    if (shared) {
      final members = _membersOf(list, l10n);
      fairness = StreamBuilder<List<TodoModel>>(
        stream: _doneStream,
        builder: (context, doneSnap) {
          final done = doneSnap.data ?? const <TodoModel>[];
          final now = DateTime.now();
          _weekStats = FairnessStats.compute(
            period: FairnessPeriod.week,
            members: members,
            todos: done,
            now: now,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: TdSpace.lg),
            child: FairnessCard(
              members: members,
              doneTodos: done,
              suggestion: suggestNextAssignee(
                members: members,
                todos: [...todos, ...done],
                now: now,
              ),
              currentUserId: currentUserId,
              onOpenStats: () => _openStats(list, currentUserId),
            ),
          );
        },
      );
    }

    if (todos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ?fairness,
          const SizedBox(height: 48),
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noTodos,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            canEdit ? l10n.createFirstTodo : l10n.listIsEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final groupedTodos = _groupTodos(List.of(todos));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ?fairness,
        ...groupedTodos.entries.expand(
          (entry) => [
            _buildSectionHeader(
              entry.key,
              entry.value.length,
              _calculateProgress(entry.key, entry.value, todos),
            ),
            const SizedBox(height: 8),
            ...entry.value.map(
              (todo) => TodoItemWidget(
                key: ValueKey(todo.id),
                todo: todo,
                onEdit: canEdit
                    ? () => _openEditor(list, todos, currentUserId, todo)
                    : null,
                onCompleted: _onCompleted,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count, [
    Map<String, int>? progress,
  ]) {
    if (_groupBy == 'user') {
      // Benutzer-Gruppierung mit anderem Design
      return Container(
        margin: const EdgeInsets.only(top: 16, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              title == AppLocalizations.of(context)!.general
                  ? Icons.group
                  : Icons.person,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (progress != null && progress['total']! > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${progress['completed']} von ${progress['total']} erledigt',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    } else {
      // Standard-Status-Gruppierung
      return Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (progress != null && progress['total']! > 0) ...[
            const SizedBox(width: 8),
            Text(
              '(${progress['completed']} von ${progress['total']} erledigt)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      );
    }
  }
}
