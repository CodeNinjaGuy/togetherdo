/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:equatable/equatable.dart';

import 'todo_model.dart' show parseFirestoreDate;

/// Anhang an einer Aufgabe (Foto oder PDF). Die Datei liegt in Firebase
/// Storage unter [path] (`todos/{listId}/{todoId}/{datei}`), die
/// Beschreibung in Firestore unter `todos/{todoId}/attachments/{id}`.
class AttachmentModel extends Equatable {
  const AttachmentModel({
    required this.id,
    required this.todoId,
    required this.listId,
    required this.name,
    required this.path,
    required this.url,
    required this.contentType,
    required this.size,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.createdAt,
  });

  final String id;
  final String todoId;
  final String listId;

  /// Anzeigename, z. B. „Rechnung.pdf“.
  final String name;

  /// Pfad in Storage.
  final String path;

  /// Download-Adresse.
  final String url;
  final String contentType;

  /// Größe in Bytes.
  final int size;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime createdAt;

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] as String,
      todoId: json['todoId'] as String,
      listId: json['listId'] as String,
      name: json['name'] as String? ?? '',
      path: json['path'] as String,
      url: json['url'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      uploadedBy: json['uploadedBy'] as String,
      uploadedByName: json['uploadedByName'] as String? ?? '',
      createdAt: parseFirestoreDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'todoId': todoId,
    'listId': listId,
    'name': name,
    'path': path,
    'url': url,
    'contentType': contentType,
    'size': size,
    'uploadedBy': uploadedBy,
    'uploadedByName': uploadedByName,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    todoId,
    listId,
    name,
    path,
    url,
    contentType,
    size,
    uploadedBy,
    uploadedByName,
    createdAt,
  ];
}
