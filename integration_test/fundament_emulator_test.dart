/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Ende-zu-Ende-Probe der App-Repositories gegen die lokale Emulator Suite
// (nie Produktion): Liste anlegen, Code-Vorschau, Beitritt, Regeln,
// Drosselung und Kontolöschung.
//
//   cd functions && npm run build && cd ..
//   firebase emulators:start --only auth,firestore,functions,storage --project togetherdo-c9179
//   flutter test integration_test/fundament_emulator_test.dart -d <Simulator> \
//     --dart-define=USE_FIREBASE_EMULATOR=true

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:togetherdo/firebase_options.dart';
import 'package:togetherdo/models/list_model.dart';
import 'package:togetherdo/models/list_preview.dart';
import 'package:togetherdo/repositories/auth_repository.dart';
import 'package:togetherdo/repositories/list_repository.dart';
import 'package:togetherdo/repositories/todo_repository.dart';
import 'package:togetherdo/services/firebase_emulator.dart';

final _random = Random();

class _TestUser {
  final String uid;
  final String email;
  final String password;
  final String name;

  _TestUser(this.uid, this.email, this.password, this.name);
}

/// Legt ein Konto nur im Auth-Emulator an (ohne FCM-Token) und meldet es an.
Future<_TestUser> _newUser(String name) async {
  final suffix = _random.nextInt(1 << 32).toRadixString(16);
  final email = '${name.toLowerCase()}-$suffix@example.test';
  final password = 'emu-$suffix-${_random.nextInt(1 << 32)}';
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  final uid = cred.user!.uid;
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'id': uid,
    'email': email,
    'displayName': name,
    'createdAt': DateTime.now().toIso8601String(),
    'lastLoginAt': DateTime.now().toIso8601String(),
  });
  return _TestUser(uid, email, password, name);
}

Future<void> _signIn(_TestUser user) async {
  await FirebaseAuth.instance.signOut();
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: user.email,
    password: user.password,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(
      useFirebaseEmulator,
      isTrue,
      reason: 'Nur mit --dart-define=USE_FIREBASE_EMULATOR=true ausführen',
    );
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await connectToFirebaseEmulator();
  });

  testWidgets('Liste anlegen, per Code beitreten, Regeln greifen', (
    tester,
  ) async {
    final lists = FirebaseListRepository();
    final todos = FirebaseTodoRepository();

    final olga = await _newUser('Olga');
    final list = await lists.createList(
      name: 'WG-Haushalt',
      ownerId: olga.uid,
      ownerName: 'Olga',
      type: ListType.todo,
    );
    expect(list.shareCode, matches(RegExp(r'^\d{6}$')));
    await todos.addTodo(
      title: 'Müll raus',
      description: '',
      userId: olga.uid,
      listId: list.id,
    );

    final max = await _newUser('Max');
    // Vor dem Beitritt: Liste und Todos sind gesperrt.
    await expectLater(
      FirebaseFirestore.instance.collection('lists').doc(list.id).get(),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      FirebaseFirestore.instance
          .collection('lists')
          .where('shareCode', isEqualTo: list.shareCode)
          .get(),
      throwsA(isA<FirebaseException>()),
    );

    final preview = await lists.previewListByCode(list.shareCode!);
    expect(preview.name, 'WG-Haushalt');
    expect(preview.ownerName, 'Olga');
    expect(preview.memberCount, 1);

    final joined = await lists.joinListByCode(
      code: list.shareCode!,
      userName: 'Max',
    );
    expect(joined.memberIds, [max.uid]);
    expect(joined.memberNames, ['Max']);

    // Nach dem Beitritt: Liste und Todos sichtbar.
    final myLists = await lists.getUserLists(max.uid);
    expect(myLists.map((l) => l.id), contains(list.id));
    final listTodos = await todos.getTodosStream(list.id).first;
    expect(listTodos.single.title, 'Müll raus');

    // Zweiter Beitritt wird abgelehnt.
    await expectLater(
      lists.joinListByCode(code: list.shareCode!, userName: 'Max'),
      throwsA(
        isA<ListCodeException>().having(
          (e) => e.error,
          'error',
          ListCodeError.alreadyMember,
        ),
      ),
    );

    // Austreten über das Repository (Regel „nur sich selbst austragen“).
    await lists.leaveList(list.id, max.uid);
    final afterLeave = await lists.getUserLists(max.uid);
    expect(afterLeave.map((l) => l.id), isNot(contains(list.id)));
  });

  testWidgets('Falsche Codes werden gedrosselt', (tester) async {
    final lists = FirebaseListRepository();
    await _newUser('Eve');
    var notFound = 0;
    ListCodeError? last;
    for (var i = 0; i < 11; i++) {
      try {
        await lists.previewListByCode(
          (100000 + _random.nextInt(899999)).toString(),
        );
      } on ListCodeException catch (e) {
        last = e.error;
        if (e.error == ListCodeError.notFound) notFound++;
      }
    }
    expect(notFound, greaterThanOrEqualTo(10));
    expect(last, ListCodeError.tooManyAttempts);
  });

  testWidgets('Kontolöschung über die App: Besitz geht über, Daten weg', (
    tester,
  ) async {
    final lists = FirebaseListRepository();
    final todos = FirebaseTodoRepository();
    final auth = FirebaseAuthRepository();

    final anna = await _newUser('Anna');
    final shared = await lists.createList(
      name: 'Familie',
      ownerId: anna.uid,
      ownerName: 'Anna',
      type: ListType.shopping,
    );
    final solo = await lists.createList(
      name: 'Privat',
      ownerId: anna.uid,
      ownerName: 'Anna',
      type: ListType.todo,
    );
    final soloTodo = await todos.addTodo(
      title: 'Geheim',
      description: '',
      userId: anna.uid,
      listId: solo.id,
    );

    final ben = await _newUser('Ben');
    await lists.joinListByCode(code: shared.shareCode!, userName: 'Ben');

    // Anna löscht ihr Konto (frisch angemeldet, wie nach dem Passwort-Dialog).
    await _signIn(anna);
    await auth.reauthenticate(password: anna.password);
    await auth.deleteAccount();
    expect(FirebaseAuth.instance.currentUser, isNull);

    // Anmelden mit Annas Daten geht nicht mehr.
    await expectLater(
      FirebaseAuth.instance.signInWithEmailAndPassword(
        email: anna.email,
        password: anna.password,
      ),
      throwsA(isA<FirebaseAuthException>()),
    );

    // Ben sieht die Familienliste jetzt als Besitzer, die private ist weg.
    await _signIn(ben);
    final familie = await lists.getListById(shared.id);
    expect(familie, isNotNull);
    expect(familie!.ownerId, ben.uid);
    expect(familie.ownerName, 'Ben');
    expect(familie.memberIds, isEmpty);
    expect(await lists.getListById(solo.id), isNull);
    // Annas Profil ist gelöscht (Lesen eines fehlenden Dokuments ist erlaubt).
    final annaDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(anna.uid)
        .get();
    expect(annaDoc.exists, isFalse);
    expect(soloTodo.listId, solo.id);
  });
}
