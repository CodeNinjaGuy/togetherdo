/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Ende-zu-Ende-Probe des Profilbilds gegen die lokale Firebase Emulator Suite.
// Läuft NUR gegen Emulatoren, nie gegen Produktion:
//
//   firebase emulators:start --only auth,firestore,storage --project togetherdo-c9179
//   flutter test integration_test/avatar_emulator_test.dart -d <Simulator> \
//     --dart-define=USE_FIREBASE_EMULATOR=true
//
// Zeilen „SCREENSHOT:<name>“ in der Ausgabe markieren Haltepunkte, an denen
// ein externes Skript Bildschirmfotos aufnehmen kann.

import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:togetherdo/blocs/auth/auth_bloc.dart';
import 'package:togetherdo/blocs/auth/auth_event.dart';
import 'package:togetherdo/blocs/auth/auth_state.dart';
import 'package:togetherdo/firebase_options.dart';
import 'package:togetherdo/main.dart';
import 'package:togetherdo/repositories/auth_repository.dart';
import 'package:togetherdo/repositories/chat_repository.dart';
import 'package:togetherdo/repositories/list_repository.dart';
import 'package:togetherdo/repositories/shopping_repository.dart';
import 'package:togetherdo/repositories/todo_repository.dart';
import 'package:togetherdo/services/avatar_service.dart';
import 'package:togetherdo/services/firebase_emulator.dart';

Future<void> _hold(WidgetTester tester, String name) async {
  // ignore: avoid_print
  print('SCREENSHOT:$name');
  final end = DateTime.now().add(const Duration(seconds: 4));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Zeitüberschreitung beim Warten');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Uint8List _samplePhoto() {
  // Querformat-Testbild mit Verlauf, damit der Mittel-Zuschnitt sichtbar ist.
  final image = img.Image(width: 1200, height: 800);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgb(x, y, (x * 255) ~/ 1200, 120, (y * 255) ~/ 800);
    }
  }
  img.fillCircle(
    image,
    x: 600,
    y: 400,
    radius: 250,
    color: img.ColorRgb8(255, 210, 0),
  );
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Profilbild: Auswahl, Upload, Entfernen, Kontolöschung', (
    tester,
  ) async {
    expect(
      useFirebaseEmulator,
      isTrue,
      reason: 'Nur mit --dart-define=USE_FIREBASE_EMULATOR=true ausführen',
    );
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await connectToFirebaseEmulator();

    // Einmaliges Testkonto, existiert nur im lokalen Auth-Emulator.
    final suffix = Random().nextInt(1 << 32).toRadixString(16);
    final repo = FirebaseAuthRepository();
    await repo.signUp(
      email: 'avatar-$suffix@example.test',
      password: 'emu-$suffix-${Random().nextInt(1 << 32)}',
      displayName: 'Erika Musterfrau',
    );
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>(create: (_) => repo),
          RepositoryProvider<TodoRepository>(
            create: (_) => FirebaseTodoRepository(),
          ),
          RepositoryProvider<ShoppingRepository>(
            create: (_) => FirebaseShoppingRepository(),
          ),
          RepositoryProvider<ListRepository>(
            create: (_) => FirebaseListRepository(),
          ),
          RepositoryProvider<ChatRepository>(
            create: (_) => FirestoreChatRepository(),
          ),
        ],
        child: const TogetherDoApp(),
      ),
    );
    await _waitFor(
      tester,
      () => find.byIcon(Icons.person_outline).evaluate().isNotEmpty,
    );
    await tester.tap(find.byIcon(Icons.person_outline).last);
    await _waitFor(
      tester,
      () => find
          .byKey(const ValueKey('avatar-camera-button'))
          .evaluate()
          .isNotEmpty,
    );
    await _hold(tester, '01-profil-ohne-bild');

    // 1) Kamera-Knopf öffnet die Auswahl (kein Fehler, keine Meldung).
    await tester.tap(find.byKey(const ValueKey('avatar-camera-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar-option-gallery')), findsOne);
    // Kamera-Option erscheint nur, wenn das Gerät eine Kamera meldet.
    final hasCamera = await const DeviceCapabilities().hasCamera();
    expect(
      find.byKey(const ValueKey('avatar-option-camera')),
      hasCamera ? findsOne : findsNothing,
    );
    // ignore: avoid_print
    print('Kamera gemeldet: $hasCamera');
    await _hold(tester, '02-auswahl-ohne-bild');
    await tester.tap(find.byKey(const ValueKey('avatar-option-cancel')));
    await tester.pumpAndSettle();

    // 2) Upload eines aufbereiteten Bildes in den Storage-Emulator.
    final bloc = tester
        .element(find.byKey(const ValueKey('avatar-camera-button')))
        .read<AuthBloc>();
    final jpeg = processAvatarBytes(_samplePhoto())!;
    bloc.add(AuthUploadAvatarRequested(jpegBytes: jpeg));
    await _waitFor(tester, () => bloc.state is AuthAvatarUpdated);
    final url = (bloc.state as AuthAuthenticated).user.avatarUrl!;
    expect(url, contains('v='));
    final meta = await FirebaseStorage.instance
        .ref('avatars/$uid.jpg')
        .getMetadata();
    expect(meta.contentType, 'image/jpeg');
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    expect(doc.data()!['avatarUrl'], url);
    await FirebaseAuth.instance.currentUser!.reload();
    expect(FirebaseAuth.instance.currentUser!.photoURL, url);
    await _hold(tester, '03-profil-mit-bild');

    // 3) Auswahl zeigt jetzt „Entfernen“.
    await tester.tap(find.byKey(const ValueKey('avatar-camera-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar-option-remove')), findsOne);
    await _hold(tester, '04-auswahl-mit-bild');
    await tester.tap(find.byKey(const ValueKey('avatar-option-remove')));
    await _waitFor(
      tester,
      () =>
          bloc.state is AuthAvatarUpdated &&
          (bloc.state as AuthAuthenticated).user.avatarUrl == null,
    );
    await expectLater(
      FirebaseStorage.instance.ref('avatars/$uid.jpg').getMetadata(),
      throwsA(isA<FirebaseException>()),
    );

    // Nativer Galerie-Pfad: Fotoauswahl des Systems öffnet sich.
    await tester.tap(find.byKey(const ValueKey('avatar-camera-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('avatar-option-gallery')));
    await _hold(tester, '05-fotoauswahl-ios');

    // 4) Fremdes Bild schreiben verbieten die Storage-Regeln.
    await expectLater(
      FirebaseStorage.instance
          .ref('avatars/someone-else.jpg')
          .putData(jpeg, SettableMetadata(contentType: 'image/jpeg')),
      throwsA(isA<FirebaseException>()),
    );

    // 5) Kontolöschung räumt das Profilbild mit ab.
    bloc.add(AuthUploadAvatarRequested(jpegBytes: jpeg));
    await _waitFor(
      tester,
      () =>
          bloc.state is AuthAvatarUpdated &&
          (bloc.state as AuthAuthenticated).user.avatarUrl != null,
    );
    await repo.deleteAccount();
    // Nach der Löschung ist niemand angemeldet; Lesen ist dann gesperrt,
    // daher mit einem frischen anonymen Testkonto prüfen.
    await FirebaseAuth.instance.signInAnonymously();
    await expectLater(
      FirebaseStorage.instance.ref('avatars/$uid.jpg').getMetadata(),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'object-not-found',
        ),
      ),
    );
    await FirebaseAuth.instance.currentUser?.delete();
  });
}
