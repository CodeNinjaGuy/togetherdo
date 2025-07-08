import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/list/list_bloc.dart';
import '../../blocs/list/list_event.dart';
import '../../blocs/list/list_state.dart';
import '../../models/list_model.dart';

class CreateListDialog extends StatefulWidget {
  const CreateListDialog({super.key});

  @override
  State<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<CreateListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  ListType _selectedType = ListType.todo;
  bool _allowEdit = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _listNameController.dispose();
    super.dispose();
  }

  void _createList() {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      setState(() => _isLoading = true);

      context.read<ListBloc>().add(
        ListCreateRequested(
          name: _listNameController.text.trim(),
          ownerId: authState.user.id,
          ownerName: authState.user.displayName,
          type: _selectedType,
          allowEdit: _allowEdit,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListBloc, ListState>(
      listener: (context, state) {
        if (state is ListCreateSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Liste "${state.list.name}" erstellt'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else if (state is ListCreateFailure) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: ${state.message}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      },
      child: AlertDialog(
        title: const Text('Neue Liste erstellen'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _listNameController,
                decoration: const InputDecoration(
                  labelText: 'Listenname',
                  hintText: 'z.B. Einkaufsliste für Party',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte gib einen Namen ein';
                  }
                  if (value.trim().length < 3) {
                    return 'Der Name muss mindestens 3 Zeichen lang sein';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _createList(),
              ),
              const SizedBox(height: 16),
              Text('Listentyp', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ListType>(
                segments: const [
                  ButtonSegment<ListType>(
                    value: ListType.todo,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Todo-Liste'),
                  ),
                  ButtonSegment<ListType>(
                    value: ListType.shopping,
                    icon: Icon(Icons.shopping_cart_outlined),
                    label: Text('Einkaufsliste'),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<ListType> selection) {
                  setState(() {
                    _selectedType = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Mitglieder können bearbeiten'),
                subtitle: Text(
                  _allowEdit
                      ? 'Andere Benutzer können Items hinzufügen, bearbeiten und löschen'
                      : 'Nur du kannst Items hinzufügen, bearbeiten und löschen',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _allowEdit,
                onChanged: (value) {
                  setState(() {
                    _allowEdit = value ?? true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Die Liste erhält automatisch einen 6-stelligen Code zum Teilen.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: _isLoading ? null : _createList,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Erstellen'),
          ),
        ],
      ),
    );
  }
}
