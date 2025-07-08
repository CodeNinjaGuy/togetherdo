import 'package:equatable/equatable.dart';
import '../../models/list_model.dart';

abstract class ListState extends Equatable {
  const ListState();

  @override
  List<Object?> get props => [];
}

class ListInitial extends ListState {
  const ListInitial();
}

class ListLoading extends ListState {
  const ListLoading();
}

class ListLoadSuccess extends ListState {
  final List<ListModel> lists;

  const ListLoadSuccess({required this.lists});

  @override
  List<Object?> get props => [lists];
}

class ListLoadFailure extends ListState {
  final String message;

  const ListLoadFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ListCreateSuccess extends ListState {
  final ListModel list;

  const ListCreateSuccess({required this.list});

  @override
  List<Object?> get props => [list];
}

class ListCreateFailure extends ListState {
  final String message;

  const ListCreateFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ListUpdateSuccess extends ListState {
  final ListModel list;

  const ListUpdateSuccess({required this.list});

  @override
  List<Object?> get props => [list];
}

class ListUpdateFailure extends ListState {
  final String message;

  const ListUpdateFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ListDeleteSuccess extends ListState {
  final String listId;

  const ListDeleteSuccess({required this.listId});

  @override
  List<Object?> get props => [listId];
}

class ListDeleteFailure extends ListState {
  final String message;

  const ListDeleteFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ListCodeCheckSuccess extends ListState {
  final ListModel list;

  const ListCodeCheckSuccess({required this.list});

  @override
  List<Object?> get props => [list];
}

class ListCodeCheckFailure extends ListState {
  final String message;

  const ListCodeCheckFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ListJoinSuccess extends ListState {
  final ListModel list;

  const ListJoinSuccess({required this.list});

  @override
  List<Object?> get props => [list];
}

class ListJoinFailure extends ListState {
  final String message;

  const ListJoinFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ListLeaveSuccess extends ListState {
  final String listId;

  const ListLeaveSuccess({required this.listId});

  @override
  List<Object?> get props => [listId];
}

class ListLeaveFailure extends ListState {
  final String message;

  const ListLeaveFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
