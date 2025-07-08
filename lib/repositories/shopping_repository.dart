import '../models/shopping_item_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ShoppingRepository {
  Future<List<ShoppingItemModel>> getItems(String userId);
  Future<ShoppingItemModel> addItem({
    required String name,
    required double quantity,
    required String unit,
    required String userId,
    String? notes,
    required String listId,
  });
  Future<ShoppingItemModel> updateItem(ShoppingItemModel item);
  Future<void> deleteItem(String itemId);
}

class MockShoppingRepository implements ShoppingRepository {
  final List<ShoppingItemModel> _items = [];

  @override
  Future<List<ShoppingItemModel>> getItems(String userId) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 500));

    return _items.where((item) => item.userId == userId).toList();
  }

  @override
  Future<ShoppingItemModel> addItem({
    required String name,
    required double quantity,
    required String unit,
    required String userId,
    String? notes,
    required String listId,
  }) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 800));

    final item = ShoppingItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      quantity: quantity,
      unit: unit,
      userId: userId,
      notes: notes,
      listId: listId,
      createdAt: DateTime.now(),
    );

    _items.add(item);
    return item;
  }

  @override
  Future<ShoppingItemModel> updateItem(ShoppingItemModel item) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 600));

    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      return item;
    } else {
      throw Exception('Einkaufsitem nicht gefunden');
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 400));

    _items.removeWhere((item) => item.id == itemId);
  }
}

class FirebaseShoppingRepository implements ShoppingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<ShoppingItemModel>> getItems(String userId) async {
    final query = await _firestore
        .collection('shopping_items')
        .where('userId', isEqualTo: userId)
        .get();
    return query.docs
        .map((doc) => ShoppingItemModel.fromJson(doc.data()))
        .toList();
  }

  Stream<List<ShoppingItemModel>> getItemsStream(String listId) {
    return _firestore
        .collection('shopping_items')
        .where('listId', isEqualTo: listId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShoppingItemModel.fromJson(doc.data()))
              .toList(),
        );
  }

  @override
  Future<ShoppingItemModel> addItem({
    required String name,
    required double quantity,
    required String unit,
    required String userId,
    String? notes,
    required String listId,
  }) async {
    final docRef = _firestore.collection('shopping_items').doc();
    final now = DateTime.now();
    final item = ShoppingItemModel(
      id: docRef.id,
      name: name,
      quantity: quantity,
      unit: unit,
      userId: userId,
      notes: notes,
      listId: listId,
      createdAt: now,
      isPurchased: false,
    );
    await docRef.set(item.toJson());
    return item;
  }

  @override
  Future<ShoppingItemModel> updateItem(ShoppingItemModel item) async {
    final docRef = _firestore.collection('shopping_items').doc(item.id);
    await docRef.update(item.toJson());
    return item;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    final docRef = _firestore.collection('shopping_items').doc(itemId);
    await docRef.delete();
  }
}
