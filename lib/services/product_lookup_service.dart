/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product_info.dart';

/// Warum eine Produktsuche nichts geliefert hat.
enum ProductLookupFailure {
  /// Kein Netz oder Zeitlimit überschritten.
  offline,

  /// Antwort des Dienstes unbrauchbar (Serverfehler, kaputtes JSON).
  serverError,
}

class ProductLookupException implements Exception {
  const ProductLookupException(this.failure, [this.cause]);

  final ProductLookupFailure failure;
  final Object? cause;

  bool get isOffline => failure == ProductLookupFailure.offline;

  @override
  String toString() => 'ProductLookupException(${failure.name}, $cause)';
}

/// Fragt Open Food Facts (und als Rückfall Open Beauty Facts sowie Open
/// Products Facts) nach einem Strichcode. Die Daten stehen unter ODbL,
/// die App nennt die Quelle in der Ergebnis-Karte.
///
/// Liefert `null`, wenn kein Dienst das Produkt kennt. Wirft
/// [ProductLookupException], wenn kein Dienst erreichbar war.
class ProductLookupService {
  ProductLookupService({
    http.Client? client,
    required String appVersion,
    this.timeout = const Duration(seconds: 8),
    List<Uri Function(String ean)>? endpoints,
  }) : _client = client ?? http.Client(),
       userAgent = 'ToGetherDo/$appVersion (https://seebubble.me)',
       _endpoints = endpoints ?? _defaultEndpoints;

  final http.Client _client;
  final String userAgent;
  final Duration timeout;
  final List<Uri Function(String ean)> _endpoints;

  static const String _fields =
      'product_name,product_name_de,brands,quantity,'
      'image_front_small_url,categories_tags';

  static Uri _productUri(String host, String ean) =>
      Uri.https(host, '/api/v2/product/$ean', {'fields': _fields});

  static final List<Uri Function(String ean)> _defaultEndpoints = [
    (ean) => _productUri('world.openfoodfacts.org', ean),
    (ean) => _productUri('world.openbeautyfacts.org', ean),
    (ean) => _productUri('world.openproductsfacts.org', ean),
  ];

  static const List<ProductSource> _sourcesInOrder = [
    ProductSource.off,
    ProductSource.obf,
    ProductSource.opf,
  ];

  Future<ProductInfo?> lookup(String ean) async {
    ProductLookupException? lastError;
    for (var i = 0; i < _endpoints.length; i++) {
      try {
        final found = await _query(_endpoints[i](ean), ean, _sourceAt(i));
        if (found != null) return found;
      } on ProductLookupException catch (e) {
        lastError = e;
      }
    }
    // Erst wenn kein Dienst erreichbar war, gilt die Suche als gescheitert.
    if (lastError != null && lastError.isOffline) throw lastError;
    return null;
  }

  ProductSource _sourceAt(int index) => index < _sourcesInOrder.length
      ? _sourcesInOrder[index]
      : ProductSource.opf;

  Future<ProductInfo?> _query(Uri uri, String ean, ProductSource source) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on SocketException catch (e) {
      throw ProductLookupException(ProductLookupFailure.offline, e);
    } on TimeoutException catch (e) {
      throw ProductLookupException(ProductLookupFailure.offline, e);
    } on http.ClientException catch (e) {
      throw ProductLookupException(ProductLookupFailure.offline, e);
    } on FormatException catch (e) {
      // z. B. ungültiger Header-Wert: nicht als „unbekanntes Produkt“ tarnen.
      throw ProductLookupException(ProductLookupFailure.serverError, e);
    }

    // 404 = Produkt unbekannt, das ist eine gültige Antwort.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ProductLookupException(
        ProductLookupFailure.serverError,
        'HTTP ${response.statusCode}',
      );
    }
    try {
      return parseProduct(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
        ean: ean,
        source: source,
      );
    } on FormatException catch (e) {
      throw ProductLookupException(ProductLookupFailure.serverError, e);
    }
  }

  /// Wandelt die Antwort der Open-Facts-API in ein [ProductInfo]. Öffentlich,
  /// damit die Tests gegen gespeicherte Antworten laufen können.
  @visibleForTesting
  static ProductInfo? parseProduct(
    Map<String, dynamic> json, {
    required String ean,
    required ProductSource source,
    DateTime? now,
  }) {
    if (json['status'] != 1 && json['status'] != '1') return null;
    final product = json['product'];
    if (product is! Map<String, dynamic>) return null;

    String? text(String key) {
      final v = product[key];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : _clip(t, ProductInfo.maxTextLength);
    }

    final name = text('product_name_de') ?? text('product_name');
    if (name == null) return null;

    final rawBrands = text('brands');
    final brand = rawBrands?.split(',').first.trim();
    final image = text('image_front_small_url');

    return ProductInfo(
      ean: ean,
      name: name,
      brand: (brand == null || brand.isEmpty) ? null : brand,
      quantity: text('quantity'),
      imageUrl:
          (image != null &&
              image.startsWith('https://') &&
              image.length <= ProductInfo.maxUrlLength)
          ? image
          : null,
      source: source,
      updatedAt: now ?? DateTime.now(),
    );
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  void close() => _client.close();
}
