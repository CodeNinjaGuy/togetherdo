import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/todo/todo_item_widget.dart';
import '../../widgets/todo/add_todo_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    _todoRepository = context.read<TodoRepository>() as FirebaseTodoRepository;
    _listRepository = context.read<ListRepository>() as FirebaseListRepository;
  }

  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTodoDialog(listId: widget.listId),
    );
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
          groupKey = todo.assignedToUserName ?? 'Unbekannt';
        } else {
          groupKey = 'Allgemein';
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
        'Ausstehend': _sortTodos(pendingTodos),
        'Erledigt': _sortTodos(completedTodos),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Todos'),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is AuthAuthenticated) {
                return IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    context.read<AuthBloc>().add(const AuthLogoutRequested());
                  },
                  tooltip: 'Abmelden',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<ListModel?>(
        stream: Stream.fromFuture(_listRepository.getListById(widget.listId)),
        builder: (context, listSnapshot) {
          if (listSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = listSnapshot.data;
          if (list == null) {
            return const Center(child: Text('Liste nicht gefunden'));
          }

          final authState = context.read<AuthBloc>().state;
          final currentUserId = authState is AuthAuthenticated
              ? authState.user.id
              : '';
          final isOwner = list.ownerId == currentUserId;
          final isMember = list.memberIds.contains(currentUserId);
          final canEdit = isOwner || (isMember && list.allowEdit);

          return Column(
            children: [
              // Gruppierung und Sortierung
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _groupBy,
                        decoration: const InputDecoration(
                          labelText: 'Gruppierung',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'status',
                            child: Text('Nach Status'),
                          ),
                          DropdownMenuItem(
                            value: 'user',
                            child: Text('Nach Benutzer'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _groupBy = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(
                          labelText: 'Sortierung',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'dueDate',
                            child: Text('Nach Fälligkeit'),
                          ),
                          DropdownMenuItem(
                            value: 'priority',
                            child: Text('Nach Priorität'),
                          ),
                          DropdownMenuItem(
                            value: 'createdAt',
                            child: Text('Nach Erstellung'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                            });
                          }
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Todos Stream
              Expanded(
                child: StreamBuilder<List<TodoModel>>(
                  stream: _todoRepository.getTodosStream(widget.listId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Fehler beim Laden: \\${snapshot.error}'),
                      );
                    }
                    final todos = snapshot.data ?? <TodoModel>[];

                    if (todos.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 80,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Keine Todos vorhanden',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canEdit
                                  ? 'Erstelle dein erstes Todo'
                                  : 'Die Liste ist noch leer',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Gruppiere Todos nach Status
                    final groupedTodos = _groupTodos(todos);

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: groupedTodos.entries
                          .expand(
                            (entry) => [
                              _buildSectionHeader(
                                entry.key,
                                entry.value.length,
                                _calculateProgress(
                                  entry.key,
                                  entry.value,
                                  todos,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...entry.value.map(
                                (todo) => TodoItemWidget(todo: todo),
                              ),
                              const SizedBox(height: 24),
                            ],
                          )
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<ListModel?>(
        stream: Stream.fromFuture(_listRepository.getListById(widget.listId)),
        builder: (context, listSnapshot) {
          if (listSnapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }

          final list = listSnapshot.data;
          if (list == null) {
            return const SizedBox.shrink();
          }

          final authState = context.read<AuthBloc>().state;
          final currentUserId = authState is AuthAuthenticated
              ? authState.user.id
              : '';
          final isOwner = list.ownerId == currentUserId;
          final isMember = list.memberIds.contains(currentUserId);
          final canEdit = isOwner || (isMember && list.allowEdit);

          if (!canEdit) {
            return const SizedBox.shrink(); // Kein FAB wenn keine Bearbeitungsberechtigung
          }

          return FloatingActionButton(
            onPressed: _showAddTodoDialog,
            child: const Icon(Icons.add),
          );
        },
      ),
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
              title == 'Allgemein' ? Icons.group : Icons.person,
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
