import 'package:equatable/equatable.dart';
import '../../models/notification_settings_model.dart';

abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoadSuccess extends NotificationState {
  final NotificationSettings settings;

  const NotificationLoadSuccess(this.settings);

  @override
  List<Object?> get props => [settings];
}

class NotificationLoadFailure extends NotificationState {
  final String error;

  const NotificationLoadFailure(this.error);

  @override
  List<Object?> get props => [error];
}
