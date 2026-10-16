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
import 'package:togetherdo/design/td_design.dart';
import 'package:togetherdo/fairness/fairness.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/models/anhang_model.dart';
import 'package:togetherdo/models/chat_message_model.dart';
import 'package:togetherdo/models/list_model.dart';
import 'package:togetherdo/models/todo_model.dart';
import 'package:togetherdo/navigation/app_shell.dart';
import 'package:togetherdo/repositories/anhang_repository.dart';
import 'package:togetherdo/repositories/todo_repository.dart';
import 'package:togetherdo/services/attachment_service.dart';
import 'package:togetherdo/utils/app_theme.dart';
import 'package:togetherdo/utils/stream_utils.dart';
import 'package:togetherdo/widgets/attachments/anhang_abschnitt.dart';
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

  group('Anhänge (gemeinsam für Aufgaben und Termine)', () {
    Anhang anhang(String id, {String von = 'anna', String typ = 'application/pdf'}) => Anhang(
      id: id,
      name: '$id.pdf',
      typ: typ,
      groesse: 1200,
      pfad: 'todos/L1/T1/$id',
      hochgeladenVon: von,
      hochgeladenAm: DateTime.utc(2026, 10, 16, 9),
    );

    test('Ziel liefert Storage-Pfad und Sammlung', () {
      const a = AnhangZiel.aufgabe(listId: 'L', todoId: 'T');
      const t = AnhangZiel.termin(listId: 'L', terminId: 'X');
      expect(a.storagePfad, 'todos/L/T');
      expect(t.storagePfad, 'termine/L/X');
      expect(a.sammlung.name, 'todos');
      expect(t.sammlung.name, 'termine');
      expect(a, const AnhangZiel.aufgabe(listId: 'L', todoId: 'T'));
      expect(a == t, isFalse);
    });
    test('Modell hin und zurück', () {
      final a = anhang('a1', typ: 'image/jpeg');
      final back = Anhang.fromJson(a.toJson());
      expect(back, a);
      expect(back.hochgeladenVon, 'anna');
      expect(back.istBild, isTrue);
      expect(back.istPdf, isFalse);
    });
    test('Mock-Repository streamt Änderungen je Ziel', () async {
      final repo = MockAnhangRepository();
      const z = AnhangZiel.aufgabe(listId: 'L1', todoId: 'T1');
      const anderes = AnhangZiel.termin(listId: 'L1', terminId: 'T1');
      final seen = <int>[];
      final sub = repo.beobachten(z).listen((l) => seen.add(l.length));
      await Future<void>.delayed(Duration.zero);
      await repo.hinzufuegen(z, anhang('a'));
      await repo.hinzufuegen(anderes, anhang('b'));
      await repo.entfernen(z, 'a');
      await Future<void>.delayed(Duration.zero);
      expect(seen, [0, 1, 0]);
      expect(repo.von(anderes), hasLength(1));
      await sub.cancel();
    });
    test('Vormerkung: neue Aufgabe sammelt und lädt nach dem Anlegen hoch', () async {
      final service = FakeAttachmentService();
      final repo = MockAnhangRepository();
      final v = AnhangVormerkung();
      v.hinzufuegen(
        AnhangAuswahl(bytes: Uint8List(10), name: 'Rechnung.pdf', mime: 'application/pdf'),
        userId: 'ben',
      );
      expect(v.anhaenge.single.pfad, startsWith('vorgemerkt/'));
      // Galerie-Dienst liefert die vorgemerkte Datei aus dem Speicher.
      expect(await v.dienst(service).laden(v.anhaenge.single.pfad), hasLength(10));
      const z = AnhangZiel.aufgabe(listId: 'L1', todoId: 'NEU');
      await v.hochladen(ziel: z, service: service, repository: repo, userId: 'ben');
      expect(v.leer, isTrue);
      final a = repo.von(z).single;
      expect(a.pfad, startsWith('todos/L1/NEU/'));
      expect(a.hochgeladenVon, 'ben');
      expect(service.dateien.containsKey(a.pfad), isTrue);
    });
    testWidgets('Abschnitt: Galerie, Plus-Kachel, Hochladen trägt ein', (tester) async {
      final service = FakeAttachmentService(bilderVerarbeiten: false);
      const z = AnhangZiel.aufgabe(listId: 'L1', todoId: 'T1');
      final repo = MockAnhangRepository({z: [anhang('vorhanden')]});
      service.naechsteAuswahl = [
        AnhangAuswahl(bytes: Uint8List(5), name: 'Plan.pdf', mime: 'application/pdf'),
      ];
      await tester.pumpWidget(
        _app(AnhangAbschnitt(service: service, repository: repo, userId: 'ben', ziel: z)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anhänge'), findsOneWidget);
      expect(find.text('vorhanden.pdf'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pumpAndSettle();
      // Quelle wählen: Dokument.
      await tester.tap(find.text('Dokument'));
      await tester.pumpAndSettle();
      expect(service.gewaehlt, [AnhangQuelle.dokument]);
      expect(repo.von(z).map((a) => a.name), ['vorhanden.pdf', 'Plan.pdf']);
      expect(find.text('Plan.pdf'), findsOneWidget);
    });
    testWidgets('Kennzeichen zeigt die Anzahl, nichts bei 0', (tester) async {
      const z = AnhangZiel.aufgabe(listId: 'L1', todoId: 'T1');
      final repo = MockAnhangRepository();
      await tester.pumpWidget(_app(AnhangAnzahl(repository: repo, ziel: z)));
      await tester.pump();
      expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
      await repo.hinzufuegen(z, anhang('a'));
      await repo.hinzufuegen(z, anhang('b'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
    });
    test('Chat-Nachricht trägt Bildpfad und Vorschau', () {
      final m = ChatMessageModel(
        id: '1',
        todoId: 't',
        userId: 'u',
        userName: 'U',
        message: '',
        timestamp: DateTime(2026, 10, 16),
        imagePath: 'chats/l/t/bild',
        imagePreviewPath: 'chats/l/t/bild_vorschau.jpg',
      );
      final back = ChatMessageModel.fromJson(m.toJson());
      expect(back.hasImage, isTrue);
      expect(back.imagePath, 'chats/l/t/bild');
      expect(back.imagePreviewPath, 'chats/l/t/bild_vorschau.jpg');
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
