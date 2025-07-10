class NotificationSettings {
  final bool todoCreated;
  final bool todoCompleted;
  final bool todoDeleted;
  final bool memberAdded;
  final bool memberRemoved;

  const NotificationSettings({
    this.todoCreated = true,
    this.todoCompleted = true,
    this.todoDeleted = true,
    this.memberAdded = true,
    this.memberRemoved = true,
  });

  NotificationSettings copyWith({
    bool? todoCreated,
    bool? todoCompleted,
    bool? todoDeleted,
    bool? memberAdded,
    bool? memberRemoved,
  }) {
    return NotificationSettings(
      todoCreated: todoCreated ?? this.todoCreated,
      todoCompleted: todoCompleted ?? this.todoCompleted,
      todoDeleted: todoDeleted ?? this.todoDeleted,
      memberAdded: memberAdded ?? this.memberAdded,
      memberRemoved: memberRemoved ?? this.memberRemoved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'todoCreated': todoCreated,
      'todoCompleted': todoCompleted,
      'todoDeleted': todoDeleted,
      'memberAdded': memberAdded,
      'memberRemoved': memberRemoved,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      todoCreated: map['todoCreated'] ?? true,
      todoCompleted: map['todoCompleted'] ?? true,
      todoDeleted: map['todoDeleted'] ?? true,
      memberAdded: map['memberAdded'] ?? true,
      memberRemoved: map['memberRemoved'] ?? true,
    );
  }

  @override
  String toString() {
    return 'NotificationSettings(todoCreated: $todoCreated, todoCompleted: $todoCompleted, todoDeleted: $todoDeleted, memberAdded: $memberAdded, memberRemoved: $memberRemoved)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.todoCreated == todoCreated &&
        other.todoCompleted == todoCompleted &&
        other.todoDeleted == todoDeleted &&
        other.memberAdded == memberAdded &&
        other.memberRemoved == memberRemoved;
  }

  @override
  int get hashCode {
    return todoCreated.hashCode ^
        todoCompleted.hashCode ^
        todoDeleted.hashCode ^
        memberAdded.hashCode ^
        memberRemoved.hashCode;
  }
}
