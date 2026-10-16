/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'functions_client.dart';

/// `true`, wenn die App mit `--dart-define=USE_FIREBASE_EMULATOR=true`
/// gebaut wurde. Verbindet Auth, Firestore, Storage und Functions
/// (Ports wie in `firebase.json`). In Release-Builds ohne diesen Schalter immer `false`.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Host der Emulator Suite (Android-Emulator erreicht den Mac über 10.0.2.2).
const String _emulatorHostOverride = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
);

Future<void> connectToFirebaseEmulator() async {
  final host = _emulatorHostOverride.isNotEmpty
      ? _emulatorHostOverride
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : 'localhost');
  debugPrint('Firebase Emulator aktiv: $host');
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  appFunctions.useFunctionsEmulator(host, 5001);
}
