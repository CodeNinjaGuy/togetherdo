import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }

    return BlocListener<ListBloc, ListState>(
      listener: (context, state) {
        if (state is ListCreateSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.listCreatedSuccess(state.list.name)),
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
              content: Text('${l10n.error}: ${state.message}'),
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
        title: Text(l10n.newListTitle),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _listNameController,
                  decoration: InputDecoration(
                    labelText: l10n.listName,
                    hintText: l10n.exampleShoppingList,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.pleaseEnterName;
                    }
                    if (value.trim().length < 3) {
                      return l10n.listNameMinLength;
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _createList(),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.listTypeLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<ListType>(
                  segments: [
                    ButtonSegment<ListType>(
                      value: ListType.todo,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(l10n.todoListLabel),
                    ),
                    ButtonSegment<ListType>(
                      value: ListType.shopping,
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text(l10n.shoppingListLabel),
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
                  title: Text(l10n.membersCanEditTitle),
                  subtitle: Text(
                    _allowEdit
                        ? l10n.membersCanEditSubtitle
                        : l10n.onlyOwnerCanEditItems,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
                          '${l10n.listCreatedSubtitle} ${l10n.sixDigitCode} ${l10n.listCreatedSubtitle2}',
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _isLoading ? null : _createList,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.create),
          ),
        ],
      ),
    );
  }
}
