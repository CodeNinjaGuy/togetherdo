/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:equatable/equatable.dart';

import 'list_model.dart';

/// Was man vor dem Beitritt über eine Liste erfährt (Function
/// `previewListByCode`): keine IDs, keine Mitgliedernamen.
class ListPreview extends Equatable {
  final String name;
  final ListType type;
  final String ownerName;
  final int memberCount;
  final String shareCode;
  final bool isMember;

  const ListPreview({
    required this.name,
    required this.type,
    required this.ownerName,
    required this.memberCount,
    required this.shareCode,
    this.isMember = false,
  });

  factory ListPreview.fromJson(Map<String, dynamic> json) {
    return ListPreview(
      name: json['name'] as String? ?? '',
      type: json['type'] == 'shopping' ? ListType.shopping : ListType.todo,
      ownerName: json['ownerName'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
      shareCode: json['shareCode'] as String? ?? '',
      isMember: json['isMember'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    name,
    type,
    ownerName,
    memberCount,
    shareCode,
    isMember,
  ];
}

/// Warum Vorschau oder Beitritt per Code nicht geklappt hat.
enum ListCodeError { notFound, alreadyMember, tooManyAttempts, invalid }

class ListCodeException implements Exception {
  final ListCodeError error;

  const ListCodeException(this.error);

  @override
  String toString() => 'ListCodeException($error)';
}
