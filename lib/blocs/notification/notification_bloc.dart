import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/notification_settings_model.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc() : super(NotificationInitial()) {
    on<NotificationLoadRequested>(_onNotificationLoadRequested);
    on<NotificationSettingsChanged>(_onNotificationSettingsChanged);
  }

  Future<void> _onNotificationLoadRequested(
    NotificationLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final todoCreated = prefs.getBool('notification_todo_created') ?? true;
      final todoCompleted =
          prefs.getBool('notification_todo_completed') ?? true;
      final todoDeleted = prefs.getBool('notification_todo_deleted') ?? true;
      final memberAdded = prefs.getBool('notification_member_added') ?? true;
      final memberRemoved =
          prefs.getBool('notification_member_removed') ?? true;

      final settings = NotificationSettings(
        todoCreated: todoCreated,
        todoCompleted: todoCompleted,
        todoDeleted: todoDeleted,
        memberAdded: memberAdded,
        memberRemoved: memberRemoved,
      );

      emit(NotificationLoadSuccess(settings));
    } catch (e) {
      emit(NotificationLoadFailure(e.toString()));
    }
  }

  Future<void> _onNotificationSettingsChanged(
    NotificationSettingsChanged event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        'notification_todo_created',
        event.settings.todoCreated,
      );
      await prefs.setBool(
        'notification_todo_completed',
        event.settings.todoCompleted,
      );
      await prefs.setBool(
        'notification_todo_deleted',
        event.settings.todoDeleted,
      );
      await prefs.setBool(
        'notification_member_added',
        event.settings.memberAdded,
      );
      await prefs.setBool(
        'notification_member_removed',
        event.settings.memberRemoved,
      );

      emit(NotificationLoadSuccess(event.settings));
    } catch (e) {
      emit(NotificationLoadFailure(e.toString()));
    }
  }
}
