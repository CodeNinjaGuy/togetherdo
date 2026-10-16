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
import '../../design/td_design.dart';
import '../../fairness/fairness.dart';
import '../../models/list_model.dart';
import '../../models/todo_model.dart';
import '../../repositories/anhang_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/todo_repository.dart';
import '../../services/review_service.dart';
import '../attachments/anhang_abschnitt.dart';
import '../common/user_avatar.dart';
import '../fairness/fairness_widgets.dart';

/// Zeile einer Aufgabe auf Basis von [TdTaskTile]: Abhaken (alle
/// Mitglieder), Wischen zum Löschen (nur mit Bearbeitungsrecht), Etiketten
/// für Fälligkeit, Priorität, Aufwand, Kategorie und Anhänge, Chat rechts.
class TodoItemWidget extends StatelessWidget {
  const TodoItemWidget({
    super.key,
    required this.todo,
    required this.list,
    required this.members,
    required this.currentUserId,
    required this.canEdit,
    this.index = 0,
    this.onTap,
    this.onCompleted,
    this.accent,
    this.showListTag = false,
  });

  final TodoModel todo;
  final ListModel list;
  final List<FairnessMember> members;
  final String currentUserId;

  /// Bearbeiten/Löschen erlaubt (Besitzer oder Mitglied mit allowEdit).
  final bool canEdit;
  final int index;

  /// Öffnet Bearbeiten bzw. Details.
  final VoidCallback? onTap;

  /// Nach erfolgreichem eigenem Abhaken (für die Bewertungsanfrage).
  final VoidCallback? onCompleted;
  final Color? accent;

  /// Auf „Heute“: Listenname als Etikett zeigen.
  final bool showListTag;

  bool get _isMember =>
      list.ownerId == currentUserId || list.memberIds.contains(currentUserId);

  Future<void> _setCompleted(BuildContext context, bool value) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<TodoRepository>().setCompleted(
        todoId: todo.id,
        completed: value,
        userId: auth.user.id,
        userName: auth.user.displayName,
      );
      if (value) onCompleted?.call();
    } catch (e) {
      ReviewService.instance.noteError();
      debugPrint('Abhaken fehlgeschlagen: $e');
      if (context.mounted) {
        TdToast.show(context, l10n.saveFailed, variant: TdToastVariant.error);
      }
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTodoTitle),
        content: Text(l10n.deleteTodoContent(todo.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.td.danger),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<ChatRepository>().deleteAllMessages(todo.id);
      if (!context.mounted) return;
      await context.read<TodoRepository>().deleteTodo(todo.id);
      if (!context.mounted) return;
      TdToast.show(
        context,
        l10n.taskDeleted,
        variant: TdToastVariant.info,
        icon: Icons.delete_outline_rounded,
      );
    } catch (e) {
      debugPrint('Aufgabe löschen fehlgeschlagen: $e');
      if (context.mounted) {
        TdToast.show(context, l10n.saveFailed, variant: TdToastVariant.error);
      }
    }
  }

  TdAvatarData? _assignee() {
    final id = todo.assignedToUserId;
    if (id == null) return null;
    for (final m in members) {
      if (m.id == id) {
        return avatarDataOf(m, imageUrl: UserAvatarCache.instance.peek(id));
      }
    }
    return TdAvatarData(
      id: id,
      name: todo.assignedToUserName ?? '?',
      imageUrl: UserAvatarCache.instance.peek(id),
    );
  }

  Widget _dueTag(BuildContext context, AppLocalizations l10n) {
    final due = todo.dueDate!;
    final td = context.td;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hasTime = due.hour != 0 || due.minute != 0;
    if (todo.isCompleted) {
      return TdTag(
        label: DateFormat.MMMd(locale).format(due),
        icon: Icons.event_rounded,
        filled: false,
      );
    }
    if (todo.isOverdue) {
      return TdTag(
        label: l10n.overdue,
        icon: Icons.schedule_rounded,
        color: td.danger,
      );
    }
    if (todo.isDueToday) {
      return TdTag(
        label: hasTime
            ? '${l10n.dueToday}, ${DateFormat.Hm(locale).format(due)}'
            : l10n.dueToday,
        icon: Icons.today_rounded,
        color: td.warning,
      );
    }
    return TdTag(
      label:
          (hasTime
                  ? DateFormat.MMMEd(locale).add_Hm()
                  : DateFormat.MMMEd(locale))
              .format(due),
      icon: Icons.event_rounded,
      filled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final td = context.td;
    final color = accent ?? context.colors.primary;
    final shared = list.memberIds.isNotEmpty;
    final locale = Localizations.localeOf(context).toLanguageTag();

    final tags = <Widget>[
      if (showListTag)
        TdTag(label: list.name, color: color, icon: Icons.checklist_rounded),
      if (todo.dueDate != null) _dueTag(context, l10n),
      if (todo.priority == TodoPriority.high)
        TdTag(
          label: l10n.priorityHigh,
          icon: Icons.priority_high_rounded,
          color: td.danger,
        ),
      if (todo.priority == TodoPriority.low)
        TdTag(
          label: l10n.priorityLow,
          icon: Icons.south_rounded,
          filled: false,
        ),
      TdWeightTag(weight: tdWeightOf(todo.effort)),
      if (todo.category != null && todo.category!.isNotEmpty)
        TdTag(label: todo.category!, icon: Icons.sell_outlined, filled: false),
      AnhangAnzahl(
        repository: context.read<AnhangRepository>(),
        ziel: AnhangZiel.aufgabe(listId: todo.listId, todoId: todo.id),
      ),
      if (todo.isCompleted && todo.completedByUserName != null)
        TdTag(
          label: todo.completedAt == null
              ? l10n.doneBy(todo.completedByUserName!)
              : l10n.completedByAt(
                  todo.completedByUserName!,
                  DateFormat.MMMEd(locale).add_Hm().format(todo.completedAt!),
                ),
          icon: Icons.check_circle_rounded,
          color: td.success,
        ),
    ];

    Widget? trailing;
    if (shared) {
      trailing = StreamBuilder<int>(
        stream: (context.read<ChatRepository>()).getUnreadCount(
          todo.id,
          currentUserId,
        ),
        builder: (context, snap) => TdIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: l10n.chat,
          size: 38,
          badge: snap.data ?? 0,
          onPressed: () async {
            await context.read<ChatRepository>().markAsRead(
              todo.id,
              currentUserId,
            );
            if (!context.mounted) return;
            context.push(
              '/chat/${todo.id}?title=${Uri.encodeComponent(todo.title)}&liste=${list.id}',
            );
          },
        ),
      );
    }

    return TdFadeSlideIn(
      index: index,
      child: TdTaskTile(
        heroTag: 'task-${todo.id}',
        title: todo.title,
        subtitle: todo.description.isEmpty ? null : todo.description,
        done: todo.isCompleted,
        accent: color,
        assignee: _assignee(),
        tags: tags,
        trailing: trailing,
        onChanged: _isMember ? (v) => _setCompleted(context, v) : null,
        disabledHint: _isMember ? null : l10n.onlyMembersCanComplete,
        onTap: onTap,
        onDelete: canEdit ? () => _delete(context) : null,
        confirmDelete: canEdit ? () => _confirmDelete(context) : null,
      ),
    );
  }
}
