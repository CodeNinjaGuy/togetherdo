import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationHelper {
  static final NavigationHelper _instance = NavigationHelper._internal();
  factory NavigationHelper() => _instance;
  NavigationHelper._internal();

  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Navigation zu Chat-Nachrichten
  void navigateToChat(String todoId, String listId, String todoTitle) {
    debugPrint('🚀 Navigation zu Chat: Todo $todoId in Liste $listId');

    if (_navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;
      final router = GoRouter.of(context);

      try {
        // Zuerst zur Todo-Liste navigieren
        debugPrint('📱 Navigiere zu Todo-Liste: /todo/$listId');
        router.push('/todo/$listId');

        // Kurze Verzögerung, dann zum Chat navigieren
        Future.delayed(const Duration(milliseconds: 300), () {
          final chatUrl =
              '/chat/$todoId?title=${Uri.encodeComponent(todoTitle)}';
          debugPrint('💬 Navigiere zu Chat: $chatUrl');
          router.push(chatUrl);
        });
      } catch (e) {
        debugPrint('❌ Fehler bei Navigation: $e');
      }
    } else {
      debugPrint('❌ NavigatorKey ist null');
    }
  }

  /// Navigation zu Todo-Items
  void navigateToTodo(String todoId, String listId) {
    debugPrint('🚀 Navigation zu Todo: $todoId in Liste $listId');

    if (_navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;
      final router = GoRouter.of(context);

      try {
        debugPrint('📱 Navigiere zu Todo-Liste: /todo/$listId');
        router.push('/todo/$listId');
      } catch (e) {
        debugPrint('❌ Fehler bei Navigation: $e');
      }
    } else {
      debugPrint('❌ NavigatorKey ist null');
    }
  }

  /// Navigation zu Listen
  void navigateToList(String listId) {
    debugPrint('🚀 Navigation zu Liste: $listId');

    if (_navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;
      final router = GoRouter.of(context);

      try {
        debugPrint('📱 Navigiere zu Liste: /todo/$listId');
        router.push('/todo/$listId');
      } catch (e) {
        debugPrint('❌ Fehler bei Navigation: $e');
      }
    } else {
      debugPrint('❌ NavigatorKey ist null');
    }
  }
}
