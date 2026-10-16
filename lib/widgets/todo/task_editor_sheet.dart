/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../calendar/repositories/termin_repository.dart';
import '../../calendar/services/verfuegbarkeit.dart';
import '../../design/td_design.dart';
import '../../fairness/fairness.dart';
import '../../models/todo_model.dart';
import '../../repositories/anhang_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/todo_repository.dart';
import '../../services/attachment_service.dart';
import '../../services/review_service.dart';
import '../attachments/anhang_abschnitt.dart';
import '../fairness/fairness_widgets.dart';

/// Öffnet das Sheet zum Anlegen ([todo] = null), Bearbeiten oder – ohne
/// Bearbeitungsrecht – Ansehen einer Aufgabe. [listTodos] = alle Aufgaben
/// der Liste (für „wer ist dran“).
Future<void> showTaskEditorSheet(
  BuildContext context, {
  required String listId,
  required List<FairnessMember> members,
  required List<TodoModel> listTodos,
  required String currentUserId,
  required String currentUserName,
  TodoModel? todo,
  bool canEdit = true,
}) {
  final l10n = AppLocalizations.of(context)!;
  // Urlaub im Familienkalender: Abwesende werden nicht vorgeschlagen.
  final verfuegbarkeit = Verfuegbarkeit(
    repository: FirebaseTerminRepository(),
    listIds: [listId],
  );
  final title = todo == null
      ? l10n.newTodoTitle
      : (canEdit ? l10n.editTodoTitle : l10n.taskDetails);
  return showTdSheet<void>(
    context,
    title: title,
    builder: (_) => TaskEditorForm(
      listId: listId,
      members: members,
      listTodos: listTodos,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      todo: todo,
      canEdit: canEdit,
      repository: context.read<TodoRepository>(),
      chatRepository: context.read<ChatRepository>(),
      attachmentRepository: context.read<AnhangRepository>(),
      attachmentService: context.read<AttachmentService>(),
      absentOn: (tag) =>
          verfuegbarkeit.abwesende(members.map((m) => m.id), tag),
    ),
  );
}

/// Formular: Titel, Beschreibung, Fälligkeit, Zuständig (mit Vorschlag),
/// Aufwand, Priorität, Kategorie, Anhänge.
class TaskEditorForm extends StatefulWidget {
  const TaskEditorForm({
    super.key,
    required this.listId,
    required this.members,
    required this.listTodos,
    required this.currentUserId,
    required this.repository,
    this.currentUserName = '',
    this.todo,
    this.canEdit = true,
    this.chatRepository,
    this.attachmentRepository,
    this.attachmentService,
    this.absentOn,
    this.now,
  });

  final String listId;
  final List<FairnessMember> members;
  final List<TodoModel> listTodos;
  final String currentUserId;
  final String currentUserName;
  final TodoRepository repository;
  final TodoModel? todo;

  /// Ohne Bearbeitungsrecht: Felder nur lesen, Anhänge trotzdem möglich.
  final bool canEdit;
  final ChatRepository? chatRepository;

  /// Ohne beides bleibt der Abschnitt „Anhänge“ aus (Tests, Vorschau).
  final AnhangRepository? attachmentRepository;
  final AttachmentService? attachmentService;

  /// Wer ist an diesem Tag abwesend (Urlaub im Kalender)? Ohne Angabe
  /// gilt niemand als abwesend.
  final Future<Set<String>> Function(DateTime tag)? absentOn;

  /// Nur für Tests.
  final DateTime? now;

  @override
  State<TaskEditorForm> createState() => _TaskEditorFormState();
}

