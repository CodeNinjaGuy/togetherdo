import 'package:equatable/equatable.dart';
import '../../models/shopping_item_model.dart';

abstract class ShoppingState extends Equatable {
  const ShoppingState();

  @override
  List<Object?> get props => [];
}

class ShoppingInitial extends ShoppingState {
  const ShoppingInitial();
}

class ShoppingLoading extends ShoppingState {
  const ShoppingLoading();
}

class ShoppingLoadSuccess extends ShoppingState {
  final List<ShoppingItemModel> items;

  const ShoppingLoadSuccess({required this.items});

  @override
  List<Object?> get props => [items];
}

class ShoppingLoadFailure extends ShoppingState {
  final String message;

  const ShoppingLoadFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShoppingAddSuccess extends ShoppingState {
  final ShoppingItemModel item;

  const ShoppingAddSuccess({required this.item});

  @override
  List<Object?> get props => [item];
}

class ShoppingAddFailure extends ShoppingState {
  final String message;

  const ShoppingAddFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShoppingUpdateSuccess extends ShoppingState {
  final ShoppingItemModel item;

  const ShoppingUpdateSuccess({required this.item});

  @override
  List<Object?> get props => [item];
}

class ShoppingUpdateFailure extends ShoppingState {
  final String message;

  const ShoppingUpdateFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShoppingDeleteSuccess extends ShoppingState {
  final String itemId;

  const ShoppingDeleteSuccess({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

class ShoppingDeleteFailure extends ShoppingState {
  final String message;

  const ShoppingDeleteFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
