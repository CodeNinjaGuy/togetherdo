import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  String _selectedUnit = 'Stück';

  final List<String> _commonUnits = [
    'Stück',
    'kg',
    'g',
    'l',
    'ml',
    'Packung',
    'Dose',
    'Flasche',
    'Tüte',
    'Bund',
    'Kopf',
  ];

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
            unit: _selectedUnit,
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
    return AlertDialog(
      title: const Text('Item hinzufügen'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Bezeichnung',
                  hintText: 'z.B. Milch, Brot, Äpfel',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bezeichnung ist erforderlich';
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
                      decoration: const InputDecoration(
                        labelText: 'Menge',
                        hintText: '1',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Menge ist erforderlich';
                        }
                        final quantity = double.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Ungültige Menge';
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
                      decoration: const InputDecoration(labelText: 'Einheit'),
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
                decoration: const InputDecoration(
                  labelText: 'Notizen (optional)',
                  hintText: 'z.B. Bio, Marke, Größe',
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
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(onPressed: _addItem, child: const Text('Hinzufügen')),
      ],
    );
  }
}
