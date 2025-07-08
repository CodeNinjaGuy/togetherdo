import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../repositories/list_repository.dart';
import '../../repositories/shopping_repository.dart';
import '../../models/shopping_item_model.dart';
import '../../models/list_model.dart';

class ShoppingItemWidget extends StatelessWidget {
  final ShoppingItemModel item;

  const ShoppingItemWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ListModel?>(
      stream: Stream.fromFuture(
        (context.read<ListRepository>() as FirebaseListRepository).getListById(
          item.listId,
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

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Checkbox(
              value: item.isPurchased,
              onChanged: canEdit
                  ? (value) async {
                      if (value != null) {
                        final authState = context.read<AuthBloc>().state;
                        final currentUser = authState is AuthAuthenticated
                            ? authState.user
                            : null;
                        final updatedItem = item.copyWith(
                          isPurchased: value,
                          purchasedBy: value ? currentUser?.displayName : null,
                          purchasedAt: value ? DateTime.now() : null,
                        );
                        await (context.read<ShoppingRepository>()
                                as FirebaseShoppingRepository)
                            .updateItem(updatedItem);
                      }
                    }
                  : null,
            ),
            title: Text(
              item.name,
              style: TextStyle(
                decoration: item.isPurchased
                    ? TextDecoration.lineThrough
                    : null,
                color: item.isPurchased
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.displayQuantity,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.isPurchased && item.purchasedBy != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Gekauft von ${(authState is AuthAuthenticated && authState.user.displayName == item.purchasedBy) ? 'dir' : item.purchasedBy!}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.purchasedAt != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat(
                            'dd.MM.yyyy HH:mm',
                          ).format(item.purchasedAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            trailing: canEdit
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showDeleteDialog(context),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item löschen'),
        content: Text('Möchtest du "${item.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              await (context.read<ShoppingRepository>()
                      as FirebaseShoppingRepository)
                  .deleteItem(item.id);
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
