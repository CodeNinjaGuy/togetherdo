/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shopping_item_model.dart';

abstract class ShoppingRepository {
  Future<List<ShoppingItemModel>> getItems(String userId);
  Future<ShoppingItemModel> addItem({
    required String name,
    required double quantity,
    required String unit,
    required String userId,
    String? notes,
    required String listId,
    String? ean,
    String? imageUrl,
  });

  /// Legt einen Artikel an – oder erhöht die Menge, wenn in der Liste schon
  /// ein offener Artikel mit demselben Strichcode liegt (Mehrfach-Scan).
  Future<ShoppingItemModel> addOrIncrement({
    required String name,
    required double quantity,
    required String unit,
    required String userId,
    required String listId,
    required String ean,
    String? imageUrl,
    String? notes,
  });

  Future<ShoppingItemModel> updateItem(ShoppingItemModel item);
  Future<void> deleteItem(String itemId);
}

/// Sucht in [items] den offenen Artikel mit Strichcode [ean]. Gemeinsame
/// Logik für Firestore und Testdoppel.
ShoppingItemModel? findOpenItemByEan(
  Iterable<ShoppingItemModel> items,
  String listId,
  String ean,
) {
  for (final item in items) {
    if (item.listId == listId && item.ean == ean && !item.isPurchased) {
      return item;
    }
  }
  return null;
}

class MockShoppingRepository implements ShoppingRepository {
  final List<ShoppingItemModel> _items = [];

  /// Simulierte Verzögerung; in Tests auf `Duration.zero` setzen.
  Duration delay = const Duration(milliseconds: 300);

  List<ShoppingItemModel> get items => List.unmodifiable(_items);

  Future<void> _wait() => Future.delayed(delay);

  @override
  Future<List<ShoppingItemModel>> getItems(String userId) async {
    await _wait();
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
    String? ean,
    String? imageUrl,
  }) async {
    await _wait();
    final item = ShoppingItemModel(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_items.length}',
      name: name,
      quantity: quantity,
      unit: unit,
      userId: userId,
      notes: notes,
      listId: listId,
      createdAt: DateTime.now(),
      ean: ean,
      imageUrl: imageUrl,
    );
    _items.add(item);
    return item;
  }

  @override
  Future<ShoppingItemModel> addOrIncrement({
    required String name,
    required double quantity,
    required String unit,
    required String userId,
    required String listId,
    required String ean,
    String? imageUrl,
    String? notes,
  }) async {
    final existing = findOpenItemByEan(_items, listId, ean);
    if (existing != null) {
      final updated = existing.copyWith(
        quantity: existing.quantity + quantity,
        imageUrl: existing.imageUrl ?? imageUrl,
      );
      return updateItem(updated);
    }
    return addItem(
      name: name,
      quantity: quantity,
      unit: unit,
      userId: userId,
      notes: notes,
      listId: listId,
      ean: ean,
      imageUrl: imageUrl,
    );
  }

  @override
  Future<ShoppingItemModel> updateItem(ShoppingItemModel item) async {
    await _wait();
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
    await _wait();
    _items.removeWhere((item) => item.id == itemId);
  }
}

class FirebaseShoppingRepository implements ShoppingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('shopping_items');

  @override
  Future<List<ShoppingItemModel>> getItems(String userId) async {
    final query = await _col.where('userId', isEqualTo: userId).get();
    return query.docs
        .map((doc) => ShoppingItemModel.fromJson(doc.data()))
        .toList();
  }

  Stream<List<ShoppingItemModel>> getItemsStream(String listId) {
    return _col
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
    String? ean,
    String? imageUrl,
  }) async {
    final docRef = _col.doc();
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
      ean: ean,
      imageUrl: imageUrl,
    );
    await docRef.set(item.toJson());
    return item;
  }

  @override
  Future<ShoppingItemModel> addOrIncrement({
    required String name,
    required double quantity,
    required String unit,
    required String userId,
    required String listId,
    required String ean,
    String? imageUrl,
    String? notes,
  }) async {
    final snapshot = await _col
        .where('listId', isEqualTo: listId)
        .where('ean', isEqualTo: ean)
        .get();
    final existing = findOpenItemByEan(
      snapshot.docs.map((d) => ShoppingItemModel.fromJson(d.data())),
      listId,
      ean,
    );
    if (existing != null) {
      final updated = existing.copyWith(
        quantity: existing.quantity + quantity,
        imageUrl: existing.imageUrl ?? imageUrl,
      );
      return updateItem(updated);
    }
    return addItem(
      name: name,
      quantity: quantity,
      unit: unit,
      userId: userId,
      notes: notes,
      listId: listId,
      ean: ean,
      imageUrl: imageUrl,
    );
  }

  @override
  Future<ShoppingItemModel> updateItem(ShoppingItemModel item) async {
    await _col.doc(item.id).update(item.toJson());
    return item;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _col.doc(itemId).delete();
  }
}
