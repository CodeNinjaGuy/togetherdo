import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../repositories/list_repository.dart';
import '../../repositories/shopping_repository.dart';
import '../../models/shopping_item_model.dart';
import '../../models/list_model.dart';

class ShoppingItemWidget extends StatefulWidget {
  final ShoppingItemModel item;
  final bool highlight;
  final VoidCallback? onHighlightEnd;

  const ShoppingItemWidget({
    super.key,
    required this.item,
    this.highlight = false,
    this.onHighlightEnd,
  });

  @override
  State<ShoppingItemWidget> createState() => _ShoppingItemWidgetState();
}

class _ShoppingItemWidgetState extends State<ShoppingItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  bool _isHighlighted = false;
  bool _wasHighlighted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.green.withOpacity(0.3),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.highlight) {
      _startHighlightAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant ShoppingItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !_wasHighlighted) {
      _startHighlightAnimation();
    }
  }

  void _startHighlightAnimation() async {
    setState(() {
      _isHighlighted = true;
      _wasHighlighted = true;
    });

    // Dezente Blink-Animation
    for (int i = 0; i < 2; i++) {
      await _controller.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      await _controller.reverse();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Nach dem Blinken das Highlight komplett entfernen
    setState(() {
      _isHighlighted = false;
      _wasHighlighted = false;
    });
    widget.onHighlightEnd?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Card(
          color: _isHighlighted ? _colorAnimation.value : null,
          margin: const EdgeInsets.only(bottom: 8),
          elevation: _isHighlighted ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: _isHighlighted
                ? BorderSide(color: Colors.green, width: 1)
                : BorderSide.none,
          ),
          child: _buildListTile(context),
        );
      },
    );
  }

  Widget _buildListTile(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: widget.item.isPurchased,
        onChanged: _canEdit(context)
            ? (value) async {
                if (value != null) {
                  final authState = context.read<AuthBloc>().state;
                  final currentUser = authState is AuthAuthenticated
                      ? authState.user
                      : null;
                  final updatedItem = widget.item.copyWith(
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
        widget.item.name,
        style: TextStyle(
          decoration: widget.item.isPurchased
              ? TextDecoration.lineThrough
              : null,
          color: widget.item.isPurchased
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.item.displayQuantity,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.item.notes != null &&
                  widget.item.notes!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (widget.item.isPurchased && widget.item.purchasedBy != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Gekauft von ${(context.read<AuthBloc>().state is AuthAuthenticated && (context.read<AuthBloc>().state as AuthAuthenticated).user.displayName == widget.item.purchasedBy) ? 'dir' : widget.item.purchasedBy!}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.item.purchasedAt != null) ...[
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
                    ).format(widget.item.purchasedAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
      trailing: _canEdit(context)
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showDeleteDialog(context),
            )
          : null,
    );
  }

  bool _canEdit(BuildContext context) {
    final list = (context.read<ListRepository>() as FirebaseListRepository)
        .getListById(widget.item.listId);
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';
    // Dummy-Check, ggf. anpassen
    return true;
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item löschen'),
        content: Text('Möchtest du "${widget.item.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              await (context.read<ShoppingRepository>()
                      as FirebaseShoppingRepository)
                  .deleteItem(widget.item.id);
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
