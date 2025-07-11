import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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
  Future<String> uploadAvatar(String imagePath);
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
  Future<String> uploadAvatar(String imagePath) async {
    // Simuliere eine Verzögerung
    await Future.delayed(const Duration(seconds: 2));

    // Mock-Avatar-Upload - gibt eine simulierte URL zurück
    return 'https://example.com/avatars/${DateTime.now().millisecondsSinceEpoch}.jpg';
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
    // Update lastLoginAt
    await doc.reference.update({
      'lastLoginAt': DateTime.now().toIso8601String(),
    });
    return UserModel.fromJson({
      ...doc.data()!,
      'lastLoginAt': DateTime.now().toIso8601String(),
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
    final userModel = UserModel(
      id: user.uid,
      email: user.email!,
      displayName: displayName,
      createdAt: now,
      lastLoginAt: now,
    );
    await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
    await user.updateDisplayName(displayName);
    return userModel;
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
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
  Future<String> uploadAvatar(String imagePath) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');
    final file = File(imagePath);
    final ref = _storage.ref().child(
      'avatars/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }
}
