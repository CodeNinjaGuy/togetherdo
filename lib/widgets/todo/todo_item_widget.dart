import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../repositories/list_repository.dart';
import '../../repositories/todo_repository.dart';
import '../../models/todo_model.dart';
import '../../models/list_model.dart';

class TodoItemWidget extends StatelessWidget {
  final TodoModel todo;

  const TodoItemWidget({super.key, required this.todo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ListModel?>(
      stream: Stream.fromFuture(
        (context.read<ListRepository>() as FirebaseListRepository).getListById(
          todo.listId,
        ),
      ),
      builder: (context, listSnapshot) {
        final list = listSnapshot.data;
        final authState = context.read<AuthBloc>().state;
        final currentUserId = authState is AuthAuthenticated
            ? authState.user.id
            : '';

        final isOwner = list?.ownerId == currentUserId;
        final isMember = list?.memberIds.contains(currentUserId) == true;
        final canEdit = isOwner || (isMember && (list?.allowEdit ?? true));

        // Berechtigung für das Erledigen des Todos
        final canComplete =
            canEdit &&
            (todo.assignedToUserId == null || // Allgemeines Todo
                todo.assignedToUserId == currentUserId || // Zugewiesen an mich
                (todo.assignedToUserId != null && isOwner) // Ich bin Besitzer
                );

        // Visuelle Unterscheidung für Zuweisungen
        final isAssignedToMe = todo.assignedToUserId == currentUserId;
        final isAssignedToOther =
            todo.assignedToUserId != null && !isAssignedToMe;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isAssignedToMe
                  ? Colors.green.withValues(
                      alpha: 0.6,
                    ) // Hellgrün für zugewiesen an mich
                  : isAssignedToOther
                  ? Colors.blue.withValues(
                      alpha: 0.4,
                    ) // Hellblau für zugewiesen an andere
                  : Colors.transparent,
              width: isAssignedToMe || isAssignedToOther ? 2 : 0,
            ),
          ),
          child: ListTile(
            leading: Checkbox(
              value: todo.isCompleted,
              onChanged: canComplete
                  ? (value) async {
                      if (value != null) {
                        final authState = context.read<AuthBloc>().state;
                        final currentUser = authState is AuthAuthenticated
                            ? authState.user
                            : null;

                        final updatedTodo = todo.copyWith(
                          isCompleted: value,
                          completedByUserId: value ? currentUser?.id : null,
                          completedByUserName: value
                              ? currentUser?.displayName
                              : null,
                        );
                        await (context.read<TodoRepository>()
                                as FirebaseTodoRepository)
                            .updateTodo(updatedTodo);
                      }
                    }
                  : null,
            ),
            title: Text(
              todo.title,
              style: TextStyle(
                decoration: todo.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
                color: todo.isCompleted
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todo.description.isNotEmpty)
                  Text(
                    todo.description,
                    style: TextStyle(
                      decoration: todo.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: todo.isCompleted
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                if (todo.assignedToUserId != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isAssignedToMe
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAssignedToMe ? Icons.person : Icons.person_outline,
                          size: 14,
                          color: isAssignedToMe
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAssignedToMe
                              ? 'Dir zugewiesen'
                              : 'Zugewiesen an ${todo.assignedToUserName ?? 'Unbekannt'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAssignedToMe
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (todo.isCompleted && todo.completedByUserName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Erledigt von ${todo.completedByUserName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (todo.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: _getDueDateColor(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(todo.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getDueDateColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (todo.category != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      todo.category!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPriorityChip(context),
                if (canComplete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showDeleteDialog(context),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getDueDateColor(BuildContext context) {
    if (todo.isCompleted) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }

    if (todo.isOverdue) {
      return Theme.of(context).colorScheme.error;
    }

    if (todo.isDueToday) {
      return Theme.of(context).colorScheme.primary;
    }

    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Widget _buildPriorityChip(BuildContext context) {
    Color color;
    String label;

    switch (todo.priority) {
      case TodoPriority.high:
        color = Theme.of(context).colorScheme.error;
        label = 'Hoch';
        break;
      case TodoPriority.medium:
        color = Theme.of(context).colorScheme.primary;
        label = 'Mittel';
        break;
      case TodoPriority.low:
        color = Theme.of(context).colorScheme.secondary;
        label = 'Niedrig';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Todo löschen'),
        content: Text('Möchtest du "${todo.title}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              await (context.read<TodoRepository>() as FirebaseTodoRepository)
                  .deleteTodo(todo.id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
