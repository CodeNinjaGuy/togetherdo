import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      final chatMessage = prefs.getBool('notification_chat_message') ?? true;

      final settings = NotificationSettings(
        todoCreated: todoCreated,
        todoCompleted: todoCompleted,
        todoDeleted: todoDeleted,
        memberAdded: memberAdded,
        memberRemoved: memberRemoved,
        chatMessage: chatMessage,
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

      // Lokale Einstellungen speichern
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
      await prefs.setBool(
        'notification_chat_message',
        event.settings.chatMessage,
      );

      // Einstellungen in Firestore speichern (für Cloud Functions)
      await _saveSettingsToFirestore(event.settings);

      emit(NotificationLoadSuccess(event.settings));
    } catch (e) {
      emit(NotificationLoadFailure(e.toString()));
    }
  }

  // Neue Funktion: Einstellungen in Firestore speichern
  Future<void> _saveSettingsToFirestore(NotificationSettings settings) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'notificationSettings': {
                'todoCreated': settings.todoCreated,
                'todoCompleted': settings.todoCompleted,
                'todoDeleted': settings.todoDeleted,
                'memberAdded': settings.memberAdded,
                'memberRemoved': settings.memberRemoved,
                'chatMessage': settings.chatMessage,
              },
            });
        debugPrint('✅ Benachrichtigungseinstellungen in Firestore gespeichert');
      }
    } catch (e) {
      debugPrint(
        '❌ Fehler beim Speichern der Benachrichtigungseinstellungen in Firestore: $e',
      );
      // Fehler nicht weiterwerfen, da lokale Speicherung bereits funktioniert
    }
  }
}
