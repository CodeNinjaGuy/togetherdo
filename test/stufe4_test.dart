/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Stufe 4: Navigation, Anhänge, Startseite-Hilfen und Bausteine.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:togetherdo/design/td_design.dart';
import 'package:togetherdo/fairness/fairness.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/models/attachment_model.dart';
import 'package:togetherdo/models/chat_message_model.dart';
import 'package:togetherdo/models/list_model.dart';
import 'package:togetherdo/models/todo_model.dart';
import 'package:togetherdo/navigation/app_shell.dart';
import 'package:togetherdo/repositories/attachment_repository.dart';
import 'package:togetherdo/repositories/todo_repository.dart';
import 'package:togetherdo/services/aufgaben_anhang_service.dart';
import 'package:togetherdo/utils/app_theme.dart';
import 'package:togetherdo/utils/stream_utils.dart';
import 'package:togetherdo/widgets/common/user_avatar.dart';
import 'package:togetherdo/widgets/lists/list_visuals.dart';
import 'package:togetherdo/widgets/todo/task_editor_sheet.dart';

Widget _app(Widget child, {Locale locale = const Locale('de', 'DE')}) {
  return MaterialApp(
    theme: AppTheme.of('Light'),
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

ListModel _list({String id = 'L1', bool allowEdit = true}) => ListModel(
  id: id,
  name: 'Haushalt',
  ownerId: 'anna',
  ownerName: 'Anna',
  type: ListType.todo,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  memberIds: const ['ben'],
  memberNames: const ['Ben'],
  allowEdit: allowEdit,
);

void main() {
  setUpAll(() {
    UserAvatarCache.instance.loaderOverride = (_) async => null;
  });

  group('Navigation (AppShell)', () {
    test('Reiter aus der Route', () {
      expect(AppShell.tabFor('/'), ShellTab.today);
      expect(AppShell.tabFor('/lists'), ShellTab.lists);
      expect(AppShell.tabFor('/todo/abc'), ShellTab.lists);
      expect(AppShell.tabFor('/shopping/abc'), ShellTab.lists);
      expect(AppShell.tabFor('/kalender'), ShellTab.calendar);
      expect(AppShell.tabFor('/profile'), ShellTab.profile);
    });
    test('Route je Reiter und Listen-ID aus Detailroute', () {
      expect(AppShell.pathFor(ShellTab.calendar), '/kalender');
      expect(AppShell.isListDetail('/todo/x'), isTrue);
      expect(AppShell.isListDetail('/lists'), isFalse);
      expect(AppShell.listIdOf('/shopping/wg'), 'wg');
      expect(AppShell.listIdOf('/profile'), isNull);
    });
  });

  group('Theme', () {
    test('System und Dunkel sind bekannt', () {
      expect(AppTheme.isSystem('System'), isTrue);
      expect(AppTheme.of('Dark').brightness, Brightness.dark);
      expect(AppTheme.of('Unbekannt'), AppTheme.of('Light'));
    });
    test('Schriften sind gebündelt, Theme nutzt sie', () {
      expect(TdTypography.bundledFamilies, contains('Manrope'));
      expect(TdTypography.bundledFamilies, contains('Nunito'));
      final theme = AppTheme.of('Light');
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Manrope');
      expect(theme.textTheme.headlineLarge?.fontFamily, 'Nunito');
      expect(AppTheme.of('Matrix').textTheme.bodyLarge?.fontFamily, 'Source Code Pro');
    });
    test('Sheets zeichnen nur einen Griff (Theme ohne eigenen)', () {
      expect(AppTheme.of('Light').bottomSheetTheme.showDragHandle, isFalse);
    });
  });

  group('Streams', () {
    test('combineLatestLists fasst Teile zusammen', () async {
      final a = StreamController<List<int>>();
      final b = StreamController<List<int>>();
      final out = <List<int>>[];
      final sub = combineLatestLists([a.stream, b.stream]).listen(out.add);
      a.add([1]);
      await Future<void>.delayed(Duration.zero);
      expect(out, isEmpty); // b fehlt noch
      b.add([2, 3]);
      await Future<void>.delayed(Duration.zero);
      expect(out.last, [1, 2, 3]);
      a.add([9]);
      await Future<void>.delayed(Duration.zero);
      expect(out.last, [9, 2, 3]);
      await sub.cancel();
      await a.close();
      await b.close();
    });
    test('leer liefert sofort eine leere Liste; chunked teilt in 30er', () async {
      expect(await combineLatestLists<int>(const []).first, isEmpty);
      final ids = List.generate(65, (i) => 'l$i');
      expect(chunked(ids).map((c) => c.length).toList(), [30, 30, 5]);
    });
  });

  group('Anhänge', () {
    test('Dateinamen, Typen und Grenzen', () {
      expect(sanitizeFileName('Rechnung Küche (final).pdf'), 'Rechnung-K-che-final-.pdf');
      expect(sanitizeFileName('   '), 'datei');
      expect(contentTypeFor('a.PDF'), 'application/pdf');
      expect(contentTypeFor('a.jpeg'), 'image/jpeg');
      expect(contentTypeFor('a.bin'), 'application/octet-stream');
      expect(checkAttachment('image/jpeg', 5 * 1024 * 1024), AttachmentPickStatus.picked);
      expect(checkAttachment('image/jpeg', 11 * 1024 * 1024), AttachmentPickStatus.tooLarge);
      expect(checkAttachment('application/pdf', 19 * 1024 * 1024), AttachmentPickStatus.picked);
      expect(checkAttachment('application/pdf', 21 * 1024 * 1024), AttachmentPickStatus.tooLarge);
      expect(checkAttachment('application/zip', 10), AttachmentPickStatus.unsupported);
      expect(
        attachmentStoragePath(listId: 'L', todoId: 'T', fileName: 'a.jpg'),
        'todos/L/T/a.jpg',
      );
      expect(
        attachmentStoragePath(listId: 'L', todoId: 'T', fileName: 'a.jpg', chat: true),
        'chats/L/T/a.jpg',
      );
    });
    test('Bild wird auf 1600 px verkleinert und als JPEG geliefert', () {
      final wide = img.Image(width: 3200, height: 800);
      img.fill(wide, color: img.ColorRgb8(10, 20, 30));
      final out = compressAttachmentImage(Uint8List.fromList(img.encodePng(wide)));
      final decoded = img.decodeJpg(out!)!;
      expect(decoded.width, 1600);
      expect(decoded.height, 400);
      final small = img.Image(width: 300, height: 200);
      final out2 = compressAttachmentImage(Uint8List.fromList(img.encodePng(small)));
      expect(img.decodeJpg(out2!)!.width, 300);
      expect(compressAttachmentImage(Uint8List.fromList([1, 2, 3])), isNull);
    });
    test('Modell hin und zurück', () {
      final a = AttachmentModel(
        id: 'a1',
        todoId: 't',
        listId: 'l',
        name: 'foto.jpg',
        path: 'todos/l/t/a1-foto.jpg',
        url: 'https://x/y',
        contentType: 'image/jpeg',
        size: 10,
        uploadedBy: 'anna',
        uploadedByName: 'Anna',
        createdAt: DateTime(2026, 10, 16, 9),
      );
      expect(AttachmentModel.fromJson(a.toJson()), a);
      expect(a.isImage, isTrue);
      expect(a.isPdf, isFalse);
    });
    test('Mock-Repository streamt Änderungen', () async {
      final repo = MockAttachmentRepository();
      final seen = <int>[];
      final sub = repo.watch('t').listen((l) => seen.add(l.length));
      await Future<void>.delayed(Duration.zero);
      await repo.add(
        AttachmentModel(
          id: 'a',
          todoId: 't',
          listId: 'l',
          name: 'n',
          path: 'p',
          url: 'u',
          contentType: 'application/pdf',
          size: 1,
          uploadedBy: 'x',
          uploadedByName: 'X',
          createdAt: DateTime(2026),
        ),
      );
      await repo.remove('t', 'a');
      await Future<void>.delayed(Duration.zero);
      expect(seen, [0, 1, 0]);
      await sub.cancel();
    });
    testWidgets('Galerie: Hinzufügen-Kachel, Upload, Löschen-Knopf', (tester) async {
      var added = 0;
      TdAttachmentItem? deleted;
      await tester.pumpWidget(
        _app(
          TdAttachmentGallery(
            onAdd: () => added++,
            addLabel: 'Hinzufügen',
            deleteLabel: 'Löschen',
            uploads: const [TdUploadProgress(name: 'u.jpg', progress: 0.4)],
            items: const [
              TdAttachmentItem(id: '1', name: 'rechnung.pdf', isImage: false, canDelete: true),
              TdAttachmentItem(id: '2', name: 'bild.jpg', url: '', canDelete: false),
            ],
            onDelete: (i) => deleted = i,
            onOpen: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hinzufügen'), findsOneWidget);
      expect(find.text('rechnung.pdf'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget); // nur bei canDelete
      await tester.tap(find.text('Hinzufügen'));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(added, 1);
      expect(deleted?.id, '1');
    });
    test('Chat-Nachricht trägt Bild', () {
      final m = ChatMessageModel(
        id: '1',
        todoId: 't',
        userId: 'u',
        userName: 'U',
        message: '',
        timestamp: DateTime(2026, 10, 16),
        imageUrl: 'https://x/bild.jpg',
        imagePath: 'chats/l/t/bild.jpg',
      );
      final back = ChatMessageModel.fromJson(m.toJson());
      expect(back.hasImage, isTrue);
      expect(back.imagePath, 'chats/l/t/bild.jpg');
      expect(
        ChatMessageModel.fromJson({
          'id': '2',
          'todoId': 't',
          'userId': 'u',
          'userName': 'U',
          'message': 'hi',
          'timestamp': '2026-10-16T10:00:00.000',
        }).hasImage,
        isFalse,
      );
    });
  });

  group('Listen-Optik', () {
    test('Farbe je Liste stabil, Symbol je Art', () {
      final l = _list();
      expect(listColor(l), listColor(_list()));
      expect(listIcon(l), Icons.checklist_rounded);
      expect(listHeroTag('x'), 'list-icon-x');
    });
    testWidgets('ListHeader zeigt Name und Mitglieder (Hero-Symbol)', (tester) async {
      await tester.pumpWidget(_app(ListHeader(list: _list(), subtitle: '2 Mitglieder')));
      await tester.pumpAndSettle();
      expect(find.text('Haushalt'), findsOneWidget);
      expect(find.text('2 Mitglieder'), findsOneWidget);
      expect(find.byType(Hero), findsOneWidget);
    });
  });

  group('Aufgaben-Sheet ohne Bearbeitungsrecht', () {
    testWidgets('zeigt Werte, keine Felder, kein Speichern', (tester) async {
      final members = const [
        FairnessMember(id: 'anna', name: 'Anna', index: 0),
        FairnessMember(id: 'ben', name: 'Ben', index: 1),
      ];
      final todo = TodoModel(
        id: 't1',
        title: 'Bad putzen',
        description: 'gründlich',
        createdAt: DateTime(2026, 10, 1),
        userId: 'anna',
        listId: 'L1',
        assignedToUserId: 'ben',
        assignedToUserName: 'Ben',
        category: 'Küche',
      );
      await tester.pumpWidget(
        _app(
          TaskEditorForm(
            listId: 'L1',
            members: members,
            listTodos: [todo],
            currentUserId: 'ben',
            repository: MockTodoRepository(),
            todo: todo,
            canEdit: false,
            now: DateTime(2026, 10, 16),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bad putzen'), findsOneWidget);
      expect(find.text('gründlich'), findsOneWidget);
      expect(find.text('Küche'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const ValueKey('task-save')), findsNothing);
      expect(find.text('Schließen'), findsOneWidget);
      expect(find.text('Nur Lesen'), findsOneWidget);
    });
  });

  group('TdTaskTile', () {
    testWidgets('Rückfrage vor dem Löschen per Wischen', (tester) async {
      var deleted = false;
      var asked = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 390,
            child: TdTaskTile(
              title: 'Müll',
              done: false,
              onChanged: (_) {},
              onDelete: () => deleted = true,
              confirmDelete: () async {
                asked++;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Müll'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(deleted, isFalse);
      expect(find.text('Müll'), findsOneWidget);
    });
    testWidgets('gesperrtes Abhaken erklärt sich per Tooltip', (tester) async {
      await tester.pumpWidget(
        _app(
          const TdTaskTile(
            title: 'Fremd',
            done: false,
            disabledHint: 'Nur Mitglieder',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.byType(Dismissible), findsNothing);
    });
  });
}
