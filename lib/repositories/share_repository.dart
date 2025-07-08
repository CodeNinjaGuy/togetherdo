import 'dart:math';
import '../models/share_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ShareRepository {
  Future<List<ShareModel>> getUserShares(String userId);
  Future<ShareModel> createShare({
    required String ownerId,
    required String ownerName,
    required ShareType type,
    required String listName,
  });
  Future<ShareModel?> joinShare(String code, String userId, String userName);
  Future<void> leaveShare(String shareId, String userId);
  Future<void> deleteShare(String shareId, String ownerId);
  Future<ShareModel?> getShareByCode(String code);
}

class MockShareRepository implements ShareRepository {
  final List<ShareModel> _shares = [];
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
  Future<List<ShareModel>> getUserShares(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return _shares
        .where(
          (share) =>
              share.ownerId == userId || share.memberIds.contains(userId),
        )
        .toList();
  }

  @override
  Future<ShareModel> createShare({
    required String ownerId,
    required String ownerName,
    required ShareType type,
    required String listName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    String code;
    do {
      code = _generateCode();
    } while (_shares.any((share) => share.code == code));

    final share = ShareModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      code: code,
      ownerId: ownerId,
      ownerName: ownerName,
      type: type,
      listName: listName,
      createdAt: DateTime.now(),
      memberIds: [],
    );

    _shares.add(share);
    return share;
  }

  @override
  Future<ShareModel?> joinShare(
    String code,
    String userId,
    String userName,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final shareIndex = _shares.indexWhere((share) => share.code == code);
    if (shareIndex == -1) {
      return null; // Code nicht gefunden
    }

    final share = _shares[shareIndex];

    // Prüfe ob Benutzer bereits Mitglied ist oder der Owner
    if (share.ownerId == userId || share.memberIds.contains(userId)) {
      return null; // Bereits Mitglied
    }

    // Füge Benutzer zur Liste hinzu
    final updatedShare = share.copyWith(
      memberIds: [...share.memberIds, userId],
    );

    _shares[shareIndex] = updatedShare;
    return updatedShare;
  }

  @override
  Future<void> leaveShare(String shareId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final shareIndex = _shares.indexWhere((share) => share.id == shareId);
    if (shareIndex == -1) return;

    final share = _shares[shareIndex];
    final updatedMemberIds = share.memberIds
        .where((id) => id != userId)
        .toList();

    _shares[shareIndex] = share.copyWith(memberIds: updatedMemberIds);
  }

  @override
  Future<void> deleteShare(String shareId, String ownerId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    _shares.removeWhere(
      (share) => share.id == shareId && share.ownerId == ownerId,
    );
  }

  @override
  Future<ShareModel?> getShareByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      return _shares.firstWhere((share) => share.code == code);
    } catch (e) {
      return null;
    }
  }
}

class FirebaseShareRepository implements ShareRepository {
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
  Future<List<ShareModel>> getUserShares(String userId) async {
    final query = await _firestore
        .collection('shares')
        .where('allUserIds', arrayContains: userId)
        .get();
    return query.docs.map((doc) => ShareModel.fromJson(doc.data())).toList();
  }

  @override
  Future<ShareModel> createShare({
    required String ownerId,
    required String ownerName,
    required ShareType type,
    required String listName,
  }) async {
    String code;
    bool exists = true;
    // Eindeutigen Code generieren
    do {
      code = _generateCode();
      final query = await _firestore
          .collection('shares')
          .where('code', isEqualTo: code)
          .get();
      exists = query.docs.isNotEmpty;
    } while (exists);

    final docRef = _firestore.collection('shares').doc();
    final share = ShareModel(
      id: docRef.id,
      code: code,
      ownerId: ownerId,
      ownerName: ownerName,
      type: type,
      listName: listName,
      createdAt: DateTime.now(),
      memberIds: [],
    );
    await docRef.set({
      ...share.toJson(),
      'allUserIds': [ownerId],
    });
    return share;
  }

  @override
  Future<ShareModel?> joinShare(
    String code,
    String userId,
    String userName,
  ) async {
    final query = await _firestore
        .collection('shares')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final share = ShareModel.fromJson(doc.data());

    // Prüfe ob Benutzer bereits Mitglied ist oder der Owner
    if (share.ownerId == userId || share.memberIds.contains(userId)) {
      return null; // Bereits Mitglied
    }

    // Füge Benutzer zur Liste hinzu
    final updatedShare = share.copyWith(
      memberIds: [...share.memberIds, userId],
    );

    await doc.reference.update({
      ...updatedShare.toJson(),
      'allUserIds': [updatedShare.ownerId, ...updatedShare.memberIds],
    });

    return updatedShare;
  }

  @override
  Future<void> leaveShare(String shareId, String userId) async {
    final docRef = _firestore.collection('shares').doc(shareId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final share = ShareModel.fromJson(doc.data()!);
    final updatedMemberIds = share.memberIds
        .where((id) => id != userId)
        .toList();

    final updatedShare = share.copyWith(memberIds: updatedMemberIds);
    await docRef.update({
      ...updatedShare.toJson(),
      'allUserIds': [updatedShare.ownerId, ...updatedShare.memberIds],
    });
  }

  @override
  Future<void> deleteShare(String shareId, String ownerId) async {
    final docRef = _firestore.collection('shares').doc(shareId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    if (data['ownerId'] != ownerId) {
      throw Exception('Nur der Besitzer kann löschen');
    }

    await docRef.delete();
  }

  @override
  Future<ShareModel?> getShareByCode(String code) async {
    final query = await _firestore
        .collection('shares')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return ShareModel.fromJson(query.docs.first.data());
  }
}
