import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final String? fcmToken;
  final Map<String, bool> notificationSettings;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
    required this.lastLoginAt,
    this.fcmToken,
    this.notificationSettings = const {
      'todoCreated': true,
      'todoCompleted': true,
      'todoDeleted': true,
      'memberAdded': true,
      'memberRemoved': true,
      'chatMessage': true,
    },
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
      fcmToken: json['fcmToken'] as String?,
      notificationSettings: Map<String, bool>.from(
        json['notificationSettings'] as Map<String, dynamic>? ??
            {
              'todoCreated': true,
              'todoCompleted': true,
              'todoDeleted': true,
              'memberAdded': true,
              'memberRemoved': true,
              'chatMessage': true,
            },
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'fcmToken': fcmToken,
      'notificationSettings': notificationSettings,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? fcmToken,
    Map<String, bool>? notificationSettings,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    avatarUrl,
    createdAt,
    lastLoginAt,
    fcmToken,
    notificationSettings,
  ];
}
