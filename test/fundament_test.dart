/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Tests für Stufe 1 „Fundament“: Code-Vorschau, Callable-Antworten,
// Passwort vergessen, rechtliche Links, Datenschutz-Text.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/config/legal_links.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/l10n/app_localizations_de.dart';
import 'package:togetherdo/l10n/app_localizations_en.dart';
import 'package:togetherdo/models/list_model.dart';
import 'package:togetherdo/models/list_preview.dart';
import 'package:togetherdo/repositories/auth_repository.dart';
import 'package:togetherdo/services/functions_client.dart';
import 'package:togetherdo/widgets/auth/forgot_password_dialog.dart';
import 'package:togetherdo/widgets/common/legal_links_row.dart';

class _RecordingAuthRepository extends MockAuthRepository {
  final List<String> resetEmails = [];
  Object? error;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmails.add(email);
    final e = error;
    if (e != null) throw e;
  }
}

Widget _app(
  Widget child, {
  required AuthRepository repo,
  Locale locale = const Locale('de', 'DE'),
}) {
  return RepositoryProvider<AuthRepository>.value(
    value: repo,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('Callable-Antworten', () {
    test('jsonMapFrom wandelt verschachtelte Maps und Listen um', () {
      final raw = <Object?, Object?>{
        'id': 'L1',
        'memberIds': <Object?>['a', 'b'],
        'nested': <Object?, Object?>{'x': 1},
      };
      final json = jsonMapFrom(raw);
      expect(json['memberIds'], ['a', 'b']);
      expect(json['nested'], isA<Map<String, dynamic>>());
      expect(jsonMapFrom(null), isEmpty);
    });

    test('ListModel aus createList-Antwort', () {
      final json = jsonMapFrom(<Object?, Object?>{
        'id': 'L1',
        'name': 'Haushalt',
        'ownerId': 'u1',
        'ownerName': 'Olga',
        'type': 'shopping',
        'createdAt': '2026-10-16T10:00:00.000Z',
        'updatedAt': '2026-10-16T10:00:00.000Z',
        'isShared': true,
        'shareCode': '123456',
        'memberIds': <Object?>[],
        'memberNames': <Object?>[],
        'allowEdit': true,
        'allUserIds': <Object?>['u1'],
      });
      final list = ListModel.fromJson(json);
      expect(list.type, ListType.shopping);
      expect(list.shareCode, '123456');
    });

    test('ListPreview liest die Vorschau ohne IDs', () {
      final preview = ListPreview.fromJson({
        'name': 'WG',
        'type': 'todo',
        'ownerName': 'Max',
        'memberCount': 3,
        'shareCode': '654321',
        'isMember': false,
      });
      expect(preview.name, 'WG');
      expect(preview.type, ListType.todo);
      expect(preview.memberCount, 3);
      expect(preview.shareCode, '654321');
    });
  });

  group('Datenschutz', () {
    test('Text behauptet nicht mehr, Chats würden nicht gespeichert', () {
      final de = AppLocalizationsDe();
      final en = AppLocalizationsEn();
      expect(de.privacySecurityStep1, contains('Chat-Nachrichten'));
      expect(de.privacySecurityStep1, contains('Firebase'));
      expect(de.privacySecurityStep1, isNot(contains('nicht dauerhaft')));
      expect(en.privacySecurityStep1, contains('chat messages'));
      expect(en.privacySecurityStep1, isNot(contains('not permanently')));
    });

    test('Links zeigen auf die SeeBubble-Seiten', () {
      expect(
        LegalLinks.privacyPolicy.toString(),
        'https://seebubble.me/datenschutz.html',
      );
      expect(
        LegalLinks.imprint.toString(),
        'https://seebubble.me/impressum.html',
      );
    });

    testWidgets('LegalLinksRow zeigt beide Links', (tester) async {
      await tester.pumpWidget(
        _app(const LegalLinksRow(), repo: _RecordingAuthRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Datenschutzerklärung'), findsOneWidget);
      expect(find.text('Impressum'), findsOneWidget);
    });
  });

  group('Passwort vergessen', () {
    testWidgets('schickt Link an die eingegebene Adresse', (tester) async {
      final repo = _RecordingAuthRepository();
      await tester.pumpWidget(
        _app(
          const ForgotPasswordDialog(initialEmail: 'max@example.test'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Passwort zurücksetzen'), findsOneWidget);
      await tester.tap(find.text('Link senden'));
      await tester.pumpAndSettle();
      expect(repo.resetEmails, ['max@example.test']);
      expect(find.textContaining('Falls ein Konto'), findsOneWidget);
    });

    testWidgets('prüft die Eingabe vor dem Senden', (tester) async {
      final repo = _RecordingAuthRepository();
      await tester.pumpWidget(_app(const ForgotPasswordDialog(), repo: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link senden'));
      await tester.pumpAndSettle();
      expect(repo.resetEmails, isEmpty);
      expect(find.text('E-Mail ist erforderlich'), findsOneWidget);
    });

    testWidgets('zeigt Fehler, wenn der Versand scheitert', (tester) async {
      final repo = _RecordingAuthRepository()..error = Exception('offline');
      await tester.pumpWidget(
        _app(
          const ForgotPasswordDialog(initialEmail: 'max@example.test'),
          repo: repo,
          locale: const Locale('en', 'US'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();
      expect(
        find.text('The link could not be sent. Please try again later.'),
        findsOneWidget,
      );
    });
  });
}
