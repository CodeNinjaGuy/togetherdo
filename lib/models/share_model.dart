import 'package:equatable/equatable.dart';

enum ShareType { todo, shopping }

class ShareModel extends Equatable {
  final String id;
  final String code;
  final String ownerId;
  final String ownerName;
  final ShareType type;
  final String listName;
  final DateTime createdAt;
  final List<String> memberIds;
  final bool isActive;

  const ShareModel({
    required this.id,
    required this.code,
    required this.ownerId,
    required this.ownerName,
    required this.type,
    required this.listName,
    required this.createdAt,
    required this.memberIds,
    this.isActive = true,
  });

  factory ShareModel.fromJson(Map<String, dynamic> json) {
    return ShareModel(
      id: json['id'] as String,
      code: json['code'] as String,
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String,
      type: ShareType.values.firstWhere(
        (e) => e.toString() == 'ShareType.${json['type']}',
        orElse: () => ShareType.todo,
      ),
      listName: json['listName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      memberIds: List<String>.from(json['memberIds'] as List),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'type': type.toString().split('.').last,
      'listName': listName,
      'createdAt': createdAt.toIso8601String(),
      'memberIds': memberIds,
      'isActive': isActive,
    };
  }

  ShareModel copyWith({
    String? id,
    String? code,
    String? ownerId,
    String? ownerName,
    ShareType? type,
    String? listName,
    DateTime? createdAt,
    List<String>? memberIds,
    bool? isActive,
  }) {
    return ShareModel(
      id: id ?? this.id,
      code: code ?? this.code,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      type: type ?? this.type,
      listName: listName ?? this.listName,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isOwner => true; // Wird später dynamisch gesetzt
  int get memberCount => memberIds.length + 1; // +1 für den Owner

  @override
  List<Object?> get props => [
    id,
    code,
    ownerId,
    ownerName,
    type,
    listName,
    createdAt,
    memberIds,
    isActive,
  ];
}
