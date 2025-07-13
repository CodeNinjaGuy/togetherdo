class NotificationSettings {
  final bool todoCreated;
  final bool todoCompleted;
  final bool todoDeleted;
  final bool memberAdded;
  final bool memberRemoved;
  final bool chatMessage; // Neue Chat-Benachrichtigung
  final bool shoppingItemCreated;
  final bool shoppingItemPurchased;
  final bool shoppingItemDeleted;

  const NotificationSettings({
    this.todoCreated = true,
    this.todoCompleted = true,
    this.todoDeleted = true,
    this.memberAdded = true,
    this.memberRemoved = true,
    this.chatMessage = true, // Standardmäßig aktiviert
    this.shoppingItemCreated = true,
    this.shoppingItemPurchased = true,
    this.shoppingItemDeleted = true,
  });

  NotificationSettings copyWith({
    bool? todoCreated,
    bool? todoCompleted,
    bool? todoDeleted,
    bool? memberAdded,
    bool? memberRemoved,
    bool? chatMessage,
    bool? shoppingItemCreated,
    bool? shoppingItemPurchased,
    bool? shoppingItemDeleted,
  }) {
    return NotificationSettings(
      todoCreated: todoCreated ?? this.todoCreated,
      todoCompleted: todoCompleted ?? this.todoCompleted,
      todoDeleted: todoDeleted ?? this.todoDeleted,
      memberAdded: memberAdded ?? this.memberAdded,
      memberRemoved: memberRemoved ?? this.memberRemoved,
      chatMessage: chatMessage ?? this.chatMessage,
      shoppingItemCreated: shoppingItemCreated ?? this.shoppingItemCreated,
      shoppingItemPurchased:
          shoppingItemPurchased ?? this.shoppingItemPurchased,
      shoppingItemDeleted: shoppingItemDeleted ?? this.shoppingItemDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'todoCreated': todoCreated,
      'todoCompleted': todoCompleted,
      'todoDeleted': todoDeleted,
      'memberAdded': memberAdded,
      'memberRemoved': memberRemoved,
      'chatMessage': chatMessage,
      'shoppingItemCreated': shoppingItemCreated,
      'shoppingItemPurchased': shoppingItemPurchased,
      'shoppingItemDeleted': shoppingItemDeleted,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      todoCreated: map['todoCreated'] ?? true,
      todoCompleted: map['todoCompleted'] ?? true,
      todoDeleted: map['todoDeleted'] ?? true,
      memberAdded: map['memberAdded'] ?? true,
      memberRemoved: map['memberRemoved'] ?? true,
      chatMessage: map['chatMessage'] ?? true,
      shoppingItemCreated: map['shoppingItemCreated'] ?? true,
      shoppingItemPurchased: map['shoppingItemPurchased'] ?? true,
      shoppingItemDeleted: map['shoppingItemDeleted'] ?? true,
    );
  }

  @override
  String toString() {
    return 'NotificationSettings(todoCreated: $todoCreated, todoCompleted: $todoCompleted, todoDeleted: $todoDeleted, memberAdded: $memberAdded, memberRemoved: $memberRemoved, chatMessage: $chatMessage, shoppingItemCreated: $shoppingItemCreated, shoppingItemPurchased: $shoppingItemPurchased, shoppingItemDeleted: $shoppingItemDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.todoCreated == todoCreated &&
        other.todoCompleted == todoCompleted &&
        other.todoDeleted == todoDeleted &&
        other.memberAdded == memberAdded &&
        other.memberRemoved == memberRemoved &&
        other.chatMessage == chatMessage &&
        other.shoppingItemCreated == shoppingItemCreated &&
        other.shoppingItemPurchased == shoppingItemPurchased &&
        other.shoppingItemDeleted == shoppingItemDeleted;
  }

  @override
  int get hashCode {
    return todoCreated.hashCode ^
        todoCompleted.hashCode ^
        todoDeleted.hashCode ^
        memberAdded.hashCode ^
        memberRemoved.hashCode ^
        chatMessage.hashCode ^
        shoppingItemCreated.hashCode ^
        shoppingItemPurchased.hashCode ^
        shoppingItemDeleted.hashCode;
  }
}
