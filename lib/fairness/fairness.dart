/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// „Fair verteilt“: reine Rechenlogik ohne Firebase und ohne Oberfläche,
/// damit sie sich vollständig testen lässt.
///
/// - Jede erledigte Aufgabe bringt Punkte nach Aufwand (leicht 1, mittel 2,
///   schwer 3; ohne Angabe mittel).
/// - Die Statistik zählt je Mitglied die Punkte im Zeitraum (Woche ab
///   Montag 0 Uhr bzw. Monat ab dem 1., jeweils Ortszeit).
/// - „Wer ist dran“: das Mitglied mit der geringsten Last
///   (erledigte Punkte dieser Woche + Punkte offener, ihm zugewiesener
///   Aufgaben).
library;

import '../models/list_model.dart';
import '../models/todo_model.dart';

enum FairnessPeriod { week, month }

/// Beginn des laufenden Zeitraums in Ortszeit.
DateTime fairnessPeriodStart(FairnessPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    FairnessPeriod.week => today.subtract(Duration(days: today.weekday - 1)),
    FairnessPeriod.month => DateTime(now.year, now.month),
  };
}

/// Frühester Beginn beider Zeiträume – so reicht eine Abfrage für Woche
/// und Monat (die Woche kann im Vormonat beginnen).
DateTime fairnessQueryStart(DateTime now) {
  final week = fairnessPeriodStart(FairnessPeriod.week, now);
  final month = fairnessPeriodStart(FairnessPeriod.month, now);
  return week.isBefore(month) ? week : month;
}

/// Ein Mitglied einer Liste.
class FairnessMember {
  const FairnessMember({required this.id, required this.name, this.index = 0});

  final String id;
  final String name;

  /// Position in der Liste (Besitzer 0) – für eine feste, eindeutige Farbe.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is FairnessMember && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Besitzer zuerst, dann Mitglieder in Beitrittsreihenfolge.
List<FairnessMember> fairnessMembersOf(
  ListModel list, {
  String Function(int index)? fallbackName,
}) {
  return [
    FairnessMember(id: list.ownerId, name: list.ownerName, index: 0),
    for (var i = 0; i < list.memberIds.length; i++)
      FairnessMember(
        id: list.memberIds[i],
        index: i + 1,
        name: i < list.memberNames.length
            ? list.memberNames[i]
            : (fallbackName?.call(i) ?? '?'),
      ),
  ];
}

/// Anteil eines Mitglieds im Zeitraum.
class MemberShare {
  const MemberShare({
    required this.member,
    required this.points,
    required this.tasks,
    required this.share,
  });

  final FairnessMember member;
  final int points;
  final int tasks;

  /// 0…1 der Gesamtpunkte (0, wenn noch nichts erledigt ist).
  final double share;
}

class FairnessStats {
  const FairnessStats({
    required this.period,
    required this.start,
    required this.shares,
  });

  /// Abweichung vom gleichen Anteil, die noch als „gut verteilt“ gilt
  /// (bei zwei Personen also 35–65 %).
  static const double tolerance = 0.15;

  /// Unterhalb dieser Punktzahl sagt die Verteilung noch nichts aus.
  static const int minPointsForVerdict = 4;

  final FairnessPeriod period;
  final DateTime start;
  final List<MemberShare> shares;

  int get totalPoints => shares.fold(0, (s, e) => s + e.points);
  int get totalTasks => shares.fold(0, (s, e) => s + e.tasks);
  bool get isEmpty => totalPoints == 0;

  /// Genug Daten, um etwas über die Verteilung zu sagen.
  bool get hasVerdict =>
      shares.length >= 2 && totalPoints >= minPointsForVerdict;

  /// Jeder Anteil liegt nahe am gleichen Anteil.
  bool get isBalanced {
    if (!hasVerdict) return false;
    final fair = 1 / shares.length;
    return shares.every((s) => (s.share - fair).abs() <= tolerance);
  }

  MemberShare? get top {
    if (isEmpty) return null;
    return shares.reduce((a, b) => b.points > a.points ? b : a);
  }

