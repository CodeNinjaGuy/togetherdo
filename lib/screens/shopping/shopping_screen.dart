import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/shopping/shopping_item_widget.dart';
import '../../widgets/shopping/add_shopping_item_dialog.dart';
import '../../repositories/shopping_repository.dart';
import '../../repositories/list_repository.dart';
import '../../models/shopping_item_model.dart';
import '../../models/list_model.dart';

class ShoppingScreen extends StatefulWidget {
  final String listId;
  final String? highlightItemId;

  const ShoppingScreen({super.key, required this.listId, this.highlightItemId});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  String? _highlightItemId;
  late final FirebaseShoppingRepository _shoppingRepository;
  late final FirebaseListRepository _listRepository;

  @override
  void initState() {
    super.initState();
    _highlightItemId = widget.highlightItemId;
    _shoppingRepository =
        context.read<ShoppingRepository>() as FirebaseShoppingRepository;
    _listRepository = context.read<ListRepository>() as FirebaseListRepository;
  }

  @override
  void didUpdateWidget(covariant ShoppingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightItemId != oldWidget.highlightItemId) {
      debugPrint(
        "HighlightItemId geändert: ${oldWidget.highlightItemId} -> ${widget.highlightItemId}",
      );
      setState(() {
        _highlightItemId = widget.highlightItemId;
      });
    }
  }

  void _onHighlightEnd() {
    setState(() {
      _highlightItemId = null;
    });
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AddShoppingItemDialog(listId: widget.listId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einkaufsliste')),
      body: FutureBuilder<ListModel?>(
        future: _listRepository.getListById(widget.listId),
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
                          'Nur-Lese-Modus: Du kannst diese Liste nur anzeigen. Nur der Besitzer kann Items bearbeiten.',
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
              // Shopping Items Stream
              Expanded(
                child: StreamBuilder<List<ShoppingItemModel>>(
                  stream: _shoppingRepository.getItemsStream(widget.listId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Fehler beim Laden: \\${snapshot.error}'),
                      );
                    }
                    final items = snapshot.data ?? <ShoppingItemModel>[];

                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 80,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Einkaufsliste ist leer',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canEdit
                                  ? 'Füge dein erstes Item hinzu'
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

                    // Gruppiere Items nach Status
                    final pendingItems = items
                        .where((item) => item.isPurchased == false)
                        .toList();
                    final purchasedItems = items
                        .where((item) => item.isPurchased == true)
                        .toList();

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (pendingItems.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Noch zu kaufen',
                            pendingItems.length,
                          ),
                          const SizedBox(height: 8),
                          ...pendingItems.map(
                            (item) => ShoppingItemWidget(
                              item: item,
                              highlight: _highlightItemId == item.id,
                              onHighlightEnd: _onHighlightEnd,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (purchasedItems.isNotEmpty) ...[
                          _buildSectionHeader('Gekauft', purchasedItems.length),
                          const SizedBox(height: 8),
                          ...purchasedItems.map(
                            (item) => ShoppingItemWidget(
                              item: item,
                              highlight: _highlightItemId == item.id,
                              onHighlightEnd: _onHighlightEnd,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<ListModel?>(
        future: _listRepository.getListById(widget.listId),
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
            onPressed: _showAddItemDialog,
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
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
      ],
    );
  }
}