class _TaskEditorFormState extends State<TaskEditorForm> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late TaskEffort _effort;
  late TodoPriority _priority;
  DateTime? _due;
  bool _dueHasTime = false;
  String? _assigneeId;
  FairnessSuggestion? _suggestion;

  /// Abwesende am Fälligkeitstag (sonst heute).
  Set<String> _absent = const {};

  /// Zuständigkeit von Hand gewählt: Vorschlag überschreibt sie nicht mehr.
  bool _assigneeTouched = false;
  bool _saving = false;
  final AnhangVormerkung _vormerkung = AnhangVormerkung();

  bool get _isNew => widget.todo == null;
  bool get _editable => widget.canEdit;
  bool get _withAttachments =>
      widget.attachmentRepository != null && widget.attachmentService != null;

  @override
  void initState() {
    super.initState();
    final t = widget.todo;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _category = TextEditingController(text: t?.category ?? '');
    _effort = t?.effort ?? TaskEffort.medium;
    _priority = t?.priority ?? TodoPriority.medium;
    _due = t?.dueDate;
    _dueHasTime = _due != null && (_due!.hour != 0 || _due!.minute != 0);
    _assigneeId = t?.assignedToUserId;

    _suggest();
    _loadAbsence();
  }

  /// Vorschlag nur, wenn mehrere Personen in der Liste sind. Die eigene
  /// Aufgabe zählt beim Bearbeiten nicht zur Last; Abwesende entfallen.
  void _suggest() {
    if (widget.members.length <= 1) return;
    _suggestion = suggestNextAssignee(
      members: widget.members,
      todos: widget.listTodos.where((x) => x.id != widget.todo?.id),
      now: widget.now ?? DateTime.now(),
      absent: _absent,
    );
    if (_isNew && !_assigneeTouched) _assigneeId = _suggestion?.member.id;
  }

  /// Lädt die Abwesenheiten für den Fälligkeitstag (ohne Fälligkeit: heute)
  /// und rechnet den Vorschlag neu.
  Future<void> _loadAbsence() async {
    final load = widget.absentOn;
    if (load == null || widget.members.length <= 1) return;
    final day = _due ?? widget.now ?? DateTime.now();
    try {
      final absent = await load(DateTime(day.year, day.month, day.day));
      if (!mounted) return;
      setState(() {
        _absent = absent;
        _suggest();
      });
    } catch (e) {
      // Ohne Kalender (offline, keine Rechte) bleibt der Vorschlag wie er ist.
      debugPrint('Abwesenheiten nicht geladen: $e');
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _vormerkung.dispose();
    super.dispose();
  }

  FairnessMember? _memberById(String? id) {
    for (final m in widget.members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _due ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueHasTime
          ? TimeOfDay.fromDateTime(initial)
          : const TimeOfDay(hour: 18, minute: 0),
    );
    if (!mounted) return;
    setState(() {
      _dueHasTime = time != null;
      _due = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
    _loadAbsence();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final assignee = _memberById(_assigneeId);
    final category = _category.text.trim();
    try {
      final old = widget.todo;
      if (old == null) {
        final created = await widget.repository.addTodo(
          title: title,
          description: _description.text.trim(),
          dueDate: _due,
          priority: _priority,
          userId: widget.currentUserId,
          category: category.isEmpty ? null : category,
          listId: widget.listId,
          assignedToUserId: assignee?.id,
          assignedToUserName: assignee?.name,
          effort: _effort,
        );
        await _uploadStaged(created.id);
      } else {
        await widget.repository.updateTodo(
          old.copyWith(
            title: title,
            description: _description.text.trim(),
            dueDate: _due,
            clearDueDate: _due == null,
            priority: _priority,
            category: category.isEmpty ? null : category,
            clearCategory: category.isEmpty,
            assignedToUserId: assignee?.id,
            assignedToUserName: assignee?.name,
            clearAssignee: assignee == null,
            effort: _effort,
          ),
        );
      }
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      ReviewService.instance.noteError();
      debugPrint('Aufgabe speichern fehlgeschlagen: $e');
      if (mounted) {
        setState(() => _saving = false);
        TdToast.show(context, l10n.saveFailed, variant: TdToastVariant.error);
      }
    }
  }

  /// Vorgemerkte Anhänge einer neuen Aufgabe hochladen.
  Future<void> _uploadStaged(String todoId) async {
    final service = widget.attachmentService;
    final repo = widget.attachmentRepository;
    if (service == null || repo == null || _vormerkung.leer) return;
    await _vormerkung.hochladen(
      ziel: AnhangZiel.aufgabe(listId: widget.listId, todoId: todoId),
      service: service,
      repository: repo,
      userId: widget.currentUserId,
    );
  }

  Future<void> _delete() async {
    final todo = widget.todo;
    if (todo == null) return;
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
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.chatRepository?.deleteAllMessages(todo.id);
      await widget.repository.deleteTodo(todo.id);
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Aufgabe löschen fehlgeschlagen: $e');
      if (mounted) {
        setState(() => _saving = false);
        TdToast.show(context, l10n.saveFailed, variant: TdToastVariant.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dueText = _due == null
        ? l10n.noDueDate
        : (_dueHasTime
                  ? DateFormat.yMMMEd(locale).add_Hm()
                  : DateFormat.yMMMEd(locale))
              .format(_due!);
    final suggested = _suggestion?.member;
    final editable = _editable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!editable) ...[
          Text(_title.text, style: context.text.headlineSmall),
          if (_description.text.isNotEmpty) ...[
            const SizedBox(height: TdSpace.sm),
            Text(_description.text, style: context.text.bodyMedium),
          ],
          const SizedBox(height: TdSpace.sm),
          Tooltip(
            message: l10n.readOnlyMode,
            triggerMode: TooltipTriggerMode.tap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TdTag(
                  label: l10n.readOnly,
                  icon: Icons.lock_outline_rounded,
                  filled: false,
                ),
              ],
            ),
          ),
        ] else ...[
          TdTextField(
            controller: _title,
            label: l10n.todoTitle,
            hint: l10n.exampleTodo,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: TdSpace.lg),
          TdTextField(
            controller: _description,
            label: l10n.todoDescription,
            hint: l10n.exampleDescription,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        const SizedBox(height: TdSpace.xl),
        _Label(l10n.dueLabel),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            TdChip(
              label: dueText,
              icon: Icons.event_rounded,
              selected: _due != null,
              onTap: editable ? _pickDue : null,
            ),
            if (_due != null && editable)
              TdChip(
                label: l10n.removeDueDate,
                icon: Icons.close_rounded,
                dense: true,
                onTap: () {
                  setState(() {
                    _due = null;
                    _dueHasTime = false;
                  });
                  _loadAbsence();
                },
              ),
          ],
        ),
        const SizedBox(height: TdSpace.xl),
        _Label(l10n.responsibleLabel),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            TdChip(
              label: l10n.nobody,
              icon: Icons.groups_rounded,
              selected: _assigneeId == null,
              onTap: editable
                  ? () => setState(() {
                      _assigneeTouched = true;
                      _assigneeId = null;
                    })
                  : null,
            ),
            for (final m in widget.members)
              TdChip(
                key: ValueKey('assignee-${m.id}'),
                label: _absent.contains(m.id)
                    ? '${memberDisplayName(l10n, m, widget.currentUserId)} · ${l10n.memberAway}'
                    : memberDisplayName(l10n, m, widget.currentUserId),
                leading: MemberAvatar(member: m, size: 20),
                color: avatarDataOf(m).resolveColor(),
                selected: _assigneeId == m.id,
                onTap: editable
                    ? () => setState(() {
                        _assigneeTouched = true;
                        _assigneeId = m.id;
                      })
                    : null,
              ),
          ],
        ),
        if (suggested != null && editable) ...[
          const SizedBox(height: TdSpace.sm),
          InkWell(
            borderRadius: TdRadius.control,
            onTap: () => setState(() {
              _assigneeTouched = true;
              _assigneeId = suggested.id;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: TdSpace.xs),
                  Expanded(
                    child: Text(
                      suggested.id == widget.currentUserId
                          ? l10n.suggestedTurnYou
                          : l10n.suggestedTurn(suggested.name),
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: TdSpace.xl),
        _Label(l10n.effortLabel),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final e in TaskEffort.values)
              TdChip(
                key: ValueKey('effort-${e.name}'),
                label: effortLabel(l10n, e),
                leading: TdWeightTag(weight: tdWeightOf(e)),
                selected: _effort == e,
                onTap: editable ? () => setState(() => _effort = e) : null,
              ),
          ],
        ),
        const SizedBox(height: TdSpace.xl),
        _Label(l10n.priorityLabel),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final p in TodoPriority.values.reversed)
              TdChip(
                label: switch (p) {
                  TodoPriority.high => l10n.priorityHigh,
                  TodoPriority.medium => l10n.priorityMedium,
                  TodoPriority.low => l10n.priorityLow,
                },
                dense: true,
                selected: _priority == p,
                onTap: editable ? () => setState(() => _priority = p) : null,
              ),
          ],
        ),
        if (editable) ...[
          const SizedBox(height: TdSpace.lg),
          TdTextField(
            controller: _category,
            label: l10n.todoCategory,
            hint: l10n.exampleCustomCategory,
            textCapitalization: TextCapitalization.sentences,
          ),
        ] else if (_category.text.isNotEmpty) ...[
          const SizedBox(height: TdSpace.lg),
          _Label(l10n.todoCategory),
          Row(
            children: [TdTag(label: _category.text, icon: Icons.sell_outlined)],
          ),
        ],
        if (_withAttachments) ...[
          const SizedBox(height: TdSpace.xl),
          AnhangAbschnitt(
            ziel: widget.todo == null
                ? null
                : AnhangZiel.aufgabe(
                    listId: widget.listId,
                    todoId: widget.todo!.id,
                  ),
            vormerkung: _vormerkung,
            userId: widget.currentUserId,
            darfFremdeLoeschen: widget.canEdit,
            service: widget.attachmentService!,
            repository: widget.attachmentRepository!,
            heroPraefix: 'aufgabe',
          ),
        ],
        const SizedBox(height: TdSpace.xxl),
        if (!editable)
          TdButton.secondary(
            label: l10n.close,
            expanded: true,
            onPressed: () => Navigator.of(context).maybePop(),
          )
        else
          Row(
            children: [
              if (!_isNew && widget.chatRepository != null)
                TdIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: l10n.delete,
                  color: context.td.danger,
                  size: 52,
                  onPressed: _saving ? null : _delete,
                )
              else
                Expanded(
                  child: TdButton.secondary(
                    label: l10n.cancel,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              const SizedBox(width: TdSpace.md),
              Expanded(
                flex: 2,
                child: ValueListenableBuilder(
                  valueListenable: _title,
                  builder: (context, value, _) => TdButton.primary(
                    key: const ValueKey('task-save'),
                    label: _isNew ? l10n.add : l10n.save,
                    icon: _isNew ? Icons.add_rounded : Icons.check_rounded,
                    expanded: true,
                    loading: _saving,
                    onPressed: value.text.trim().isEmpty ? null : _save,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TdSpace.sm),
    child: Text(text, style: context.text.labelMedium),
  );
}
