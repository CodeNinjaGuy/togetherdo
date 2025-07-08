import 'package:equatable/equatable.dart';
import '../../models/shopping_item_model.dart';

abstract class ShoppingEvent extends Equatable {
  const ShoppingEvent();

  @override
  List<Object?> get props => [];
}

class ShoppingLoadRequested extends ShoppingEvent {
  final String userId;
  final String listId;

  const ShoppingLoadRequested({required this.userId, required this.listId});

  @override
  List<Object?> get props => [userId, listId];
}

class ShoppingAddRequested extends ShoppingEvent {
  final String name;
  final double quantity;
  final String unit;
  final String userId;
  final String? notes;
  final String listId;

  const ShoppingAddRequested({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.userId,
    this.notes,
    required this.listId,
  });

  @override
  List<Object?> get props => [name, quantity, unit, userId, notes, listId];
}

class ShoppingUpdateRequested extends ShoppingEvent {
  final ShoppingItemModel item;

  const ShoppingUpdateRequested({required this.item});

  @override
  List<Object?> get props => [item];
}

class ShoppingDeleteRequested extends ShoppingEvent {
  final String itemId;

  const ShoppingDeleteRequested({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

class ShoppingTogglePurchasedRequested extends ShoppingEvent {
  final String itemId;
  final bool isPurchased;
  final String? purchasedBy;

  const ShoppingTogglePurchasedRequested({
    required this.itemId,
    required this.isPurchased,
    this.purchasedBy,
  });

  @override
  List<Object?> get props => [itemId, isPurchased, purchasedBy];
}
