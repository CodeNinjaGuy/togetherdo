/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TodoPriority { low, medium, high }

/// Aufwand einer Aufgabe – Grundlage für „fair verteilt“.
/// In Firestore als Text (`light`/`medium`/`heavy`) im Feld `effort`.
/// Aufgaben ohne Angabe zählen als [medium].
enum TaskEffort {
  light(1),
  medium(2),
  heavy(3);

  const TaskEffort(this.points);

  /// Punkte für die Fairness-Statistik.
  final int points;

  static TaskEffort fromValue(Object? value) {
    for (final e in TaskEffort.values) {
      if (e.name == value) return e;
    }
    return TaskEffort.medium;
  }
}

/// Liest Datumswerte robust: Firestore-Timestamp (neu, Serverzeit) oder
/// ISO-Text (bestehende Felder).
DateTime? parseFirestoreDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class TodoModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueDate;
  final TodoPriority priority;
  final String userId;
  final String? category;
  final String listId;
  final String? assignedToUserId;
  final String? assignedToUserName;
  final String? completedByUserId;
  final String? completedByUserName;

  /// Wann erledigt (Serverzeit). Fehlt bei alten Einträgen.
  final DateTime? completedAt;

  /// Aufwand; fehlt das Feld, gilt „mittel“.
  final TaskEffort effort;

  const TodoModel({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    required this.createdAt,
    this.dueDate,
    this.priority = TodoPriority.medium,
    required this.userId,
    this.category,
    required this.listId,
    this.assignedToUserId,
    this.assignedToUserName,
    this.completedByUserId,
    this.completedByUserName,
    this.completedAt,
    this.effort = TaskEffort.medium,
  });

  factory TodoModel.fromJson(Map<String, dynamic> json) {
    return TodoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: parseFirestoreDate(json['createdAt']) ?? DateTime.now(),
      dueDate: parseFirestoreDate(json['dueDate']),
      priority: TodoPriority.values.firstWhere(
        (e) => e.toString() == 'TodoPriority.${json['priority']}',
        orElse: () => TodoPriority.medium,
      ),
      userId: json['userId'] as String,
      category: json['category'] as String?,
      listId: json['listId'] as String,
      assignedToUserId: json['assignedToUserId'] as String?,
      assignedToUserName: json['assignedToUserName'] as String?,
      completedByUserId: json['completedByUserId'] as String?,
      completedByUserName: json['completedByUserName'] as String?,
      completedAt: parseFirestoreDate(json['completedAt']),
      effort: TaskEffort.fromValue(json['effort']),
    );
  }

  /// Felder zum Anlegen und Bearbeiten. `completedAt` fehlt bewusst: es
  /// wird nur beim Abhaken als Serverzeit gesetzt (siehe Repository).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority.toString().split('.').last,
      'userId': userId,
      'category': category,
      'listId': listId,
      'assignedToUserId': assignedToUserId,
      'assignedToUserName': assignedToUserName,
      'completedByUserId': completedByUserId,
      'completedByUserName': completedByUserName,
      'effort': effort.name,
    };
  }

  TodoModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    TodoPriority? priority,
    String? userId,
    String? category,
    String? listId,
    String? assignedToUserId,
    String? assignedToUserName,
    String? completedByUserId,
    String? completedByUserName,
    DateTime? completedAt,
    TaskEffort? effort,
    bool clearAssignee = false,
    bool clearDueDate = false,
    bool clearCategory = false,
    bool clearCompletion = false,
  }) {
    return TodoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      userId: userId ?? this.userId,
      category: clearCategory ? null : category ?? this.category,
      listId: listId ?? this.listId,
      assignedToUserId: clearAssignee
          ? null
          : assignedToUserId ?? this.assignedToUserId,
      assignedToUserName: clearAssignee
          ? null
          : assignedToUserName ?? this.assignedToUserName,
      completedByUserId: clearCompletion
          ? null
          : completedByUserId ?? this.completedByUserId,
      completedByUserName: clearCompletion
          ? null
          : completedByUserName ?? this.completedByUserName,
      completedAt: clearCompletion ? null : completedAt ?? this.completedAt,
      effort: effort ?? this.effort,
    );
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return !isCompleted && DateTime.now().isAfter(dueDate!);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final due = dueDate!;
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }

  bool get isAssigned => assignedToUserId != null;
  bool get isAssignedToMe => assignedToUserId != null;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    isCompleted,
    createdAt,
    dueDate,
    priority,
    userId,
    category,
    listId,
    assignedToUserId,
    assignedToUserName,
    completedByUserId,
    completedByUserName,
    completedAt,
    effort,
  ];
}
