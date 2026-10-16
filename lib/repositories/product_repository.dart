/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_info.dart';
import '../services/product_lookup_service.dart';

/// Ergebnis einer Produktsuche nach Strichcode.
enum ProductLookupStatus {
  /// Produkt gefunden (Zwischenspeicher oder Open Facts).
  found,

  /// Kein Dienst kennt den Code.
  unknown,

  /// Kein Netz und nichts im Zwischenspeicher.
  offline,
}

class ProductLookupResult {
  const ProductLookupResult._(this.status, this.product);

  const ProductLookupResult.found(ProductInfo product)
    : this._(ProductLookupStatus.found, product);
  const ProductLookupResult.unknown()
    : this._(ProductLookupStatus.unknown, null);
  const ProductLookupResult.offline()
    : this._(ProductLookupStatus.offline, null);

  final ProductLookupStatus status;
  final ProductInfo? product;
}

/// Ablage der Produkt-Dokumente (`produkte/{ean}`). Abstrakt, damit die
/// Tests ohne Firebase laufen.
abstract class ProductStore {
  Future<Map<String, dynamic>?> read(String ean);
  Future<void> write(String ean, Map<String, dynamic> data);
}

class FirestoreProductStore implements ProductStore {
  FirestoreProductStore([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('produkte');

  @override
  Future<Map<String, dynamic>?> read(String ean) async {
    final snap = await _col.doc(ean).get();
    return snap.data();
  }

  @override
  Future<void> write(String ean, Map<String, dynamic> data) =>
      _col.doc(ean).set(data);
}

class InMemoryProductStore implements ProductStore {
  final Map<String, Map<String, dynamic>> docs = {};
  int reads = 0;
  int writes = 0;

  @override
  Future<Map<String, dynamic>?> read(String ean) async {
    reads++;
    return docs[ean];
  }

  @override
  Future<void> write(String ean, Map<String, dynamic> data) async {
    writes++;
    docs[ean] = Map<String, dynamic>.from(data);
  }
}

/// Zuletzt gescannte Codes im Gerät, damit der Scanner auch ohne Netz
/// Bekanntes sofort zeigt. Hält höchstens [maxEntries] Einträge.
class ProductLocalCache {
  ProductLocalCache({this.maxEntries = 100});

  static const String _key = 'scanner.produkte';
  final int maxEntries;

  Future<ProductInfo?> read(String ean) async {
    final map = await _load();
    final raw = map[ean];
    if (raw is! Map<String, dynamic>) return null;
    try {
      return ProductInfo.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ProductInfo product) async {
    final map = await _load();
    map.remove(product.ean);
    map[product.ean] = product.toJson();
    while (map.length > maxEntries) {
      map.remove(map.keys.first);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(map));
  }

  Future<Map<String, dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

/// Findet Produkte zu Strichcodes: erst Gerät, dann Firestore, dann Open
/// Facts. Treffer aus dem Netz landen in Firestore und im Gerät, damit das
/// nächste Mitglied sie sofort bekommt.
class ProductRepository {
  ProductRepository({
    required ProductStore store,
    required ProductLookupService lookupService,
    ProductLocalCache? localCache,
    DateTime Function()? now,
  }) : _store = store,
       _lookup = lookupService,
       _local = localCache ?? ProductLocalCache(),
       _now = now ?? DateTime.now;

  final ProductStore _store;
  final ProductLookupService _lookup;
  final ProductLocalCache _local;
  final DateTime Function() _now;

  Future<ProductLookupResult> find(String ean) async {
    final code = ean.trim();
    if (!ProductInfo.isValidEan(code)) {
      return const ProductLookupResult.unknown();
    }

    final local = await _local.read(code);
    if (local != null) return ProductLookupResult.found(local);

    try {
      final remote = await _store.read(code);
      if (remote != null) {
        final product = ProductInfo.fromJson(remote);
        await _local.write(product);
        return ProductLookupResult.found(product);
      }
    } catch (e) {
      // Firestore nicht erreichbar: trotzdem Open Facts versuchen.
      debugPrint('Produkt-Zwischenspeicher nicht erreichbar: $e');
    }

    try {
      final fetched = await _lookup.lookup(code);
      if (fetched == null) return const ProductLookupResult.unknown();
      await _local.write(fetched);
      await _storeQuietly(fetched);
      return ProductLookupResult.found(fetched);
    } on ProductLookupException catch (e) {
      if (e.isOffline) return const ProductLookupResult.offline();
      return const ProductLookupResult.unknown();
    }
  }

  /// Merkt sich einen Namen, den ein Nutzer für einen unbekannten Code
  /// eingegeben hat – im Gerät und für alle in Firestore.
  Future<ProductInfo> rememberUserProduct({
    required String ean,
    required String name,
    required String userId,
    String? brand,
    String? quantity,
  }) async {
    final product = ProductInfo(
      ean: ean.trim(),
      name: _clip(name.trim(), ProductInfo.maxTextLength),
      brand: _nullIfEmpty(brand),
      quantity: _nullIfEmpty(quantity),
      source: ProductSource.nutzer,
      updatedAt: _now(),
      createdBy: userId,
    );
    await _local.write(product);
    await _storeQuietly(product);
    return product;
  }

  Future<void> _storeQuietly(ProductInfo product) async {
    try {
      await _store.write(product.ean, product.toJson());
    } catch (e) {
      // Regeln können das Überschreiben verbieten; der Scan bleibt gültig.
      debugPrint('Produkt konnte nicht zwischengespeichert werden: $e');
    }
  }

  static String? _nullIfEmpty(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return null;
    return _clip(t, ProductInfo.maxTextLength);
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
