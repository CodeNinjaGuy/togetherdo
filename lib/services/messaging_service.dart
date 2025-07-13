import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _isInitialized = false;

  // Getter für den FCM Token
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Initialisiert das Messaging System
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Firebase Messaging Berechtigungen anfordern
      await _requestPermissions();

      // FCM Token abrufen und speichern
      await _getAndSaveFCMToken();

      // Lokale Benachrichtigungen initialisieren
      await _initializeLocalNotifications();

      // Message Handler für Vordergrund-Nachrichten
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Message Handler für Hintergrund-Nachrichten (wenn App geöffnet wird)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Initial Message Handler (wenn App durch Benachrichtigung gestartet wird)
      RemoteMessage? initialMessage = await _firebaseMessaging
          .getInitialMessage();
      if (initialMessage != null) {
        _handleInitialMessage(initialMessage);
      }

      _isInitialized = true;
      debugPrint('Messaging Service erfolgreich initialisiert');
    } catch (e) {
      debugPrint('Fehler beim Initialisieren des Messaging Service: $e');
    }
  }

  /// Berechtigungen für Push-Benachrichtigungen anfordern
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
      'Benachrichtigungsberechtigung: ${settings.authorizationStatus}',
    );
  }

  /// FCM Token abrufen und speichern
  Future<void> _getAndSaveFCMToken() async {
    try {
      // Auf macOS versuchen wir den APNS Token zu bekommen, aber fahren auch ohne fort
      if (Platform.isMacOS) {
        debugPrint('Versuche APNS Token abzurufen...');
        try {
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            debugPrint('APNS Token erfolgreich abgerufen: $apnsToken');
          } else {
            debugPrint('APNS Token nicht verfügbar, fahre ohne fort');
          }
        } catch (e) {
          debugPrint('APNS Token Fehler (ignoriert): $e');
        }
      }

      // FCM Token abrufen (auch ohne APNS Token möglich)
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        await _saveFCMToken(_fcmToken!);
        await _saveFCMTokenToFirestore(_fcmToken!);
        debugPrint('FCM Token erfolgreich abgerufen: $_fcmToken');
      } else {
        debugPrint('FCM Token konnte nicht abgerufen werden');
      }
    } catch (e) {
      debugPrint('Fehler beim Abrufen des FCM Tokens: $e');
      // Auf macOS können wir auch ohne FCM Token fortfahren
      if (Platform.isMacOS) {
        debugPrint('Fahre ohne FCM Token fort (macOS Debug-Modus)');
      }
    }

    // Token Refresh Listener
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      await _saveFCMToken(newToken);
      await _saveFCMTokenToFirestore(newToken);
      debugPrint('FCM Token aktualisiert: $newToken');
    });
  }

  /// FCM Token in SharedPreferences speichern
  Future<void> _saveFCMToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// FCM Token aus SharedPreferences abrufen
  Future<String?> getStoredFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// FCM Token in Firestore speichern
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(auth.currentUser!.uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('Fehler beim Speichern des FCM Tokens in Firestore: $e');
    }
  }

  /// Lokale Benachrichtigungen initialisieren
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const DarwinInitializationSettings initializationSettingsMacOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
          macOS: initializationSettingsMacOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Vordergrund-Nachrichten behandeln
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      'Vordergrund-Nachricht erhalten: ${message.notification?.title}',
    );

    // Lokale Benachrichtigung anzeigen
    _showLocalNotification(message);
  }

  /// Hintergrund-Nachrichten behandeln (wenn App geöffnet wird)
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint(
      'Hintergrund-Nachricht erhalten: ${message.notification?.title}',
    );
    // Hier können Sie zur entsprechenden Seite navigieren
  }

  /// Initial-Nachrichten behandeln (wenn App durch Benachrichtigung gestartet wird)
  void _handleInitialMessage(RemoteMessage message) {
    debugPrint('Initial-Nachricht erhalten: ${message.notification?.title}');
    // Hier können Sie zur entsprechenden Seite navigieren
  }

  /// Lokale Benachrichtigung anzeigen
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'togetherdo_channel',
        'TogetherDo Benachrichtigungen',
        channelDescription: 'Benachrichtigungen für TogetherDo App',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Neue Nachricht',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  /// Benachrichtigungstap behandeln
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Benachrichtigung getappt: ${response.payload}');
    // Hier können Sie zur entsprechenden Seite navigieren
  }

  /// Lokale Benachrichtigung für Todo-Fälligkeitsdatum
  Future<void> showTodoDueNotification({
    required String todoId,
    required String title,
    required String body,
  }) async {
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_due_channel',
        'Todo Fälligkeitsdaten',
        channelDescription: 'Benachrichtigungen für fällige Todos',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
    );

    await _localNotifications.show(
      todoId.hashCode,
      title,
      body,
      platformChannelSpecifics,
      payload: todoId,
    );
  }

  /// Alle Benachrichtigungen löschen
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Spezifische Benachrichtigung löschen
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Debug-Funktion: Zeige Sound-Konfiguration
  void debugSoundConfiguration() {
    debugPrint('🔊 Sound-Konfiguration Debug:');
    debugPrint('📱 Plattform: ${Platform.operatingSystem}');

    if (Platform.isAndroid) {
      debugPrint('🤖 Android: Custom Sound (notification_sound.mp3)');
      debugPrint(
        '📁 Sound-Datei: android/app/src/main/res/raw/notification_sound.mp3',
      );
    } else if (Platform.isIOS) {
      debugPrint('🍎 iOS: Custom Sound (notification_sound.caf)');
      debugPrint('📁 Sound-Datei: assets/sounds/notification_sound.caf');
    } else if (Platform.isMacOS) {
      debugPrint('🖥️ macOS: Custom Sound (notification_sound.caf)');
      debugPrint('📁 Sound-Datei: assets/sounds/notification_sound.caf');
    } else {
      debugPrint('🌐 Web: Standard-Sound');
    }
  }

  /// Test-Benachrichtigung mit benutzerdefiniertem Sound senden
  Future<void> sendTestNotification() async {
    debugSoundConfiguration();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test Benachrichtigungen',
        channelDescription: 'Test-Benachrichtigungen für TogetherDo App',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
    );

    await _localNotifications.show(
      999,
      '🎉 Test erfolgreich!',
      'Deine Push-Benachrichtigungen funktionieren!',
      platformChannelSpecifics,
    );
  }

  /// Lokale Benachrichtigung für Cloud Events senden (falls FCM nicht verfügbar)
  Future<void> sendLocalNotificationForEvent({
    required String title,
    required String body,
    String? payload,
  }) async {
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'cloud_events_channel',
        'Cloud Events Benachrichtigungen',
        channelDescription: 'Benachrichtigungen für Cloud Events',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Benachrichtigung mit benutzerdefiniertem Sound senden
  Future<void> sendCustomSoundNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'custom_sound_channel',
        'Benutzerdefinierte Sounds',
        channelDescription: 'Benachrichtigungen mit benutzerdefinierten Sounds',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.caf',
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Neue Funktion: Benachrichtigungseinstellungen aus SharedPreferences abrufen
  Future<Map<String, bool>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'todoCreated': prefs.getBool('notification_todo_created') ?? true,
      'todoCompleted': prefs.getBool('notification_todo_completed') ?? true,
      'todoDeleted': prefs.getBool('notification_todo_deleted') ?? true,
      'memberAdded': prefs.getBool('notification_member_added') ?? true,
      'memberRemoved': prefs.getBool('notification_member_removed') ?? true,
      'chatMessage': prefs.getBool('notification_chat_message') ?? true,
    };
  }

  /// Neue Funktion: Prüfen ob lokale Benachrichtigung basierend auf Einstellungen angezeigt werden soll
  Future<bool> shouldShowLocalNotification(String notificationType) async {
    final settings = await getNotificationSettings();

    switch (notificationType) {
      case 'todo_created':
        return settings['todoCreated'] ?? true;
      case 'todo_completed':
        return settings['todoCompleted'] ?? true;
      case 'todo_deleted':
        return settings['todoDeleted'] ?? true;
      case 'member_added':
        return settings['memberAdded'] ?? true;
      case 'member_removed':
        return settings['memberRemoved'] ?? true;
      case 'chat_message':
        return settings['chatMessage'] ?? true;
      default:
        return true; // Fallback
    }
  }

  /// Neue Funktion: Plattformspezifisches Verhalten von Push-Benachrichtigungen
  String getPlatformNotificationBehavior() {
    if (Platform.isIOS) {
      return '''
📱 iOS Push-Benachrichtigungen:
• App im Vordergrund: Keine Push-Benachrichtigungen (nur lokale)
• App im Hintergrund: Push-Benachrichtigungen werden angezeigt
• App geschlossen: Push-Benachrichtigungen werden angezeigt

ℹ️ iOS zeigt keine Push-Benachrichtigungen an, wenn die App aktiv ist.
''';
    } else if (Platform.isMacOS) {
      return '''
🖥️ macOS Push-Benachrichtigungen:
• App im Vordergrund: Push-Benachrichtigungen werden angezeigt ✅
• App im Hintergrund: Push-Benachrichtigungen werden angezeigt
• App geschlossen: Push-Benachrichtigungen werden angezeigt

ℹ️ macOS zeigt Push-Benachrichtigungen auch bei aktiver App an.
''';
    } else if (Platform.isAndroid) {
      return '''
🤖 Android Push-Benachrichtigungen:
• App im Vordergrund: Push-Benachrichtigungen werden angezeigt ✅
• App im Hintergrund: Push-Benachrichtigungen werden angezeigt
• App geschlossen: Push-Benachrichtigungen werden angezeigt

ℹ️ Android zeigt Push-Benachrichtigungen immer an.
''';
    } else {
      return '''
🌐 Web Push-Benachrichtigungen:
• Browser aktiv: Push-Benachrichtigungen werden angezeigt ✅
• Browser im Hintergrund: Push-Benachrichtigungen werden angezeigt
• Browser geschlossen: Push-Benachrichtigungen werden angezeigt

ℹ️ Web zeigt Push-Benachrichtigungen immer an.
''';
    }
  }

  /// Neue Funktion: Prüfen ob Push-Benachrichtigungen im Vordergrund angezeigt werden
  bool shouldShowForegroundNotifications() {
    if (Platform.isIOS) {
      return false; // iOS zeigt keine Push-Benachrichtigungen im Vordergrund
    } else {
      return true; // macOS, Android, Web zeigen Push-Benachrichtigungen im Vordergrund
    }
  }
}
