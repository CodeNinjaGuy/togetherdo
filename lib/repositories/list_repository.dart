/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/list_model.dart';
import '../models/list_preview.dart';
import '../services/functions_client.dart';

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

  /// Vorschau zu einem 6-stelligen Code. Wirft [ListCodeException].
  Future<ListPreview> previewListByCode(String code);

  /// Tritt der Liste zum Code bei. Wirft [ListCodeException].
  Future<ListModel> joinListByCode({
    required String code,
    required String userName,
  });
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

  ListModel _byCode(String code) {
    for (final list in _lists) {
      if (list.shareCode == code) return list;
    }
    throw const ListCodeException(ListCodeError.notFound);
  }

  @override
  Future<ListPreview> previewListByCode(String code) async {
    final list = _byCode(code);
    return ListPreview(
      name: list.name,
      type: list.type,
      ownerName: list.ownerName,
      memberCount: list.memberCount,
      shareCode: code,
    );
  }

  @override
  Future<ListModel> joinListByCode({
    required String code,
    required String userName,
  }) async {
    final list = _byCode(code);
    final joined = list.copyWith(
      memberIds: [...list.memberIds, 'mock-user'],
      memberNames: [...list.memberNames, userName],
    );
    await updateList(joined);
    return joined;
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

  @override
  Future<List<ListModel>> getUserLists(String userId) async {
    final query = await _firestore
        .collection('lists')
        .where('allUserIds', arrayContains: userId)
        .get();
    return query.docs.map((doc) => ListModel.fromJson(doc.data())).toList();
  }

  /// Anlegen über die Function `createList`: Sie vergibt einen eindeutigen
  /// Code (die Regeln verbieten Clients das Suchen nach Codes).
  @override
  Future<ListModel> createList({
    required String name,
    required String ownerId,
    required String ownerName,
    required ListType type,
    bool allowEdit = true,
  }) async {
    final data = await callFunction('createList', {
      'name': name,
      'type': type.name,
      'allowEdit': allowEdit,
      'ownerName': ownerName,
    });
    return ListModel.fromJson(data);
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
    final data = doc.data();
    if (data == null) {
      throw Exception('Listendaten konnten nicht geladen werden!');
    }
    if (data['ownerId'] != ownerId) {
      throw Exception('owner_cannot_delete');
    }
    await docRef.delete();
  }

  @override
  Future<void> leaveList(String listId, String userId) async {
    if (listId.isEmpty || userId.isEmpty) {
      throw Exception('Listen-ID oder User-ID ist nicht gesetzt!');
    }
    final docRef = _firestore.collection('lists').doc(listId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data();
    if (data == null) {
      throw Exception('Listendaten konnten nicht geladen werden!');
    }
    if (data['ownerId'] == userId) {
      throw Exception('owner_cannot_leave');
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
  Future<ListPreview> previewListByCode(String code) async {
    try {
      final data = await callFunction('previewListByCode', {'code': code});
      return ListPreview.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      throw _codeError(e);
    }
  }

  @override
  Future<ListModel> joinListByCode({
    required String code,
    required String userName,
  }) async {
    try {
      final data = await callFunction('joinListByCode', {
        'code': code,
        'userName': userName,
      });
      return ListModel.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      throw _codeError(e);
    }
  }

  Exception _codeError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
        return const ListCodeException(ListCodeError.notFound);
      case 'already-exists':
        return const ListCodeException(ListCodeError.alreadyMember);
      case 'resource-exhausted':
        return const ListCodeException(ListCodeError.tooManyAttempts);
      case 'invalid-argument':
        return const ListCodeException(ListCodeError.invalid);
      default:
        return e;
    }
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
