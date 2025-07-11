import '../models/chat_message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ChatRepository {
  Stream<List<ChatMessageModel>> getMessages(String todoId);
  Future<void> sendMessage(ChatMessageModel message);
  Future<void> deleteAllMessages(String todoId);
  Stream<int> getUnreadCount(String todoId, String currentUserId);
  Future<void> markAsRead(String todoId, String currentUserId);
}

class FirestoreChatRepository implements ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<ChatMessageModel>> getMessages(String todoId) {
    return _firestore
        .collection('todos')
        .doc(todoId)
        .collection('chatMessages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromJson(doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> sendMessage(ChatMessageModel message) async {
    final docRef = _firestore
        .collection('todos')
        .doc(message.todoId)
        .collection('chatMessages')
        .doc(message.id);
    await docRef.set(message.toJson());
  }

  @override
  Future<void> deleteAllMessages(String todoId) async {
    final collection = _firestore
        .collection('todos')
        .doc(todoId)
        .collection('chatMessages');
    final batch = _firestore.batch();
    final snapshots = await collection.get();
    for (final doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Stream<int> getUnreadCount(String todoId, String currentUserId) {
    return _firestore
        .collection('todos')
        .doc(todoId)
        .collection('chatMessages')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromJson(doc.data()))
              .where(
                (message) => message.userId != currentUserId && !message.isRead,
              )
              .length,
        );
  }

  @override
  Future<void> markAsRead(String todoId, String currentUserId) async {
    final collection = _firestore
        .collection('todos')
        .doc(todoId)
        .collection('chatMessages');

    final batch = _firestore.batch();
    final allMessages = await collection.get();

    for (final doc in allMessages.docs) {
      final message = ChatMessageModel.fromJson(doc.data());
      if (message.userId != currentUserId && !message.isRead) {
        batch.update(doc.reference, {'isRead': true});
      }
    }

    await batch.commit();
  }
}
