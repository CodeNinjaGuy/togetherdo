/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:equatable/equatable.dart';

/// Woher die Produktdaten stammen.
enum ProductSource {
  /// Open Food Facts (Lebensmittel).
  off,

  /// Open Beauty Facts (Kosmetik).
  obf,

  /// Open Products Facts (sonstige Waren).
  opf,

  /// Von einem Nutzer der App benannt.
  nutzer;

  static ProductSource parse(String? raw) => ProductSource.values.firstWhere(
    (s) => s.name == raw,
    orElse: () => ProductSource.nutzer,
  );

  /// Quellen, deren Daten unter ODbL stehen und genannt werden müssen.
  bool get isOpenFacts => this != ProductSource.nutzer;
}

/// Ein per Strichcode erkanntes Produkt. Wird in Firestore unter
/// `produkte/{ean}` zwischengespeichert, damit nicht jeder Scan ins
/// Internet muss. Feldnamen dort auf Deutsch, siehe [toJson].
class ProductInfo extends Equatable {
  /// Längste zulässige Zeichenkette für Name, Marke und Menge.
  static const int maxTextLength = 120;

  /// Längste zulässige Bild-URL.
  static const int maxUrlLength = 500;

  const ProductInfo({
    required this.ean,
    required this.name,
    this.brand,
    this.quantity,
    this.imageUrl,
    required this.source,
    required this.updatedAt,
    this.createdBy,
  });

  final String ean;
  final String name;
  final String? brand;

  /// Füllmenge wie auf der Packung, z. B. „500 g“.
  final String? quantity;
  final String? imageUrl;
  final ProductSource source;
  final DateTime updatedAt;

  /// Nutzer-ID, falls die Daten von einem Nutzer stammen.
  final String? createdBy;

  /// Gültige Strichcodes für Produkte: 8, 12, 13 oder 14 Ziffern
  /// (EAN-8, UPC-A, EAN-13, GTIN-14).
  static bool isValidEan(String code) =>
      RegExp(r'^\d{8}$|^\d{12,14}$').hasMatch(code);

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      ean: json['ean'] as String,
      name: json['name'] as String,
      brand: _emptyToNull(json['marke'] as String?),
      quantity: _emptyToNull(json['menge'] as String?),
      imageUrl: _emptyToNull(json['bildUrl'] as String?),
      source: ProductSource.parse(json['quelle'] as String?),
      updatedAt: json['aktualisiertAm'] is String
          ? (DateTime.tryParse(json['aktualisiertAm'] as String) ??
                    DateTime.fromMillisecondsSinceEpoch(0))
                .toLocal()
          : DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: json['erstelltVon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'ean': ean,
    'name': name,
    'marke': brand,
    'menge': quantity,
    'bildUrl': imageUrl,
    'quelle': source.name,
    'aktualisiertAm': updatedAt.toUtc().toIso8601String(),
    if (createdBy != null) 'erstelltVon': createdBy,
  };

  ProductInfo copyWith({
    String? name,
    String? brand,
    String? quantity,
    String? imageUrl,
    ProductSource? source,
    DateTime? updatedAt,
    String? createdBy,
  }) => ProductInfo(
    ean: ean,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    quantity: quantity ?? this.quantity,
    imageUrl: imageUrl ?? this.imageUrl,
    source: source ?? this.source,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy ?? this.createdBy,
  );

  /// Marke und Menge in einer Zeile, z. B. „Ferrero · 450 g“.
  String get detailLine => [
    brand,
    quantity,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  static String? _emptyToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  @override
  List<Object?> get props => [
    ean,
    name,
    brand,
    quantity,
    imageUrl,
    source,
    updatedAt,
    createdBy,
  ];
}
