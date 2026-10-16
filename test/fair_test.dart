/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Tests für Stufe 3 „Fair verteilt“: Aufwand/Punkte, Statistik je Woche
// und Monat, „wer ist dran“, Bewertungsregeln und das Aufgaben-Sheet.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:togetherdo/design/td_design.dart';
import 'package:togetherdo/fairness/fairness.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/models/list_model.dart';
import 'package:togetherdo/models/todo_model.dart';
import 'package:togetherdo/repositories/todo_repository.dart';
import 'package:togetherdo/services/review_service.dart';
import 'package:togetherdo/utils/app_theme.dart';
import 'package:togetherdo/widgets/common/user_avatar.dart';
import 'package:togetherdo/widgets/fairness/fairness_widgets.dart';
import 'package:togetherdo/widgets/todo/task_editor_sheet.dart';

const anna = FairnessMember(id: 'anna', name: 'Anna');
const ben = FairnessMember(id: 'ben', name: 'Ben');
const cleo = FairnessMember(id: 'cleo', name: 'Cleo');
const members = [anna, ben, cleo];

// Donnerstag, 15. Oktober 2026, 12 Uhr → Woche ab Mo 12.10., Monat ab 1.10.
final now = DateTime(2026, 10, 15, 12);

TodoModel todo(
  String id, {
  String? doneBy,
  DateTime? doneAt,
  TaskEffort effort = TaskEffort.medium,
  String? assignee,
  bool completed = true,
}) => TodoModel(
  id: id,
  title: 'Aufgabe $id',
  description: '',
  createdAt: DateTime(2026, 10, 1),
  userId: 'anna',
  listId: 'L1',
  isCompleted: doneBy != null && completed,
  completedByUserId: doneBy,
  completedAt: doneAt,
  effort: effort,
  assignedToUserId: assignee,
);

class _RecordingTodoRepository extends MockTodoRepository {
  final added = <Map<String, Object?>>[];
  final updated = <TodoModel>[];

  @override
  Future<TodoModel> addTodo({
    required String title,
    required String description,
    DateTime? dueDate,
    TodoPriority priority = TodoPriority.medium,
    required String userId,
    String? category,
    required String listId,
    String? assignedToUserId,
    String? assignedToUserName,
    TaskEffort effort = TaskEffort.medium,
  }) async {
    added.add({
      'title': title,
      'assignedToUserId': assignedToUserId,
      'effort': effort,
      'dueDate': dueDate,
    });
    return todo('neu');
  }

  @override
  Future<TodoModel> updateTodo(TodoModel todo) async {
    updated.add(todo);
    return todo;
  }
}

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

