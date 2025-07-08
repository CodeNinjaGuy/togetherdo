import 'package:equatable/equatable.dart';

enum ListType { todo, shopping }

class ListModel extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final String ownerName;
  final ListType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isShared;
  final String? shareCode;
  final List<String> memberIds;
  final List<String> memberNames;
  final bool allowEdit;

  const ListModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerName,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.isShared = false,
    this.shareCode,
    this.memberIds = const [],
    this.memberNames = const [],
    this.allowEdit = true,
  });

  factory ListModel.fromJson(Map<String, dynamic> json) {
    return ListModel(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String? ?? 'Unbekannt',
      type: ListType.values.firstWhere(
        (e) => e.toString() == 'ListType.${json['type']}',
        orElse: () => ListType.todo,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isShared: json['isShared'] as bool? ?? false,
      shareCode: json['shareCode'] as String?,
      memberIds: List<String>.from(json['memberIds'] as List? ?? []),
      memberNames: List<String>.from(json['memberNames'] as List? ?? []),
      allowEdit: json['allowEdit'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'type': type.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isShared': isShared,
      'shareCode': shareCode,
      'memberIds': memberIds,
      'memberNames': memberNames,
      'allowEdit': allowEdit,
    };
  }

  ListModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? ownerName,
    ListType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isShared,
    String? shareCode,
    List<String>? memberIds,
    List<String>? memberNames,
    bool? allowEdit,
  }) {
    return ListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isShared: isShared ?? this.isShared,
      shareCode: shareCode ?? this.shareCode,
      memberIds: memberIds ?? this.memberIds,
      memberNames: memberNames ?? this.memberNames,
      allowEdit: allowEdit ?? this.allowEdit,
    );
  }

  bool get isOwner => true; // Wird später dynamisch gesetzt
  int get memberCount => memberIds.length + 1; // +1 für den Owner

  @override
  List<Object?> get props => [
    id,
    name,
    ownerId,
    ownerName,
    type,
    createdAt,
    updatedAt,
    isShared,
    shareCode,
    memberIds,
    memberNames,
    allowEdit,
  ];
}
