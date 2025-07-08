import 'package:equatable/equatable.dart';

class ShoppingItemModel extends Equatable {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool isPurchased;
  final String? purchasedBy;
  final DateTime? purchasedAt;
  final DateTime createdAt;
  final String userId;
  final String? notes;
  final String listId;

  const ShoppingItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.isPurchased = false,
    this.purchasedBy,
    this.purchasedAt,
    required this.createdAt,
    required this.userId,
    this.notes,
    required this.listId,
  });

  factory ShoppingItemModel.fromJson(Map<String, dynamic> json) {
    return ShoppingItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      isPurchased: json['isPurchased'] as bool? ?? false,
      purchasedBy: json['purchasedBy'] as String?,
      purchasedAt: json['purchasedAt'] != null
          ? DateTime.parse(json['purchasedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['userId'] as String,
      notes: json['notes'] as String?,
      listId: json['listId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isPurchased': isPurchased,
      'purchasedBy': purchasedBy,
      'purchasedAt': purchasedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'notes': notes,
      'listId': listId,
    };
  }

  ShoppingItemModel copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    bool? isPurchased,
    String? purchasedBy,
    DateTime? purchasedAt,
    DateTime? createdAt,
    String? userId,
    String? notes,
    String? listId,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isPurchased: isPurchased ?? this.isPurchased,
      purchasedBy: purchasedBy ?? this.purchasedBy,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
      listId: listId ?? this.listId,
    );
  }

  String get displayQuantity {
    if (quantity == quantity.toInt()) {
      return '${quantity.toInt()} $unit';
    }
    return '${quantity.toStringAsFixed(1)} $unit';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    quantity,
    unit,
    isPurchased,
    purchasedBy,
    purchasedAt,
    createdAt,
    userId,
    notes,
    listId,
  ];
}
