import 'package:equatable/equatable.dart';

enum TodoPriority { low, medium, high }

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
  });

  factory TodoModel.fromJson(Map<String, dynamic> json) {
    return TodoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
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
    );
  }

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
  }) {
    return TodoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      listId: listId ?? this.listId,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedToUserName: assignedToUserName ?? this.assignedToUserName,
      completedByUserId: completedByUserId ?? this.completedByUserId,
      completedByUserName: completedByUserName ?? this.completedByUserName,
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
  ];
}
