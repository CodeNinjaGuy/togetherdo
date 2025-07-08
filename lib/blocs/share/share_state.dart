import 'package:equatable/equatable.dart';
import '../../models/share_model.dart';

abstract class ShareState extends Equatable {
  const ShareState();

  @override
  List<Object?> get props => [];
}

class ShareInitial extends ShareState {
  const ShareInitial();
}

class ShareLoading extends ShareState {
  const ShareLoading();
}

class ShareLoadSuccess extends ShareState {
  final List<ShareModel> shares;

  const ShareLoadSuccess({required this.shares});

  @override
  List<Object?> get props => [shares];
}

class ShareLoadFailure extends ShareState {
  final String message;

  const ShareLoadFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShareCreateSuccess extends ShareState {
  final ShareModel share;

  const ShareCreateSuccess({required this.share});

  @override
  List<Object?> get props => [share];
}

class ShareCreateFailure extends ShareState {
  final String message;

  const ShareCreateFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShareJoinSuccess extends ShareState {
  final ShareModel share;

  const ShareJoinSuccess({required this.share});

  @override
  List<Object?> get props => [share];
}

class ShareJoinFailure extends ShareState {
  final String message;

  const ShareJoinFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShareLeaveSuccess extends ShareState {
  final String shareId;

  const ShareLeaveSuccess({required this.shareId});

  @override
  List<Object?> get props => [shareId];
}

class ShareLeaveFailure extends ShareState {
  final String message;

  const ShareLeaveFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShareDeleteSuccess extends ShareState {
  final String shareId;

  const ShareDeleteSuccess({required this.shareId});

  @override
  List<Object?> get props => [shareId];
}

class ShareDeleteFailure extends ShareState {
  final String message;

  const ShareDeleteFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ShareCodeCheckSuccess extends ShareState {
  final ShareModel share;

  const ShareCodeCheckSuccess({required this.share});

  @override
  List<Object?> get props => [share];
}

class ShareCodeCheckFailure extends ShareState {
  final String message;

  const ShareCodeCheckFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
