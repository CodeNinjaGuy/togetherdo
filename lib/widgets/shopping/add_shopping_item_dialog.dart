import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/shopping/shopping_bloc.dart';
import '../../blocs/shopping/shopping_event.dart';

class AddShoppingItemDialog extends StatefulWidget {
  final String listId;

  const AddShoppingItemDialog({super.key, required this.listId});

  @override
  State<AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<AddShoppingItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedUnit;

  List<String> get _commonUnits {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.unit_piece,
      l10n.unit_kg,
      l10n.unit_g,
      l10n.unit_l,
      l10n.unit_ml,
      l10n.unit_pack,
      l10n.unit_can,
      l10n.unit_bottle,
      l10n.unit_bag,
      l10n.unit_bunch,
      l10n.unit_head,
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _selectedUnit ??= l10n.unit_piece;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_formKey.currentState!.validate()) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final quantity = double.tryParse(_quantityController.text) ?? 1.0;

        context.read<ShoppingBloc>().add(
          ShoppingAddRequested(
            name: _nameController.text.trim(),
            quantity: quantity,
            unit: _selectedUnit!,
            userId: authState.user.id,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            listId: widget.listId,
          ),
        );

        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.addItem),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.itemLabel,
                  hintText: l10n.exampleItem,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '${l10n.itemLabel} ist erforderlich';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: l10n.quantity,
                        hintText: l10n.exampleQuantity,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '${l10n.quantity} ist erforderlich';
                        }
                        final quantity = double.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Ungültige ${l10n.quantity.toLowerCase()}';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: InputDecoration(labelText: l10n.unit),
                      items: _commonUnits.map((unit) {
                        return DropdownMenuItem(value: unit, child: Text(unit));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUnit = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: l10n.notesOptional,
                  hintText: l10n.exampleNotes,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(onPressed: _addItem, child: Text(l10n.add)),
      ],
    );
  }
}
