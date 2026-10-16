/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../components/td_avatar.dart';
import '../components/td_chip.dart';

/// Beispieldaten für den Vorzeige-Startbildschirm. Keine Firebase-
/// Anbindung, keine echten Personen.
class DemoList {
  const DemoList({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.isShopping = false,
  });

  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final bool isShopping;
}

enum DemoDue { today, tonight, overdue, later }

class DemoTask {
  DemoTask({
    required this.id,
    required this.title,
    required this.listId,
    this.subtitle,
    this.done = false,
    this.assignee,
    this.weight = TdWeight.medium,
    this.due = DemoDue.today,
    this.quantity,
  });

  final String id;
  final String title;
  final String listId;
  final String? subtitle;
  bool done;
  final TdAvatarData? assignee;
  final TdWeight weight;
  final DemoDue due;

  /// Nur Einkauf: „2 L“, „500 g“.
  final String? quantity;

  DemoTask copyWith({bool? done}) => DemoTask(
    id: id,
    title: title,
    listId: listId,
    subtitle: subtitle,
    done: done ?? this.done,
    assignee: assignee,
    weight: weight,
    due: due,
    quantity: quantity,
  );
}

class DemoData {
  DemoData._();

  static const me = TdAvatarData(
    id: 'me',
    name: 'Martin',
    color: Color(0xFF6A5AE0),
  );
  static const anna = TdAvatarData(
    id: 'anna',
    name: 'Anna',
    color: Color(0xFFFF7A59),
  );
  static const leo = TdAvatarData(
    id: 'leo',
    name: 'Leo',
    color: Color(0xFF1FB38F),
  );

  static const people = [me, anna, leo];

  static const lists = <DemoList>[
    DemoList(
      id: 'haus',
      name: 'Haushalt',
      color: Color(0xFF6A5AE0),
      icon: Icons.home_rounded,
    ),
    DemoList(
      id: 'kids',
      name: 'Kinder',
      color: Color(0xFFF2A500),
      icon: Icons.child_care_rounded,
    ),
    DemoList(
      id: 'garten',
      name: 'Garten',
      color: Color(0xFF1FB38F),
      icon: Icons.yard_rounded,
    ),
    DemoList(
      id: 'einkauf',
      name: 'Wocheneinkauf',
      color: Color(0xFFFF7A59),
      icon: Icons.shopping_basket_rounded,
      isShopping: true,
    ),
  ];

  static DemoList listById(String id) => lists.firstWhere((l) => l.id == id);

  static List<DemoTask> tasks() => [
    DemoTask(
      id: 't1',
      title: 'Müll rausbringen',
      listId: 'haus',
      assignee: me,
      weight: TdWeight.light,
      due: DemoDue.tonight,
    ),
    DemoTask(
      id: 't2',
      title: 'Kita-Tasche packen',
      subtitle: 'Wechselkleidung, Trinkflasche',
      listId: 'kids',
      assignee: anna,
      weight: TdWeight.medium,
    ),
    DemoTask(
      id: 't3',
      title: 'Bad putzen',
      listId: 'haus',
      assignee: me,
      weight: TdWeight.heavy,
      due: DemoDue.overdue,
    ),
    DemoTask(
      id: 't4',
      title: 'Hochbeet gießen',
      listId: 'garten',
      assignee: leo,
      weight: TdWeight.light,
    ),
    DemoTask(
      id: 't5',
      title: 'Wäsche aufhängen',
      listId: 'haus',
      done: true,
      assignee: anna,
      weight: TdWeight.medium,
    ),
  ];

  static List<DemoTask> shopping() => [
    DemoTask(
      id: 's1',
      title: 'Hafermilch',
      listId: 'einkauf',
      quantity: '2 L',
      weight: TdWeight.light,
    ),
    DemoTask(
      id: 's2',
      title: 'Tomaten',
      listId: 'einkauf',
      quantity: '500 g',
      weight: TdWeight.light,
    ),
    DemoTask(
      id: 's3',
      title: 'Brot',
      listId: 'einkauf',
      subtitle: 'Vollkorn, geschnitten',
      weight: TdWeight.light,
    ),
    DemoTask(
      id: 's4',
      title: 'Spülmittel',
      listId: 'einkauf',
      done: true,
      weight: TdWeight.light,
    ),
  ];

  /// Erledigte Gewichtspunkte diese Woche (Attrappe).
  static const weekPoints = <String, double>{'me': 9, 'anna': 13, 'leo': 5};
}