void main() {
  setUpAll(() {
    UserAvatarCache.instance.loaderOverride = (_) async => null;
  });

  group('Datenmodell', () {
    test('Aufwand: Punkte und Standard „mittel“', () {
      expect(TaskEffort.light.points, 1);
      expect(TaskEffort.medium.points, 2);
      expect(TaskEffort.heavy.points, 3);
      expect(TaskEffort.fromValue(null), TaskEffort.medium);
      expect(TaskEffort.fromValue('quatsch'), TaskEffort.medium);
      expect(TaskEffort.fromValue('heavy'), TaskEffort.heavy);
    });

    test('alte Aufgabe ohne effort/completedAt wird als mittel gelesen', () {
      final t = TodoModel.fromJson({
        'id': 'x',
        'title': 'Alt',
        'description': '',
        'createdAt': '2025-07-01T10:00:00.000',
        'userId': 'anna',
        'listId': 'L1',
        'isCompleted': true,
        'completedByUserId': 'anna',
      });
      expect(t.effort, TaskEffort.medium);
      expect(t.completedAt, isNull);
    });

    test(
      'completedAt als Timestamp, effort im JSON, kein completedAt in toJson',
      () {
        final t = TodoModel.fromJson({
          'id': 'x',
          'title': 'Neu',
          'description': '',
          'createdAt': '2026-10-01T10:00:00.000',
          'userId': 'anna',
          'listId': 'L1',
          'isCompleted': true,
          'completedByUserId': 'ben',
          'completedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 14, 8)),
          'effort': 'heavy',
        });
        expect(t.completedAt, DateTime.utc(2026, 10, 14, 8).toLocal());
        expect(t.effort, TaskEffort.heavy);
        final json = t.toJson();
        expect(json['effort'], 'heavy');
        expect(json.containsKey('completedAt'), isFalse);
      },
    );

    test('copyWith kann Zuständigkeit, Datum und Erledigt leeren', () {
      final t = todo(
        'a',
        doneBy: 'anna',
        doneAt: now,
        assignee: 'ben',
      ).copyWith(dueDate: now);
      final c = t.copyWith(
        clearAssignee: true,
        clearDueDate: true,
        clearCompletion: true,
        isCompleted: false,
      );
      expect(c.assignedToUserId, isNull);
      expect(c.dueDate, isNull);
      expect(c.completedByUserId, isNull);
      expect(c.completedAt, isNull);
    });

    test('Mitglieder einer Liste: Besitzer zuerst', () {
      final list = ListModel(
        id: 'L1',
        name: 'WG',
        ownerId: 'anna',
        ownerName: 'Anna',
        type: ListType.todo,
        createdAt: now,
        updatedAt: now,
        memberIds: const ['ben', 'cleo'],
        memberNames: const ['Ben'],
      );
      final m = fairnessMembersOf(
        list,
        fallbackName: (i) => 'Mitglied ${i + 1}',
      );
      expect(m.map((e) => e.id), ['anna', 'ben', 'cleo']);
      expect(m.last.name, 'Mitglied 2');
    });
  });

  group('Zeiträume', () {
    test('Woche ab Montag 0 Uhr, Monat ab dem 1.', () {
      expect(
        fairnessPeriodStart(FairnessPeriod.week, now),
        DateTime(2026, 10, 12),
      );
      expect(
        fairnessPeriodStart(FairnessPeriod.month, now),
        DateTime(2026, 10, 1),
      );
      // Sonntag gehört noch zur Woche ab Montag davor
      expect(
        fairnessPeriodStart(FairnessPeriod.week, DateTime(2026, 10, 18, 23)),
        DateTime(2026, 10, 12),
      );
    });

    test('Abfrage beginnt beim früheren der beiden Zeiträume', () {
      // Do 1.10.: Woche ab Mo 28.9. liegt vor dem Monatsanfang
      expect(
        fairnessQueryStart(DateTime(2026, 10, 1, 9)),
        DateTime(2026, 9, 28),
      );
      expect(fairnessQueryStart(now), DateTime(2026, 10, 1));
    });
  });

  group('Statistik', () {
    final todos = [
      todo(
        '1',
        doneBy: 'anna',
        doneAt: DateTime(2026, 10, 13),
        effort: TaskEffort.heavy,
      ),
      todo(
        '2',
        doneBy: 'anna',
        doneAt: DateTime(2026, 10, 14),
        effort: TaskEffort.light,
      ),
      todo(
        '3',
        doneBy: 'ben',
        doneAt: DateTime(2026, 10, 14),
        effort: TaskEffort.medium,
      ),
      todo(
        '4',
        doneBy: 'ben',
        doneAt: DateTime(2026, 10, 5),
        effort: TaskEffort.heavy,
      ), // Vorwoche
      todo('5', doneBy: 'fremd', doneAt: DateTime(2026, 10, 14)), // ehemalig
      todo('6', doneBy: 'cleo', doneAt: DateTime(2026, 9, 30)), // Vormonat
      todo('7'), // offen
    ];

    test('Woche: Punkte und Anteile je Mitglied', () {
      final s = FairnessStats.compute(
        period: FairnessPeriod.week,
        members: members,
        todos: todos,
        now: now,
      );
      expect(s.shareOf('anna')!.points, 4);
      expect(s.shareOf('anna')!.tasks, 2);
      expect(s.shareOf('ben')!.points, 2);
      expect(s.shareOf('cleo')!.points, 0);
      expect(s.totalPoints, 6);
      expect(s.shareOf('anna')!.share, closeTo(2 / 3, 1e-9));
      expect(s.top!.member, anna);
      expect(s.isBalanced, isFalse);
    });

    test('Monat zählt die Vorwoche mit, den Vormonat nicht', () {
      final s = FairnessStats.compute(
        period: FairnessPeriod.month,
        members: members,
        todos: todos,
        now: now,
      );
      expect(s.shareOf('ben')!.points, 5);
      expect(s.shareOf('cleo')!.points, 0);
      expect(s.totalPoints, 9);
    });

    test('ohne Erledigt-Zeit (Serverzeit unterwegs) zählt als jetzt', () {
      final s = FairnessStats.compute(
        period: FairnessPeriod.week,
        members: members,
        todos: [todo('x', doneBy: 'cleo')],
        now: now,
      );
      expect(s.shareOf('cleo')!.points, 2);
    });

    test('gut verteilt: alle nahe am gleichen Anteil, genug Punkte', () {
      FairnessStats stats(List<TodoModel> t) => FairnessStats.compute(
        period: FairnessPeriod.week,
        members: const [anna, ben],
        todos: t,
        now: now,
      );
      final balanced = stats([
        todo('a', doneBy: 'anna', doneAt: now, effort: TaskEffort.heavy),
        todo('b', doneBy: 'ben', doneAt: now, effort: TaskEffort.medium),
        todo('c', doneBy: 'ben', doneAt: now, effort: TaskEffort.light),
      ]);
      expect(balanced.isBalanced, isTrue);
      final tooLittle = stats([
        todo('a', doneBy: 'anna', doneAt: now, effort: TaskEffort.light),
        todo('b', doneBy: 'ben', doneAt: now, effort: TaskEffort.light),
      ]);
      expect(tooLittle.hasVerdict, isFalse);
      expect(tooLittle.isBalanced, isFalse);
      final empty = stats(const []);
      expect(empty.isEmpty, isTrue);
      expect(empty.top, isNull);
    });
  });

  group('Wer ist dran', () {
    test('geringste Last aus erledigt (Woche) + offen zugewiesen', () {
      final s = suggestNextAssignee(
        members: members,
        now: now,
        todos: [
          todo(
            '1',
            doneBy: 'anna',
            doneAt: DateTime(2026, 10, 13),
            effort: TaskEffort.heavy,
          ),
          todo(
            '2',
            doneBy: 'ben',
            doneAt: DateTime(2026, 10, 13),
            effort: TaskEffort.light,
          ),
          todo(
            '3',
            assignee: 'cleo',
            effort: TaskEffort.heavy,
            completed: false,
          ),
          todo(
            '4',
            doneBy: 'ben',
            doneAt: DateTime(2026, 10, 1),
            effort: TaskEffort.heavy,
          ), // Vorwoche
        ],
      )!;
      expect(s.load, {'anna': 3, 'ben': 1, 'cleo': 3});
      expect(s.member, ben);
    });

    test('Gleichstand: weniger erledigt, dann Reihenfolge', () {
      final s = suggestNextAssignee(
        members: members,
        now: now,
        todos: [
          todo('1', doneBy: 'anna', doneAt: now, effort: TaskEffort.medium),
          todo(
            '2',
            assignee: 'ben',
            effort: TaskEffort.medium,
            completed: false,
          ),
        ],
      )!;
      // anna 2 (erledigt), ben 2 (offen), cleo 0
      expect(s.member, cleo);
      final tie = suggestNextAssignee(
        members: const [anna, ben],
        now: now,
        todos: [
          todo('1', doneBy: 'anna', doneAt: now, effort: TaskEffort.medium),
          todo(
            '2',
            assignee: 'ben',
            effort: TaskEffort.medium,
            completed: false,
          ),
        ],
      )!;
      expect(tie.member, ben); // gleiche Last, Ben hat weniger erledigt
      expect(
        suggestNextAssignee(members: const [], todos: const [], now: now),
        isNull,
      );
    });
  });

  group('Bewertungsanfrage', () {
    const policy = ReviewPolicy();
    final first = DateTime(2026, 10, 1);

    test('Erfolgsmomente: 10., dann jede 25. erledigte Aufgabe', () {
      expect(policy.momentForCompletedCount(9), isNull);
      expect(policy.momentForCompletedCount(10), ReviewMoment.tenthTaskDone);
      expect(policy.momentForCompletedCount(11), isNull);
      expect(policy.momentForCompletedCount(25), ReviewMoment.taskMilestone);
      expect(policy.momentForCompletedCount(50), ReviewMoment.taskMilestone);
    });

    test('frühestens 3 Tage nach erster Nutzung', () {
      expect(
        policy.mayPrompt(
          now: first.add(const Duration(days: 2)),
          firstUse: first,
          lastPrompt: null,
          lastError: null,
        ),
        isFalse,
      );
      expect(
        policy.mayPrompt(
          now: first.add(const Duration(days: 3)),
          firstUse: first,
          lastPrompt: null,
          lastError: null,
        ),
        isTrue,
      );
      expect(
        policy.mayPrompt(
          now: now,
          firstUse: null,
          lastPrompt: null,
          lastError: null,
        ),
        isFalse,
      );
    });

    test('höchstens alle 60 Tage, nicht kurz nach Fehler', () {
      final t = DateTime(2026, 12, 1);
      expect(
        policy.mayPrompt(
          now: t,
          firstUse: first,
          lastPrompt: t.subtract(const Duration(days: 59)),
          lastError: null,
        ),
        isFalse,
      );
      expect(
        policy.mayPrompt(
          now: t,
          firstUse: first,
          lastPrompt: t.subtract(const Duration(days: 60)),
          lastError: null,
        ),
        isTrue,
      );
      expect(
        policy.mayPrompt(
          now: t,
          firstUse: first,
          lastPrompt: null,
          lastError: t.subtract(const Duration(minutes: 3)),
        ),
        isFalse,
      );
    });

    test(
      'Dienst: 10. Aufgabe fragt einmal, danach Pause; Fehler sperrt',
      () async {
        SharedPreferences.setMockInitialValues({
          'review.firstUse': DateTime(2026, 10, 1).toIso8601String(),
          'review.completedCount': 8,
        });
        final service = ReviewService.instance;
        var asked = 0;
        var clock = DateTime(2026, 10, 10);
        service.clock = () => clock;
        service.requestOverride = () async => asked++;

        await service.onTaskCompleted(); // 9
        expect(asked, 0);
        await service.onTaskCompleted(); // 10
        expect(asked, 1);
        await service.onFairWeek(DateTime(2026, 10, 5)); // innerhalb 60 Tage
        expect(asked, 1);

        clock = DateTime(2027, 1, 1);
        service.noteError();
        await service.onFairWeek(DateTime(2026, 12, 28));
        expect(asked, 1, reason: 'kurz nach Fehler');
        clock = DateTime(2027, 1, 1, 1);
        await service.onFairWeek(DateTime(2026, 12, 28));
        expect(asked, 1, reason: 'dieselbe Woche nur einmal');
        await service.onFairWeek(DateTime(2027, 1, 4));
        expect(asked, 2);
        service.requestOverride = null;
        service.clock = DateTime.now;
      },
    );
  });

  group('Oberfläche', () {
    testWidgets('Fairness-Karte zeigt Anteile, Hinweis und Woche/Monat', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          FairnessCard(
            members: members,
            now: now,
            currentUserId: 'anna',
            onOpenStats: () {},
            suggestion: const FairnessSuggestion(member: cleo, load: {}),
            doneTodos: [
              todo(
                '1',
                doneBy: 'anna',
                doneAt: DateTime(2026, 10, 13),
                effort: TaskEffort.heavy,
              ),
              todo(
                '2',
                doneBy: 'ben',
                doneAt: DateTime(2026, 10, 13),
                effort: TaskEffort.light,
              ),
              todo(
                '3',
                doneBy: 'ben',
                doneAt: DateTime(2026, 10, 2),
                effort: TaskEffort.heavy,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fair verteilt'), findsOneWidget);
      expect(
        find.text('Du hast am meisten getragen. Als Nächstes ist Cleo dran.'),
        findsOneWidget,
      );
      expect(find.text('75 %'), findsOneWidget); // Anna 3 von 4

      await tester.tap(find.text('Monat'));
      await tester.pumpAndSettle();
      expect(find.text('43 %'), findsOneWidget); // Anna 3 von 7
      expect(find.text('57 %'), findsOneWidget); // Ben 4 von 7
    });

    testWidgets(
      'Sheet „Neue Aufgabe“: Vorschlag vorausgewählt, Aufwand wählbar',
      (tester) async {
        final repo = _RecordingTodoRepository();
        await tester.pumpWidget(
          _app(
            TaskEditorForm(
              listId: 'L1',
              members: members,
              currentUserId: 'anna',
              repository: repo,
              now: now,
              listTodos: [
                todo(
                  '1',
                  doneBy: 'anna',
                  doneAt: now,
                  effort: TaskEffort.heavy,
                ),
                todo(
                  '2',
                  doneBy: 'cleo',
                  doneAt: now,
                  effort: TaskEffort.medium,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Vorschlag: Ben ist dran'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'Bad putzen');
        await tester.tap(find.byKey(const ValueKey('effort-heavy')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const ValueKey('task-save')));
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pump(const Duration(milliseconds: 100));

        expect(repo.added, hasLength(1));
        expect(repo.added.single['title'], 'Bad putzen');
        expect(repo.added.single['assignedToUserId'], 'ben');
        expect(repo.added.single['effort'], TaskEffort.heavy);
      },
    );

    testWidgets(
      'Sheet „Bearbeiten“: Werte übernommen, Zuständigkeit änderbar',
      (tester) async {
        final repo = _RecordingTodoRepository();
        final existing = todo(
          'e',
          assignee: 'cleo',
          effort: TaskEffort.light,
          completed: false,
        ).copyWith(description: 'alt', dueDate: DateTime(2026, 10, 20, 18));
        await tester.pumpWidget(
          _app(
            TaskEditorForm(
              listId: 'L1',
              members: members,
              currentUserId: 'anna',
              repository: repo,
              now: now,
              listTodos: [existing],
              todo: existing,
            ),
            locale: const Locale('en', 'US'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Aufgabe e'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('assignee-ben')));
        await tester.tap(find.text('Remove date'));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const ValueKey('task-save')));
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pump(const Duration(milliseconds: 100));

        final saved = repo.updated.single;
        expect(saved.assignedToUserId, 'ben');
        expect(saved.assignedToUserName, 'Ben');
        expect(saved.effort, TaskEffort.light);
        expect(saved.dueDate, isNull);
        expect(saved.description, 'alt');
      },
    );
  });
}
