import 'package:equatable/equatable.dart';
import '../../models/notification_settings_model.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class NotificationLoadRequested extends NotificationEvent {
  const NotificationLoadRequested();
}

class NotificationSettingsChanged extends NotificationEvent {
  final NotificationSettings settings;

  const NotificationSettingsChanged(this.settings);

  @override
  List<Object?> get props => [settings];
}
