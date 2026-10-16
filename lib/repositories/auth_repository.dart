/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> getCurrentUser();
  Future<UserModel> signIn({required String email, required String password});
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> signOut();
  Future<UserModel> updateProfile({
    required String displayName,
    String? avatarUrl,
  });
  Future<UserModel> updateLanguage({
    required String languageCode,
    required String countryCode,
  });

  /// Lädt ein fertig aufbereitetes JPEG als Profilbild hoch, setzt die
  /// Adresse im Nutzerprofil und in Firebase Auth und liefert sie zurück.
  Future<String> uploadAvatar(Uint8List jpegBytes);

  /// Entfernt das Profilbild (Datei, Profilfeld, Auth-photoURL).
  Future<void> removeAvatar();
  Future<Map<String, String>?> getUserLanguage();
  Future<void> deleteAccount();
  Future<void> reauthenticate({required String password}); // NEU
}

class MockAuthRepository implements AuthRepository {
  UserModel? _currentUser;

  @override
  Future<UserModel?> getCurrentUser() async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 500));
    return _currentUser;
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(seconds: 1));

    // Mock-Login-Logik
    if (email == 'test@example.com' && password == 'password') {
      _currentUser = UserModel(
        id: '1',
        email: email,
        displayName: 'Test User',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      return _currentUser!;
    } else {
      throw Exception('Ungültige Anmeldedaten');
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(seconds: 1));

    // Mock-Registrierungslogik
    _currentUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  @override
  Future<UserModel> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(seconds: 1));

    if (_currentUser == null) {
      throw Exception('Kein Benutzer angemeldet');
    }

    _currentUser = _currentUser!.copyWith(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    return _currentUser!;
  }

  @override
  Future<UserModel> updateLanguage({
    required String languageCode,
    required String countryCode,
  }) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(seconds: 1));

    if (_currentUser == null) {
      throw Exception('Kein Benutzer angemeldet');
    }

    _currentUser = _currentUser!.copyWith(
      languageCode: languageCode,
      countryCode: countryCode,
    );
    return _currentUser!;
  }

  @override
  Future<String> uploadAvatar(Uint8List jpegBytes) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(seconds: 2));

    // Mock-Avatar-Upload - gibt eine simulierte URL zurück
    final url =
        'https://example.com/avatars/${DateTime.now().millisecondsSinceEpoch}.jpg';
    _currentUser = _currentUser?.copyWith(avatarUrl: url);
    return url;
  }

  @override
  Future<void> removeAvatar() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = _currentUser?.copyWith(clearAvatarUrl: true);
  }

  @override
  Future<Map<String, String>?> getUserLanguage() async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(milliseconds: 500));

    if (_currentUser == null) return null;

    // Gibt die Spracheinstellungen des Benutzers zurück
    return {
      'languageCode': _currentUser!.languageCode ?? 'en',
      'countryCode': _currentUser!.countryCode ?? 'US',
    };
  }

  @override
  Future<void> deleteAccount() async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(seconds: 2));

    // Mock-Account-Löschung
    _currentUser = null;
  }

  @override
  Future<void> reauthenticate({required String password}) async {
    // Mock: immer erfolgreich
    await Future.delayed(const Duration(milliseconds: 500));
  }
}

