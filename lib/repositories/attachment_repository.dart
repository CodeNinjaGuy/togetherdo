/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attachment_model.dart';

/// Beschreibungen der Anhänge einer Aufgabe (Firestore). Die Dateien
/// selbst verwaltet `AttachmentService` (Storage).
abstract class AttachmentRepository {
  Stream<List<AttachmentModel>> watch(String todoId);
  Future<void> add(AttachmentModel attachment);
  Future<void> remove(String todoId, String attachmentId);
}

class FirestoreAttachmentRepository implements AttachmentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String todoId) =>
      _firestore.collection('todos').doc(todoId).collection('attachments');

  @override
  Stream<List<AttachmentModel>> watch(String todoId) => _col(todoId)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => AttachmentModel.fromJson(d.data())).toList());

  @override
  Future<void> add(AttachmentModel attachment) =>
      _col(attachment.todoId).doc(attachment.id).set(attachment.toJson());

  @override
  Future<void> remove(String todoId, String attachmentId) =>
      _col(todoId).doc(attachmentId).delete();
}

/// Für Tests und Vorschau: alles im Speicher.
class MockAttachmentRepository implements AttachmentRepository {
  final Map<String, List<AttachmentModel>> _byTodo = {};
  final Map<String, StreamController<List<AttachmentModel>>> _controllers = {};

  StreamController<List<AttachmentModel>> _c(String todoId) =>
      _controllers.putIfAbsent(
        todoId,
        () => StreamController<List<AttachmentModel>>.broadcast(
          onListen: () => _emit(todoId),
        ),
      );

  void _emit(String todoId) =>
      _c(todoId).add(List.unmodifiable(_byTodo[todoId] ?? const []));

  @override
  Stream<List<AttachmentModel>> watch(String todoId) => _c(todoId).stream;

  @override
  Future<void> add(AttachmentModel attachment) async {
    (_byTodo[attachment.todoId] ??= []).add(attachment);
    _emit(attachment.todoId);
  }

  @override
  Future<void> remove(String todoId, String attachmentId) async {
    _byTodo[todoId]?.removeWhere((a) => a.id == attachmentId);
    _emit(todoId);
  }
}
