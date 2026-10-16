/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:togetherdo/blocs/auth/auth_bloc.dart';
import 'package:togetherdo/blocs/auth/auth_event.dart';
import 'package:togetherdo/blocs/auth/auth_state.dart';
import 'package:togetherdo/blocs/language/language_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/models/user_model.dart';
import 'package:togetherdo/repositories/auth_repository.dart';
import 'package:togetherdo/services/avatar_service.dart';
import 'package:togetherdo/widgets/common/user_avatar.dart';
import 'package:togetherdo/widgets/profile/avatar_source_sheet.dart';
import 'package:togetherdo/widgets/profile/editable_profile_avatar.dart';

final _user = UserModel(
  id: 'u1',
  email: 'test@example.com',
  displayName: 'Martin Bundschuh',
  createdAt: DateTime(2026, 1, 1),
  lastLoginAt: DateTime(2026, 1, 1),
);

class _FakeAuthRepository extends MockAuthRepository {
  UserModel user;
  int uploads = 0;
  int removals = 0;

  _FakeAuthRepository(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  Future<String> uploadAvatar(Uint8List jpegBytes) async {
    uploads++;
    return 'https://example.invalid/avatars/u1.jpg?v=1';
  }

  @override
  Future<void> removeAvatar() async {
    removals++;
  }
}

class _FakeAvatarService extends AvatarService {
  final bool camera;
  final AvatarPickResult result;
  AvatarAction? lastAction;

  _FakeAvatarService({required this.camera, required this.result});

  @override
  Future<bool> canUseCamera() async => camera;