class FirebaseAuthRepository implements AuthRepository {
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data()!);
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final doc = await _firestore.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) throw Exception('Benutzerprofil nicht gefunden');

    // FCM Token abrufen und aktualisieren
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      // FCM Token ist optional, fahre ohne fort
      debugPrint('FCM Token konnte nicht abgerufen werden: $e');
    }

    // Update lastLoginAt und FCM Token
    final updateData = {'lastLoginAt': DateTime.now().toIso8601String()};

    if (fcmToken != null) {
      updateData['fcmToken'] = fcmToken;
    }

    await doc.reference.update(updateData);

    return UserModel.fromJson({
      ...doc.data()!,
      'lastLoginAt': DateTime.now().toIso8601String(),
      if (fcmToken != null) 'fcmToken': fcmToken,
    });
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user!;
    final now = DateTime.now();

    // FCM Token abrufen
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      // FCM Token ist optional, fahre ohne fort
      debugPrint('FCM Token konnte nicht abgerufen werden: $e');
    }

    // Standard Notification Settings
    final notificationSettings = {
      'todoCreated': true,
      'todoCompleted': true,
      'todoDeleted': true,
      'memberAdded': true,
      'memberRemoved': true,
      'chatMessage': true,
    };

    final userModel = UserModel(
      id: user.uid,
      email: user.email!,
      displayName: displayName,
      createdAt: now,
      lastLoginAt: now,
      fcmToken: fcmToken,
      notificationSettings: notificationSettings,
    );

    await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
    await user.updateDisplayName(displayName);
    return userModel;
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Fehler beim Abmelden: $e');
      throw Exception('Fehler beim Abmelden: $e');
    }
  }

  @override
  Future<UserModel> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Benutzerprofil nicht gefunden');
    final data = doc.data()!;
    final updated = {
      ...data,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
    await docRef.update(updated);
    await user.updateDisplayName(displayName);
    if (avatarUrl != null) await user.updatePhotoURL(avatarUrl);
    return UserModel.fromJson(updated);
  }

  @override
  Future<UserModel> updateLanguage({
    required String languageCode,
    required String countryCode,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Benutzerprofil nicht gefunden');
    final data = doc.data()!;
    final updated = {
      ...data,
      'languageCode': languageCode,
      'countryCode': countryCode,
    };
    await docRef.update(updated);
    return UserModel.fromJson(updated);
  }

  /// Feste Ablage je Nutzer – ein neues Bild überschreibt das alte.
  static String avatarPath(String uid) => 'avatars/$uid.jpg';

  @override
  Future<String> uploadAvatar(Uint8List jpegBytes) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');
    final ref = _storage.ref(avatarPath(user.uid));
    final snapshot = await ref.putData(
      jpegBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );
    final downloadUrl = await snapshot.ref.getDownloadURL();
    // Gleicher Pfad, neues Bild: Versionsparameter, damit Bild-Caches
    // (App und Browser) die neue Datei laden.
    final version = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse(downloadUrl);
    final url = uri
        .replace(queryParameters: {...uri.queryParameters, 'v': '$version'})
        .toString();
    await _firestore.collection('users').doc(user.uid).set({
      'avatarUrl': url,
      'avatarUpdatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await user.updatePhotoURL(url);
    return url;
  }

  @override
  Future<void> removeAvatar() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');
    await _deleteAvatarFile(user.uid);
    await _firestore.collection('users').doc(user.uid).set({
      'avatarUrl': null,
      'avatarUpdatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await user.updatePhotoURL(null);
  }

  Future<void> _deleteAvatarFile(String uid) async {
    try {
      await _storage.ref(avatarPath(uid)).delete();
    } on FirebaseException catch (e) {
      // Kein Bild vorhanden ist kein Fehler.
      if (e.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<Map<String, String>?> getUserLanguage() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final languageCode = data['languageCode'] as String?;
    final countryCode = data['countryCode'] as String?;

    if (languageCode != null && countryCode != null) {
      return {'languageCode': languageCode, 'countryCode': countryCode};
    }

    return null;
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');

    try {
      // Schritt 1: Aus allen beigetretenen Listen austreten
      await _leaveAllJoinedLists(user.uid);

      // Schritt 2: Alle erstellten Listen löschen
      await _deleteAllCreatedLists(user.uid);

      // Schritt 3: Profilbild aus Firebase Storage löschen
      try {
        await _deleteAvatarFile(user.uid);
      } catch (e) {
        debugPrint('Profilbild konnte nicht gelöscht werden: $e');
      }

      // Schritt 4: Alle Benutzerdaten aus Firestore löschen
      await _firestore.collection('users').doc(user.uid).delete();

      // Schritt 5: Firebase Auth Account löschen (mit Re-Authentifizierung)
      await _deleteUserWithReAuth(user);
    } catch (e) {
      debugPrint('Fehler beim Löschen des Accounts: $e');
      throw Exception('Fehler beim Löschen des Accounts: $e');
    }
  }

  Future<void> _leaveAllJoinedLists(String userId) async {
    try {
      // Alle Listen abrufen, in denen der Benutzer Mitglied ist
      final listsQuery = await _firestore
          .collection('lists')
          .where('memberIds', arrayContains: userId)
          .get();

      // Aus allen Listen austreten
      for (final doc in listsQuery.docs) {
        final data = doc.data();
        final memberIds = List<String>.from(data['memberIds'] ?? []);
        final memberNames = List<String>.from(data['memberNames'] ?? []);

        // Benutzer aus der Liste entfernen
        memberIds.remove(userId);
        memberNames.removeWhere(
          (name) => name.contains(userId),
        ); // Vereinfachte Logik

        await doc.reference.update({
          'memberIds': memberIds,
          'memberNames': memberNames,
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Verlassen der Listen: $e');
      // Nicht abbrechen, weiter mit nächstem Schritt
    }
  }

  Future<void> _deleteAllCreatedLists(String userId) async {
    try {
      // Alle Listen abrufen, die der Benutzer erstellt hat
      final listsQuery = await _firestore
          .collection('lists')
          .where('ownerId', isEqualTo: userId)
          .get();

      // Alle erstellten Listen löschen
      for (final doc in listsQuery.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Fehler beim Löschen der erstellten Listen: $e');
      // Nicht abbrechen, weiter mit nächstem Schritt
    }
  }

  Future<void> _deleteUserWithReAuth(fb_auth.User user) async {
    try {
      // Versuche direkt zu löschen
      await user.delete();
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Re-Authentifizierung erforderlich
        throw Exception(
          'Re-Authentifizierung erforderlich. Bitte melde dich erneut an, um deinen Account zu löschen.',
        );
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> reauthenticate({required String password}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');
    final cred = fb_auth.EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    try {
      await user.reauthenticateWithCredential(cred);
    } on fb_auth.FirebaseAuthException catch (e) {
      throw Exception('Re-Authentifizierung fehlgeschlagen: ${e.message}');
    }
  }
}
