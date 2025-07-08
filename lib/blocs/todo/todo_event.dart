import 'package:equatable/equatable.dart';
import '../../models/todo_model.dart';

abstract class TodoEvent extends Equatable {
  const TodoEvent();

  @override
  List<Object?> get props => [];
}

class TodoLoadRequested extends TodoEvent {
  final String userId;
  final String listId;

  const TodoLoadRequested({required this.userId, required this.listId});

  @override
  List<Object?> get props => [userId, listId];
}

class TodoAddRequested extends TodoEvent {
  final String title;
  final String description;
  final DateTime? dueDate;
  final TodoPriority priority;
  final String userId;
  final String? category;
  final String listId;
  final String? assignedToUserId;
  final String? assignedToUserName;

  const TodoAddRequested({
    required this.title,
    required this.description,
    this.dueDate,
    this.priority = TodoPriority.medium,
    required this.userId,
    this.category,
    required this.listId,
    this.assignedToUserId,
    this.assignedToUserName,
  });

  @override
  List<Object?> get props => [
    title,
    description,
    dueDate,
    priority,
    userId,
    category,
    listId,
    assignedToUserId,
    assignedToUserName,
  ];
}

class TodoUpdateRequested extends TodoEvent {
  final TodoModel todo;

  const TodoUpdateRequested({required this.todo});

  @override
  List<Object?> get props => [todo];
}

class TodoDeleteRequested extends TodoEvent {
  final String todoId;

  const TodoDeleteRequested({required this.todoId});

  @override
  List<Object?> get props => [todoId];
}

class TodoToggleCompleteRequested extends TodoEvent {
  final String todoId;
  final bool isCompleted;
  final String? completedByUserId;
  final String? completedByUserName;

  const TodoToggleCompleteRequested({
    required this.todoId,
    required this.isCompleted,
    this.completedByUserId,
    this.completedByUserName,
  });

  @override
  List<Object?> get props => [
    todoId,
    isCompleted,
    completedByUserId,
    completedByUserName,
  ];
}
