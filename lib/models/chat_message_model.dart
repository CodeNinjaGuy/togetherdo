import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  final String id;
  final String todoId;
  final String userId;
  final String userName;
  final String message;
  final DateTime timestamp;

  const ChatMessageModel({
    required this.id,
    required this.todoId,
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      todoId: json['todoId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'todoId': todoId,
      'userId': userId,
      'userName': userName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, todoId, userId, userName, message, timestamp];
}
