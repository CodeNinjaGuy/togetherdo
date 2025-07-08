import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/todo_repository.dart';
import 'todo_event.dart';
import 'todo_state.dart';

class TodoBloc extends Bloc<TodoEvent, TodoState> {
  final TodoRepository _todoRepository;

  TodoBloc({required TodoRepository todoRepository})
    : _todoRepository = todoRepository,
      super(const TodoInitial()) {
    on<TodoLoadRequested>(_onTodoLoadRequested);
    on<TodoAddRequested>(_onTodoAddRequested);
    on<TodoUpdateRequested>(_onTodoUpdateRequested);
    on<TodoDeleteRequested>(_onTodoDeleteRequested);
    on<TodoToggleCompleteRequested>(_onTodoToggleCompleteRequested);
  }

  Future<void> _onTodoLoadRequested(
    TodoLoadRequested event,
    Emitter<TodoState> emit,
  ) async {
    emit(const TodoLoading());
    try {
      final todos = await _todoRepository.getTodos(event.userId);
      emit(TodoLoadSuccess(todos: todos));
    } catch (e) {
      emit(TodoLoadFailure(message: e.toString()));
    }
  }

  Future<void> _onTodoAddRequested(
    TodoAddRequested event,
    Emitter<TodoState> emit,
  ) async {
    try {
      final todo = await _todoRepository.addTodo(
        title: event.title,
        description: event.description,
        dueDate: event.dueDate,
        priority: event.priority,
        userId: event.userId,
        category: event.category,
        listId: event.listId,
        assignedToUserId: event.assignedToUserId,
        assignedToUserName: event.assignedToUserName,
      );
      emit(TodoAddSuccess(todo: todo));

      // Lade die aktualisierte Liste
      final todos = await _todoRepository.getTodos(event.userId);
      emit(TodoLoadSuccess(todos: todos));
    } catch (e) {
      emit(TodoAddFailure(message: e.toString()));
    }
  }

  Future<void> _onTodoUpdateRequested(
    TodoUpdateRequested event,
    Emitter<TodoState> emit,
  ) async {
    try {
      final todo = await _todoRepository.updateTodo(event.todo);
      emit(TodoUpdateSuccess(todo: todo));

      // Lade die aktualisierte Liste
      final todos = await _todoRepository.getTodos(event.todo.userId);
      emit(TodoLoadSuccess(todos: todos));
    } catch (e) {
      emit(TodoUpdateFailure(message: e.toString()));
    }
  }

  Future<void> _onTodoDeleteRequested(
    TodoDeleteRequested event,
    Emitter<TodoState> emit,
  ) async {
    try {
      await _todoRepository.deleteTodo(event.todoId);
      emit(TodoDeleteSuccess(todoId: event.todoId));

      // Lade die aktualisierte Liste
      final currentState = state;
      if (currentState is TodoLoadSuccess) {
        final updatedTodos = currentState.todos
            .where((todo) => todo.id != event.todoId)
            .toList();
        emit(TodoLoadSuccess(todos: updatedTodos));
      }
    } catch (e) {
      emit(TodoDeleteFailure(message: e.toString()));
    }
  }

  Future<void> _onTodoToggleCompleteRequested(
    TodoToggleCompleteRequested event,
    Emitter<TodoState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is TodoLoadSuccess) {
        final todo = currentState.todos.firstWhere((t) => t.id == event.todoId);
        final updatedTodo = todo.copyWith(
          isCompleted: event.isCompleted,
          completedByUserId: event.completedByUserId,
          completedByUserName: event.completedByUserName,
        );
        await _todoRepository.updateTodo(updatedTodo);

        final updatedTodos = currentState.todos.map((t) {
          return t.id == event.todoId ? updatedTodo : t;
        }).toList();
        emit(TodoLoadSuccess(todos: updatedTodos));
      }
    } catch (e) {
      emit(TodoUpdateFailure(message: e.toString()));
    }
  }
}
