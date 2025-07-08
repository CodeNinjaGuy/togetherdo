import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/todo/todo_bloc.dart';
import '../../blocs/todo/todo_event.dart';
import '../../repositories/list_repository.dart';
import '../../models/todo_model.dart';

class AddTodoDialog extends StatefulWidget {
  final String listId;

  const AddTodoDialog({super.key, required this.listId});

  @override
  State<AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<AddTodoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  TodoPriority _priority = TodoPriority.medium;
  String? _selectedUserId;
  String? _selectedUserName;
  List<Map<String, String>> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadListAndUsers();
  }

  Future<void> _loadListAndUsers() async {
    final list =
        await (context.read<ListRepository>() as FirebaseListRepository)
            .getListById(widget.listId);
    if (list != null) {
      setState(() {
        _availableUsers = [
          {'id': list.ownerId, 'name': list.ownerName},
          ...list.memberIds.asMap().entries.map((entry) {
            final memberName = entry.key < list.memberNames.length
                ? list.memberNames[entry.key]
                : 'Mitglied ${entry.key + 1}';
            return {'id': entry.value, 'name': memberName};
          }),
        ];
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _addTodo() {
    if (_formKey.currentState!.validate()) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        DateTime? dueDate;
        if (_selectedDate != null) {
          if (_selectedTime != null) {
            dueDate = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedTime!.hour,
              _selectedTime!.minute,
            );
          } else {
            dueDate = _selectedDate;
          }
        }

        context.read<TodoBloc>().add(
          TodoAddRequested(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            dueDate: dueDate,
            priority: _priority,
            userId: authState.user.id,
            category: _categoryController.text.trim().isEmpty
                ? null
                : _categoryController.text.trim(),
            listId: widget.listId,
            assignedToUserId: _selectedUserId,
            assignedToUserName: _selectedUserName,
          ),
        );

        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neues Todo'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  hintText: 'Was muss erledigt werden?',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Titel ist erforderlich';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung (optional)',
                  hintText: 'Weitere Details...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Kategorie (optional)',
                  hintText: 'z.B. Arbeit, Privat, Einkaufen',
                ),
              ),
              const SizedBox(height: 16),

              // Zuweisung
              if (_availableUsers.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Zuweisung (optional)',
                    hintText: 'Wem soll das Todo zugewiesen werden?',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Keine Zuweisung (alle können erledigen)'),
                    ),
                    ..._availableUsers.map((user) {
                      return DropdownMenuItem<String>(
                        value: user['id'],
                        child: Text(user['name']!),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value;
                      _selectedUserName = value != null
                          ? _availableUsers.firstWhere(
                              (u) => u['id'] == value,
                            )['name']
                          : null;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Priorität
              DropdownButtonFormField<TodoPriority>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priorität'),
                items: TodoPriority.values.map((priority) {
                  String label;
                  switch (priority) {
                    case TodoPriority.high:
                      label = 'Hoch';
                      break;
                    case TodoPriority.medium:
                      label = 'Mittel';
                      break;
                    case TodoPriority.low:
                      label = 'Niedrig';
                      break;
                  }
                  return DropdownMenuItem(value: priority, child: Text(label));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _priority = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Fälligkeitsdatum
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Fälligkeitsdatum (optional)',
                        hintText: _selectedDate != null
                            ? DateFormat('dd.MM.yyyy').format(_selectedDate!)
                            : 'Datum auswählen',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _selectDate,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Uhrzeit (optional)',
                        hintText: _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Zeit auswählen',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: _selectTime,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(onPressed: _addTodo, child: const Text('Hinzufügen')),
      ],
    );
  }
}
