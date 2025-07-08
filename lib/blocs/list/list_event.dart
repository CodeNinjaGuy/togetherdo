import 'package:equatable/equatable.dart';
import '../../models/list_model.dart';

abstract class ListEvent extends Equatable {
  const ListEvent();

  @override
  List<Object?> get props => [];
}

class ListLoadRequested extends ListEvent {
  final String userId;

  const ListLoadRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class ListCreateRequested extends ListEvent {
  final String name;
  final String ownerId;
  final String ownerName;
  final ListType type;
  final bool allowEdit;

  const ListCreateRequested({
    required this.name,
    required this.ownerId,
    required this.ownerName,
    required this.type,
    this.allowEdit = true,
  });

  @override
  List<Object?> get props => [name, ownerId, ownerName, type, allowEdit];
}

class ListUpdateRequested extends ListEvent {
  final ListModel list;

  const ListUpdateRequested({required this.list});

  @override
  List<Object?> get props => [list];
}

class ListDeleteRequested extends ListEvent {
  final String listId;
  final String ownerId;

  const ListDeleteRequested({required this.listId, required this.ownerId});

  @override
  List<Object?> get props => [listId, ownerId];
}

class ListCodeCheckRequested extends ListEvent {
  final String code;

  const ListCodeCheckRequested({required this.code});

  @override
  List<Object?> get props => [code];
}

class ListJoinRequested extends ListEvent {
  final String code;
  final String userId;
  final String userName;

  const ListJoinRequested({
    required this.code,
    required this.userId,
    required this.userName,
  });

  @override
  List<Object?> get props => [code, userId, userName];
}

class ListLeaveRequested extends ListEvent {
  final String listId;
  final String userId;

  const ListLeaveRequested({required this.listId, required this.userId});

  @override
  List<Object?> get props => [listId, userId];
}