  MemberShare? shareOf(String userId) {
    for (final s in shares) {
      if (s.member.id == userId) return s;
    }
    return null;
  }

  /// Zählt erledigte Aufgaben von Mitgliedern ab [start] (bis [now]).
  /// Aufgaben ehemaliger Mitglieder zählen nicht mit.
  static FairnessStats compute({
    required FairnessPeriod period,
    required List<FairnessMember> members,
    required Iterable<TodoModel> todos,
    required DateTime now,
  }) {
    final start = fairnessPeriodStart(period, now);
    final points = <String, int>{for (final m in members) m.id: 0};
    final tasks = <String, int>{for (final m in members) m.id: 0};
    for (final t in todos) {
      if (!countsAsDone(t, start)) continue;
      final by = t.completedByUserId!;
      if (!points.containsKey(by)) continue;
      points[by] = points[by]! + t.effort.points;
      tasks[by] = tasks[by]! + 1;
    }
    final total = points.values.fold(0, (s, e) => s + e);
    return FairnessStats(
      period: period,
      start: start,
      shares: [
        for (final m in members)
          MemberShare(
            member: m,
            points: points[m.id]!,
            tasks: tasks[m.id]!,
            share: total == 0 ? 0 : points[m.id]! / total,
          ),
      ],
    );
  }

  /// Erledigt, mit Person und im Zeitraum. Fehlt die Zeit noch (Serverzeit
  /// unterwegs), gilt „gerade eben“.
  static bool countsAsDone(TodoModel t, DateTime start) {
    if (!t.isCompleted || t.completedByUserId == null) return false;
    final at = t.completedAt;
    return at == null || !at.isBefore(start);
  }
}

/// Ergebnis von „wer ist dran“.
class FairnessSuggestion {
  const FairnessSuggestion({required this.member, required this.load});

  final FairnessMember member;

  /// Last je Mitglied (Punkte), Grundlage des Vorschlags.
  final Map<String, int> load;
}

/// Schlägt vor, wer die nächste Aufgabe übernimmt: geringste Last aus
/// erledigten Punkten dieser Woche plus offenen zugewiesenen Punkten.
/// Gleichstand: weniger erledigte Punkte, dann Reihenfolge der Mitglieder.
/// [todos] darf alle Aufgaben der Liste enthalten.
///
/// [absent]: Mitglieder, die am betreffenden Tag abwesend sind (Urlaub im
/// Familienkalender, siehe `Verfuegbarkeit`). Sie werden nicht
/// vorgeschlagen; ihre Last zählt trotzdem in [FairnessSuggestion.load].
/// Sind alle abwesend, gibt es keinen Vorschlag.
FairnessSuggestion? suggestNextAssignee({
  required List<FairnessMember> members,
  required Iterable<TodoModel> todos,
  required DateTime now,
  Set<String> absent = const {},
}) {
  final available = [
    for (final m in members)
      if (!absent.contains(m.id)) m,
  ];
  if (available.isEmpty) return null;
  final weekStart = fairnessPeriodStart(FairnessPeriod.week, now);
  final done = <String, int>{for (final m in members) m.id: 0};
  final open = <String, int>{for (final m in members) m.id: 0};
  for (final t in todos) {
    if (FairnessStats.countsAsDone(t, weekStart)) {
      final by = t.completedByUserId!;
      if (done.containsKey(by)) done[by] = done[by]! + t.effort.points;
    } else if (!t.isCompleted && t.assignedToUserId != null) {
      final to = t.assignedToUserId!;
      if (open.containsKey(to)) open[to] = open[to]! + t.effort.points;
    }
  }
  final load = {for (final m in members) m.id: done[m.id]! + open[m.id]!};
  var best = available.first;
  for (final m in available.skip(1)) {
    final byLoad = load[m.id]!.compareTo(load[best.id]!);
    if (byLoad < 0 || (byLoad == 0 && done[m.id]! < done[best.id]!)) {
      best = m;
    }
  }
  return FairnessSuggestion(member: best, load: load);
}
