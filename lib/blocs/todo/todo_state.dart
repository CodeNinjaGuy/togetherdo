import 'package:equatable/equatable.dart';
import '../../models/todo_model.dart';

abstract class TodoState extends Equatable {
  const TodoState();

  @override
  List<Object?> get props => [];
}

class TodoInitial extends TodoState {
  const TodoInitial();
}

class TodoLoading extends TodoState {
  const TodoLoading();
}

class TodoLoadSuccess extends TodoState {
  final List<TodoModel> todos;

  const TodoLoadSuccess({required this.todos});

  @override
  List<Object?> get props => [todos];
}

class TodoLoadFailure extends TodoState {
  final String message;

  const TodoLoadFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class TodoAddSuccess extends TodoState {
  final TodoModel todo;

  const TodoAddSuccess({required this.todo});

  @override
  List<Object?> get props => [todo];
}

class TodoAddFailure extends TodoState {
  final String message;

  const TodoAddFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class TodoUpdateSuccess extends TodoState {
  final TodoModel todo;

  const TodoUpdateSuccess({required this.todo});

  @override
  List<Object?> get props => [todo];
}

class TodoUpdateFailure extends TodoState {
  final String message;

  const TodoUpdateFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class TodoDeleteSuccess extends TodoState {
  final String todoId;

  const TodoDeleteSuccess({required this.todoId});

  @override
  List<Object?> get props => [todoId];
}

class TodoDeleteFailure extends TodoState {
  final String message;

  const TodoDeleteFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
