import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/shopping_repository.dart';
import 'shopping_event.dart';
import 'shopping_state.dart';

class ShoppingBloc extends Bloc<ShoppingEvent, ShoppingState> {
  final ShoppingRepository _shoppingRepository;

  ShoppingBloc({required ShoppingRepository shoppingRepository})
    : _shoppingRepository = shoppingRepository,
      super(const ShoppingInitial()) {
    on<ShoppingLoadRequested>(_onShoppingLoadRequested);
    on<ShoppingAddRequested>(_onShoppingAddRequested);
    on<ShoppingUpdateRequested>(_onShoppingUpdateRequested);
    on<ShoppingDeleteRequested>(_onShoppingDeleteRequested);
    on<ShoppingTogglePurchasedRequested>(_onShoppingTogglePurchasedRequested);
  }

  Future<void> _onShoppingLoadRequested(
    ShoppingLoadRequested event,
    Emitter<ShoppingState> emit,
  ) async {
    emit(const ShoppingLoading());
    try {
      final items = await _shoppingRepository.getItems(event.userId);
      emit(ShoppingLoadSuccess(items: items));
    } catch (e) {
      emit(ShoppingLoadFailure(message: e.toString()));
    }
  }

  Future<void> _onShoppingAddRequested(
    ShoppingAddRequested event,
    Emitter<ShoppingState> emit,
  ) async {
    try {
      final item = await _shoppingRepository.addItem(
        name: event.name,
        quantity: event.quantity,
        unit: event.unit,
        userId: event.userId,
        notes: event.notes,
        listId: event.listId,
      );
      emit(ShoppingAddSuccess(item: item));

      // Lade die aktualisierte Liste
      final items = await _shoppingRepository.getItems(event.userId);
      emit(ShoppingLoadSuccess(items: items));
    } catch (e) {
      emit(ShoppingAddFailure(message: e.toString()));
    }
  }

  Future<void> _onShoppingUpdateRequested(
    ShoppingUpdateRequested event,
    Emitter<ShoppingState> emit,
  ) async {
    try {
      final item = await _shoppingRepository.updateItem(event.item);
      emit(ShoppingUpdateSuccess(item: item));

      // Lade die aktualisierte Liste
      final items = await _shoppingRepository.getItems(event.item.userId);
      emit(ShoppingLoadSuccess(items: items));
    } catch (e) {
      emit(ShoppingUpdateFailure(message: e.toString()));
    }
  }

  Future<void> _onShoppingDeleteRequested(
    ShoppingDeleteRequested event,
    Emitter<ShoppingState> emit,
  ) async {
    try {
      await _shoppingRepository.deleteItem(event.itemId);
      emit(ShoppingDeleteSuccess(itemId: event.itemId));

      // Lade die aktualisierte Liste
      final currentState = state;
      if (currentState is ShoppingLoadSuccess) {
        final updatedItems = currentState.items
            .where((item) => item.id != event.itemId)
            .toList();
        emit(ShoppingLoadSuccess(items: updatedItems));
      }
    } catch (e) {
      emit(ShoppingDeleteFailure(message: e.toString()));
    }
  }

  Future<void> _onShoppingTogglePurchasedRequested(
    ShoppingTogglePurchasedRequested event,
    Emitter<ShoppingState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is ShoppingLoadSuccess) {
        final item = currentState.items.firstWhere((i) => i.id == event.itemId);
        final updatedItem = item.copyWith(
          isPurchased: event.isPurchased,
          purchasedBy: event.isPurchased ? event.purchasedBy : null,
          purchasedAt: event.isPurchased ? DateTime.now() : null,
        );
        await _shoppingRepository.updateItem(updatedItem);

        final updatedItems = currentState.items.map((i) {
          return i.id == event.itemId ? updatedItem : i;
        }).toList();
        emit(ShoppingLoadSuccess(items: updatedItems));
      }
    } catch (e) {
      emit(ShoppingUpdateFailure(message: e.toString()));
    }
  }
}
