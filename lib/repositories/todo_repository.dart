/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import '../models/todo_model.dart';
import '../utils/stream_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class TodoRepository {
  Future<List<TodoModel>> getTodos(String userId);
  Future<TodoModel> addTodo({
    required String title,
    required String description,
    DateTime? dueDate,
    TodoPriority priority,
    required String userId,
    String? category,
    required String listId,
    String? assignedToUserId,
    String? assignedToUserName,
    TaskEffort effort,
  });
  Future<TodoModel> updateTodo(TodoModel todo);
  Future<void> deleteTodo(String todoId);

  /// Abhaken bzw. wieder öffnen. Beim Abhaken setzt der Server die Zeit
  /// (`completedAt`); erledigt hat immer die angemeldete Person.
  Future<void> setCompleted({
    required String todoId,
    required bool completed,
    required String userId,
    String? userName,
  });
}

class MockTodoRepository implements TodoRepository {
  final List<TodoModel> _todos = [];

  @override
  Future<List<TodoModel>> getTodos(String userId) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 500));

    return _todos.where((todo) => todo.userId == userId).toList();
  }

  @override
  Future<TodoModel> addTodo({
    required String title,
    required String description,
    DateTime? dueDate,
    TodoPriority priority = TodoPriority.medium,
    required String userId,
    String? category,
    required String listId,
    String? assignedToUserId,
    String? assignedToUserName,
    TaskEffort effort = TaskEffort.medium,
  }) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 800));

    final todo = TodoModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      userId: userId,
      category: category,
      listId: listId,
      createdAt: DateTime.now(),
      assignedToUserId: assignedToUserId,
      assignedToUserName: assignedToUserName,
      effort: effort,
    );

    _todos.add(todo);
    return todo;
  }

  @override
  Future<TodoModel> updateTodo(TodoModel todo) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 600));

    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      _todos[index] = todo;
      return todo;
    } else {
      throw Exception('Todo nicht gefunden');
    }
  }

  @override
  Future<void> deleteTodo(String todoId) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 400));

    _todos.removeWhere((todo) => todo.id == todoId);
  }

  @override
  Future<void> setCompleted({
    required String todoId,
    required bool completed,
    required String userId,
    String? userName,
  }) async {
    final index = _todos.indexWhere((t) => t.id == todoId);
    if (index == -1) throw Exception('Todo nicht gefunden');
    final todo = _todos[index];
    _todos[index] = completed
        ? todo.copyWith(
            isCompleted: true,
            completedByUserId: userId,
            completedByUserName: userName,
            completedAt: DateTime.now(),
          )
        : todo.copyWith(isCompleted: false, clearCompletion: true);
  }
}

class FirebaseTodoRepository implements TodoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<TodoModel>> getTodos(String userId) async {
    final query = await _firestore
        .collection('todos')
        .where('userId', isEqualTo: userId)
        .get();
    return query.docs.map((doc) => TodoModel.fromJson(doc.data())).toList();
  }

  Stream<List<TodoModel>> getTodosStream(String listId) {
    return _firestore
        .collection('todos')
        .where('listId', isEqualTo: listId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TodoModel.fromJson(doc.data()))
              .toList(),
        );
  }

  @override
  Future<TodoModel> addTodo({
    required String title,
    required String description,
    DateTime? dueDate,
    TodoPriority priority = TodoPriority.medium,
    required String userId,
    String? category,
    required String listId,
    String? assignedToUserId,
    String? assignedToUserName,
    TaskEffort effort = TaskEffort.medium,
  }) async {
    final docRef = _firestore.collection('todos').doc();
    final now = DateTime.now();
    final todo = TodoModel(
      id: docRef.id,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      userId: userId,
      category: category,
      listId: listId,
      createdAt: now,
      assignedToUserId: assignedToUserId,
      assignedToUserName: assignedToUserName,
      effort: effort,
    );
    await docRef.set(todo.toJson());
    return todo;
  }

  @override
  Future<TodoModel> updateTodo(TodoModel todo) async {
    final docRef = _firestore.collection('todos').doc(todo.id);
    await docRef.update(todo.toJson());
    return todo;
  }

  @override
  Future<void> deleteTodo(String todoId) async {
    final docRef = _firestore.collection('todos').doc(todoId);
    await docRef.delete();
  }

  @override
  Future<void> setCompleted({
    required String todoId,
    required bool completed,
    required String userId,
    String? userName,
  }) async {
    await _firestore
        .collection('todos')
        .doc(todoId)
        .update(
          completed
              ? {
                  'isCompleted': true,
                  'completedByUserId': userId,
                  'completedByUserName': userName,
                  'completedAt': FieldValue.serverTimestamp(),
                }
              : {
                  'isCompleted': false,
                  'completedByUserId': null,
                  'completedByUserName': null,
                  'completedAt': null,
                },
        );
  }

  /// Zuständigkeit und Aufwand ändern (ohne die übrigen Felder anzufassen).
  Future<void> updateAssignment({
    required String todoId,
    required String? assignedToUserId,
    required String? assignedToUserName,
    required TaskEffort effort,
  }) async {
    await _firestore.collection('todos').doc(todoId).update({
      'assignedToUserId': assignedToUserId,
      'assignedToUserName': assignedToUserName,
      'effort': effort.name,
    });
  }

  /// Alle Aufgaben mehrerer Listen (Startseite „Heute“). Firestore erlaubt
  /// höchstens 30 Werte je `whereIn`, deshalb in Blöcken.
  Stream<List<TodoModel>> todosForListsStream(List<String> listIds) {
    return combineLatestLists([
      for (final ids in chunked(listIds))
        _firestore
            .collection('todos')
            .where('listId', whereIn: ids)
            .snapshots()
            .map(
              (s) => s.docs.map((d) => TodoModel.fromJson(d.data())).toList(),
            ),
    ]);
  }

  /// Eine Aufgabe (z. B. für den Chat nach einer Push-Nachricht).
  Future<TodoModel?> getTodoById(String todoId) async {
    final doc = await _firestore.collection('todos').doc(todoId).get();
    final data = doc.data();
    return data == null ? null : TodoModel.fromJson(data);
  }

  /// Erledigte Aufgaben einer Liste seit [since] – Grundlage der
  /// Fairness-Statistik (begrenzter Zeitraum, Index listId + completedAt).
  Stream<List<TodoModel>> completedSinceStream(String listId, DateTime since) {
    return _firestore
        .collection('todos')
        .where('listId', isEqualTo: listId)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TodoModel.fromJson(doc.data()))
              .toList(),
        );
  }
}
