import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/share/share_bloc.dart';
import '../../blocs/share/share_event.dart';
import '../../blocs/share/share_state.dart';
import '../../models/share_model.dart';

class CreateShareDialog extends StatefulWidget {
  const CreateShareDialog({super.key});

  @override
  State<CreateShareDialog> createState() => _CreateShareDialogState();
}

class _CreateShareDialogState extends State<CreateShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  ShareType _selectedType = ShareType.todo;
  bool _isLoading = false;

  @override
  void dispose() {
    _listNameController.dispose();
    super.dispose();
  }

  void _createShare() {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      setState(() => _isLoading = true);

      context.read<ShareBloc>().add(
        ShareCreateRequested(
          ownerId: authState.user.id,
          ownerName: authState.user.displayName,
          type: _selectedType,
          listName: _listNameController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ShareBloc, ShareState>(
      listener: (context, state) {
        if (state is ShareCreateSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Liste "${state.share.listName}" erstellt'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else if (state is ShareCreateFailure) {
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
        title: const Text('Neue geteilte Liste erstellen'),
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
                onFieldSubmitted: (_) => _createShare(),
              ),
              const SizedBox(height: 16),
              Text('Listentyp', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ShareType>(
                segments: const [
                  ButtonSegment<ShareType>(
                    value: ShareType.todo,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Todo-Liste'),
                  ),
                  ButtonSegment<ShareType>(
                    value: ShareType.shopping,
                    icon: Icon(Icons.shopping_cart_outlined),
                    label: Text('Einkaufsliste'),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<ShareType> selection) {
                  setState(() {
                    _selectedType = selection.first;
                  });
                },
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
                        'Nach dem Erstellen erhältst du einen 6-stelligen Code, '
                        'den du mit anderen teilen kannst.',
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
            onPressed: _isLoading ? null : _createShare,
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
