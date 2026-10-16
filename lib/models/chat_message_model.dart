/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  final String id;
  final String todoId;
  final String userId;
  final String userName;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  /// Bild im Chat: Pfad in Storage (`chats/{listId}/{todoId}/{id}`) und
  /// Vorschaubild (`…/{id}_vorschau.jpg`). Geladen wird über den
  /// `AttachmentService` (Storage-Regeln), nicht über eine offene Adresse.
  final String? imagePath;
  final String? imagePreviewPath;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  const ChatMessageModel({
    required this.id,
    required this.todoId,
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.imagePath,
    this.imagePreviewPath,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      todoId: json['todoId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      imagePath: json['imagePath'] as String?,
      imagePreviewPath: json['imagePreviewPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'todoId': todoId,
      'userId': userId,
      'userName': userName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      if (imagePath != null) 'imagePath': imagePath,
      if (imagePreviewPath != null) 'imagePreviewPath': imagePreviewPath,
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? todoId,
    String? userId,
    String? userName,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? imagePath,
    String? imagePreviewPath,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imagePath: imagePath ?? this.imagePath,
      imagePreviewPath: imagePreviewPath ?? this.imagePreviewPath,
    );
  }

  @override
  List<Object?> get props => [
    id,
    todoId,
    userId,
    userName,
    message,
    timestamp,
    isRead,
    imagePath,
    imagePreviewPath,
  ];
}
