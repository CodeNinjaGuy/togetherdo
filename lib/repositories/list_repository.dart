import 'dart:math';
import '../models/list_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ListRepository {
  Future<List<ListModel>> getUserLists(String userId);
  Future<ListModel> createList({
    required String name,
    required String ownerId,
    required String ownerName,
    required ListType type,
    bool allowEdit = true,
  });
  Future<ListModel> updateList(ListModel list);
  Future<void> deleteList(String listId, String ownerId);
  Future<void> leaveList(String listId, String userId);
  Future<ListModel?> getListByCode(String code);
  Future<ListModel?> getListById(String listId);
  Stream<ListModel?> getListByIdStream(String listId);
}

class MockListRepository implements ListRepository {
  final List<ListModel> _lists = [];
  final Random _random = Random();

  String _generateCode() {
    const chars = '0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  @override
  Future<List<ListModel>> getUserLists(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return _lists
        .where(
          (list) => list.ownerId == userId || list.memberIds.contains(userId),
        )
        .toList();
  }

  @override
  Future<ListModel> createList({
    required String name,
    required String ownerId,
    required String ownerName,
    required ListType type,
    bool allowEdit = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    String code;
    do {
      code = _generateCode();
    } while (_lists.any((list) => list.shareCode == code));

    final now = DateTime.now();
    final list = ListModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      ownerId: ownerId,
      ownerName: ownerName,
      type: type,
      createdAt: now,
      updatedAt: now,
      isShared: true,
      shareCode: code,
      memberIds: [],
      memberNames: [],
      allowEdit: allowEdit,
    );

    _lists.add(list);
    return list;
  }

  @override
  Future<ListModel> updateList(ListModel list) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final index = _lists.indexWhere((l) => l.id == list.id);
    if (index != -1) {
      final updatedList = list.copyWith(updatedAt: DateTime.now());
      _lists[index] = updatedList;
      return updatedList;
    }

    throw Exception('List not found');
  }

  @override
  Future<void> deleteList(String listId, String ownerId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    _lists.removeWhere((list) => list.id == listId && list.ownerId == ownerId);
  }

  @override
  Future<void> leaveList(String listId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final listIndex = _lists.indexWhere((list) => list.id == listId);
    if (listIndex != -1) {
      final list = _lists[listIndex];
      final memberIndex = list.memberIds.indexOf(userId);
      final updatedMemberIds = list.memberIds
          .where((id) => id != userId)
          .toList();
      final updatedMemberNames = <String>[];
      for (int i = 0; i < list.memberNames.length; i++) {
        if (i != memberIndex) {
          updatedMemberNames.add(list.memberNames[i]);
        }
      }
      _lists[listIndex] = list.copyWith(
        memberIds: updatedMemberIds,
        memberNames: updatedMemberNames,
      );
    }
  }

  @override
  Future<ListModel?> getListByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      return _lists.firstWhere((list) => list.shareCode == code);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ListModel?> getListById(String listId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      return _lists.firstWhere((list) => list.id == listId);
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<ListModel?> getListByIdStream(String listId) {
    // Für Mock-Repository: Simuliere Stream mit Future
    return Stream.fromFuture(getListById(listId));
  }
}

class FirebaseListRepository implements ListRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  String _generateCode() {
    const chars = '0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  @override
  Future<List<ListModel>> getUserLists(String userId) async {
    final query = await _firestore
        .collection('lists')
        .where('allUserIds', arrayContains: userId)
        .get();
    return query.docs.map((doc) => ListModel.fromJson(doc.data())).toList();
  }

  @override
  Future<ListModel> createList({
    required String name,
    required String ownerId,
    required String ownerName,
    required ListType type,
    bool allowEdit = true,
  }) async {
    String code;
    bool exists = true;
    // Eindeutigen Code generieren
    do {
      code = _generateCode();
      final query = await _firestore
          .collection('lists')
          .where('shareCode', isEqualTo: code)
          .get();
      exists = query.docs.isNotEmpty;
    } while (exists);

    final now = DateTime.now();
    final docRef = _firestore.collection('lists').doc();
    final list = ListModel(
      id: docRef.id,
      name: name,
      ownerId: ownerId,
      ownerName: ownerName,
      type: type,
      createdAt: now,
      updatedAt: now,
      isShared: true,
      shareCode: code,
      memberIds: [],
      memberNames: [],
      allowEdit: allowEdit,
    );
    await docRef.set({
      ...list.toJson(),
      'allUserIds': [ownerId],
    });
    return list;
  }

  @override
  Future<ListModel> updateList(ListModel list) async {
    final docRef = _firestore.collection('lists').doc(list.id);
    final updated = list.copyWith(updatedAt: DateTime.now());
    await docRef.update({
      ...updated.toJson(),
      'allUserIds': [updated.ownerId, ...updated.memberIds],
    });
    return updated;
  }

  @override
  Future<void> deleteList(String listId, String ownerId) async {
    final docRef = _firestore.collection('lists').doc(listId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data()!;
    if (data['ownerId'] != ownerId) {
      throw Exception('Nur der Besitzer kann löschen');
    }
    await docRef.delete();
  }

  @override
  Future<void> leaveList(String listId, String userId) async {
    final docRef = _firestore.collection('lists').doc(listId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    if (data['ownerId'] == userId) {
      throw Exception('Der Besitzer kann die Liste nicht verlassen');
    }

    final memberIds = List<String>.from(data['memberIds'] ?? []);
    final memberNames = List<String>.from(data['memberNames'] ?? []);
    if (memberIds.contains(userId)) {
      final memberIndex = memberIds.indexOf(userId);
      memberIds.remove(userId);
      if (memberIndex < memberNames.length) {
        memberNames.removeAt(memberIndex);
      }
      final allUserIds = List<String>.from(data['allUserIds'] ?? []);
      allUserIds.remove(userId);

      await docRef.update({
        'memberIds': memberIds,
        'memberNames': memberNames,
        'allUserIds': allUserIds,
      });
    }
  }

  @override
  Future<ListModel?> getListByCode(String code) async {
    final query = await _firestore
        .collection('lists')
        .where('shareCode', isEqualTo: code)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return ListModel.fromJson(query.docs.first.data());
  }

  @override
  Future<ListModel?> getListById(String listId) async {
    final doc = await _firestore.collection('lists').doc(listId).get();
    if (!doc.exists) return null;
    return ListModel.fromJson(doc.data()!);
  }

  @override
  Stream<ListModel?> getListByIdStream(String listId) {
    return _firestore.collection('lists').doc(listId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      return ListModel.fromJson(snapshot.data()!);
    });
  }
}