  @override
  Future<AvatarPickResult> pick(AvatarAction action) async {
    lastAction = action;
    return result;
  }
}

Widget _app(Widget child, {Locale locale = const Locale('en', 'US')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
    home: Scaffold(body: Center(child: child)),
  );
}

Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(200, 30, 30, 128));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('processAvatarBytes', () {
    test('schneidet quadratisch zu und verkleinert auf 512 px', () {
      final out = processAvatarBytes(_png(1200, 900))!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 512);
      expect(decoded.height, 512);
    });

    test('vergrößert kleine Bilder nicht', () {
      final out = processAvatarBytes(_png(300, 200))!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 200);
      expect(decoded.height, 200);
    });

    test('liefert null für Daten, die kein Bild sind', () {
      expect(processAvatarBytes(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });

  group('initialsFor', () {
    test('bildet Initialen', () {
      expect(initialsFor('Martin Bundschuh'), 'MB');
      expect(initialsFor('anna'), 'A');
      expect(initialsFor('  Eva  Maria  Huber '), 'EH');
      expect(initialsFor(''), '?');
    });
  });

  group('AvatarSourceSheet', () {
    testWidgets('zeigt alle Optionen mit Kamera und vorhandenem Bild', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const AvatarSourceSheet(canUseCamera: true, hasAvatar: true)),
      );
      expect(find.byKey(const ValueKey('avatar-option-camera')), findsOne);
      expect(find.byKey(const ValueKey('avatar-option-gallery')), findsOne);
      expect(find.byKey(const ValueKey('avatar-option-remove')), findsOne);
      expect(find.text('Take photo'), findsOne);
      expect(find.text('Choose from photos'), findsOne);
      expect(find.text('Remove profile picture'), findsOne);
    });

    testWidgets('blendet Kamera und Entfernen aus, wenn nicht möglich', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const AvatarSourceSheet(canUseCamera: false, hasAvatar: false)),
      );
      expect(find.byKey(const ValueKey('avatar-option-camera')), findsNothing);
      expect(find.byKey(const ValueKey('avatar-option-remove')), findsNothing);
      expect(find.byKey(const ValueKey('avatar-option-gallery')), findsOne);
    });

    testWidgets('deutsche Texte', (tester) async {
      await tester.pumpWidget(
        _app(
          const AvatarSourceSheet(canUseCamera: true, hasAvatar: true),
          locale: const Locale('de', 'DE'),
        ),
      );
      expect(find.text('Foto aufnehmen'), findsOne);
      expect(find.text('Aus Fotos wählen'), findsOne);
      expect(find.text('Profilbild entfernen'), findsOne);
    });

    testWidgets('liefert die gewählte Aktion zurück', (tester) async {
      AvatarAction? chosen;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                chosen = await showAvatarSourceSheet(
                  context,
                  canUseCamera: true,
                  hasAvatar: false,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar-option-camera')));
      await tester.pumpAndSettle();
      expect(chosen, AvatarAction.camera);
    });
  });

  group('UserAvatar', () {
    setUp(() {
      UserAvatarCache.instance.clear();
      UserAvatarCache.instance.loaderOverride = (_) async => null;
    });
    tearDown(() => UserAvatarCache.instance.loaderOverride = null);

    testWidgets('zeigt Initialen ohne Bild', (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(userId: 'x', name: 'Anna Berg')),
      );
      await tester.pump();
      expect(find.text('AB'), findsOne);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isNull);
    });

    testWidgets('lädt Bild-Adresse über den Cache nach', (tester) async {
      UserAvatarCache.instance.loaderOverride = (id) async =>
          'https://example.invalid/$id.jpg';
      await tester.pumpWidget(
        _app(const UserAvatar(userId: 'x', name: 'Anna Berg')),
      );
      await tester.pump();
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isA<NetworkImage>());
      // Initialen bleiben als Ersatz darunter erhalten.
      expect(find.text('AB'), findsOne);
      expect(UserAvatarCache.instance.peek('x'), contains('x.jpg'));
    });
  });

  group('EditableProfileAvatar', () {
    late _FakeAuthRepository repo;
    late AuthBloc bloc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = _FakeAuthRepository(_user);
    });

    Future<void> pumpAvatar(WidgetTester tester, AvatarService service) async {
      bloc = AuthBloc(
        authRepository: repo,
        languageBloc: LanguageBloc(authRepository: repo),
      );
      addTearDown(bloc.close);
      bloc.add(const AuthCheckRequested());
      await tester.runAsync(
        () => bloc.stream.firstWhere((s) => s is AuthAuthenticated),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: _app(
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => state is AuthAuthenticated
                  ? EditableProfileAvatar(
                      user: state.user,
                      avatarService: service,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Kamera-Knopf öffnet die Auswahl statt einer Meldung', (
      tester,
    ) async {
      final service = _FakeAvatarService(
        camera: false,
        result: const AvatarPickResult(AvatarPickStatus.cancelled),
      );
      await pumpAvatar(tester, service);
      await tester.tap(find.byKey(const ValueKey('avatar-camera-button')));
      await tester.pumpAndSettle();
      expect(find.byType(AvatarSourceSheet), findsOne);
      expect(find.byKey(const ValueKey('avatar-option-camera')), findsNothing);
      expect(find.byKey(const ValueKey('avatar-option-remove')), findsNothing);
    });

    testWidgets('Galerie-Bild wird hochgeladen', (tester) async {
      final service = _FakeAvatarService(
        camera: true,
        result: AvatarPickResult(
          AvatarPickStatus.picked,
          Uint8List.fromList([1, 2, 3]),
        ),
      );
      await pumpAvatar(tester, service);
      await tester.tap(find.byKey(const ValueKey('avatar-camera-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar-option-gallery')));
      await tester.pumpAndSettle();
      expect(service.lastAction, AvatarAction.gallery);
      expect(repo.uploads, 1);
      expect(bloc.state, isA<AuthAvatarUpdated>());
      expect(
        (bloc.state as AuthAuthenticated).user.avatarUrl,
        contains('u1.jpg'),
      );
      expect(find.text('Profile picture updated'), findsOne);
    });

    testWidgets('verweigerte Berechtigung zeigt freundlichen Hinweis', (
      tester,
    ) async {
      final service = _FakeAvatarService(
        camera: true,
        result: const AvatarPickResult(AvatarPickStatus.permissionDenied),
      );
      await pumpAvatar(tester, service);
      await tester.tap(find.byKey(const ValueKey('avatar-camera-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar-option-camera')));
      await tester.pumpAndSettle();
      expect(find.text('Allow access'), findsOne);
      expect(find.textContaining('camera'), findsWidgets);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.uploads, 0);
    });

    testWidgets('vorhandenes Bild kann entfernt werden', (tester) async {
      repo.user = _user.copyWith(avatarUrl: 'https://example.invalid/a.jpg');
      final service = _FakeAvatarService(
        camera: false,
        result: const AvatarPickResult(AvatarPickStatus.cancelled),
      );
      await pumpAvatar(tester, service);
      await tester.tap(find.byKey(const ValueKey('avatar-camera-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar-option-remove')));
      await tester.pumpAndSettle();
      expect(repo.removals, 1);
      expect((bloc.state as AuthAuthenticated).user.avatarUrl, isNull);
      expect(find.text('Profile picture removed'), findsOne);
    });
  });
}
