import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GlobalNavigator {
  static final GlobalNavigator _instance = GlobalNavigator._internal();
  factory GlobalNavigator() => _instance;
  GlobalNavigator._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  GoRouter? _router;

  void setRouter(GoRouter router) {
    _router = router;
    debugPrint('🌐 Global Navigator Router gesetzt');
  }

  /// Navigation zu Chat-Nachrichten
  void navigateToChat(String todoId, String listId, String todoTitle) {
    debugPrint('🚀 Global Navigation zu Chat: Todo $todoId in Liste $listId');

    if (_router != null) {
      try {
        // Zuerst zur Todo-Liste navigieren
        debugPrint('📱 Navigiere zu Todo-Liste: /todo/$listId');
        _router!.push('/todo/$listId');

        // Kurze Verzögerung, dann zum Chat navigieren
        Future.delayed(const Duration(milliseconds: 500), () {
          final chatUrl =
              '/chat/$todoId?title=${Uri.encodeComponent(todoTitle)}';
          debugPrint('💬 Navigiere zu Chat: $chatUrl');
          _router!.push(chatUrl);
        });
      } catch (e) {
        debugPrint('❌ Fehler bei Global Navigation: $e');
      }
    } else {
      debugPrint('❌ Router ist null');
    }
  }

  /// Navigation zu Todo-Items
  void navigateToTodo(String todoId, String listId) {
    debugPrint('🚀 Global Navigation zu Todo: $todoId in Liste $listId');

    if (_router != null) {
      try {
        debugPrint('📱 Navigiere zu Todo-Liste: /todo/$listId');
        _router!.push('/todo/$listId');
      } catch (e) {
        debugPrint('❌ Fehler bei Global Navigation: $e');
      }
    } else {
      debugPrint('❌ Router ist null');
    }
  }

  /// Navigation zu Listen
  void navigateToList(String listId) {
    debugPrint('🚀 Global Navigation zu Liste: $listId');

    if (_router != null) {
      try {
        debugPrint('📱 Navigiere zu Liste: /todo/$listId');
        _router!.push('/todo/$listId');
      } catch (e) {
        debugPrint('❌ Fehler bei Global Navigation: $e');
      }
    } else {
      debugPrint('❌ Router ist null');
    }
  }

  /// Navigation zu Einkaufslisten
  void navigateToShoppingList(String listId, [String? itemId]) {
    debugPrint('🚀 Global Navigation zu Einkaufsliste: $listId, Item: $itemId');

    if (_router != null) {
      try {
        String url = '/shopping/$listId';
        if (itemId != null) {
          url += '?highlight=$itemId';
        }
        debugPrint('🛒 Navigiere zu Einkaufsliste: $url');
        _router!.push(url);
      } catch (e) {
        debugPrint('❌ Fehler bei Global Navigation: $e');
      }
    } else {
      debugPrint('❌ Router ist null');
    }
  }
}
