import '../models/todo_model.dart';
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
  });
  Future<TodoModel> updateTodo(TodoModel todo);
  Future<void> deleteTodo(String todoId);
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
}
