/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import '../models/product_info.dart';
import '../repositories/product_repository.dart';
import '../repositories/shopping_repository.dart';

/// Was mit einem gescannten Artikel passiert ist.
enum ScanAddOutcome { added, incremented }

/// Verbindet den Scanner-Bildschirm mit Daten: Produkt nachschlagen,
/// in die Liste legen, unbekannte Codes benennen. Abstrakt, damit der
/// Bildschirm in Tests und in der Debug-Demo ohne Firebase läuft.
abstract class ScannerSession {
  Future<ProductLookupResult> lookup(String ean);

  Future<ScanAddOutcome> addToList(ProductInfo product, double quantity);

  Future<ProductInfo> rememberProduct({
    required String ean,
    required String name,
    String? brand,
    String? packageSize,
  });
}

/// Scanner-Sitzung für eine echte Einkaufsliste.
class ListScannerSession implements ScannerSession {
  ListScannerSession({
    required this.products,
    required this.shopping,
    required this.listId,
    required this.userId,
    required this.defaultUnit,
  });

  final ProductRepository products;
  final ShoppingRepository shopping;
  final String listId;
  final String userId;

  /// Einheit für gescannte Artikel, in der Regel „Stück“.
  final String defaultUnit;

  @override
  Future<ProductLookupResult> lookup(String ean) => products.find(ean);

  @override
  Future<ScanAddOutcome> addToList(ProductInfo product, double quantity) async {
    final item = await shopping.addOrIncrement(
      name: product.name,
      quantity: quantity,
      unit: defaultUnit,
      userId: userId,
      listId: listId,
      ean: product.ean,
      imageUrl: product.imageUrl,
    );
    return item.quantity > quantity
        ? ScanAddOutcome.incremented
        : ScanAddOutcome.added;
  }

  @override
  Future<ProductInfo> rememberProduct({
    required String ean,
    required String name,
    String? brand,
    String? packageSize,
  }) => products.rememberUserProduct(
    ean: ean,
    name: name,
    userId: userId,
    brand: brand,
    quantity: packageSize,
  );
}
