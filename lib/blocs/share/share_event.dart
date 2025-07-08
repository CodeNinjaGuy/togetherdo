import 'package:equatable/equatable.dart';
import '../../models/share_model.dart';

abstract class ShareEvent extends Equatable {
  const ShareEvent();

  @override
  List<Object?> get props => [];
}

class ShareLoadRequested extends ShareEvent {
  final String userId;

  const ShareLoadRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class ShareCreateRequested extends ShareEvent {
  final String ownerId;
  final String ownerName;
  final ShareType type;
  final String listName;

  const ShareCreateRequested({
    required this.ownerId,
    required this.ownerName,
    required this.type,
    required this.listName,
  });

  @override
  List<Object?> get props => [ownerId, ownerName, type, listName];
}

class ShareJoinRequested extends ShareEvent {
  final String code;
  final String userId;
  final String userName;

  const ShareJoinRequested({
    required this.code,
    required this.userId,
    required this.userName,
  });

  @override
  List<Object?> get props => [code, userId, userName];
}

class ShareLeaveRequested extends ShareEvent {
  final String shareId;
  final String userId;

  const ShareLeaveRequested({required this.shareId, required this.userId});

  @override
  List<Object?> get props => [shareId, userId];
}

class ShareDeleteRequested extends ShareEvent {
  final String shareId;
  final String ownerId;

  const ShareDeleteRequested({required this.shareId, required this.ownerId});

  @override
  List<Object?> get props => [shareId, ownerId];
}

class ShareCodeCheckRequested extends ShareEvent {
  final String code;

  const ShareCodeCheckRequested({required this.code});

  @override
  List<Object?> get props => [code];
}
