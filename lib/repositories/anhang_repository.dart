/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Beschreibungen der Anhänge (Firestore) für Aufgaben und Termine.
///
/// Beide Arten speichern gleich: je Anhang ein Dokument in der
/// Untersammlung `anhaenge` des Eintrags (`todos/{id}/anhaenge/{anhangId}`
/// bzw. `termine/{id}/anhaenge/{anhangId}`). Die Dateien selbst verwaltet
/// der `AttachmentService` unter [AnhangZiel.storagePfad].
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/anhang_model.dart';

/// Sammlung, zu der ein Anhang gehört.
enum AnhangSammlung {
  aufgabe('todos'),
  termin('termine');

  const AnhangSammlung(this.name);

  /// Name der Firestore-Sammlung und erster Teil des Storage-Pfads.
  final String name;
}

/// Eintrag, an dem Anhänge hängen.
class AnhangZiel {
  const AnhangZiel({
    required this.sammlung,
    required this.listId,
    required this.eintragId,
  });

  const AnhangZiel.aufgabe({required this.listId, required String todoId})
    : sammlung = AnhangSammlung.aufgabe,
      eintragId = todoId;

  const AnhangZiel.termin({required this.listId, required String terminId})
    : sammlung = AnhangSammlung.termin,
      eintragId = terminId;

  final AnhangSammlung sammlung;
  final String listId;
  final String eintragId;

  /// Basispfad in Storage, z. B. `todos/{listId}/{todoId}`.
  String get storagePfad => '${sammlung.name}/$listId/$eintragId';

  @override
  bool operator ==(Object other) =>
      other is AnhangZiel &&
      other.sammlung == sammlung &&
      other.listId == listId &&
      other.eintragId == eintragId;

  @override
  int get hashCode => Object.hash(sammlung, listId, eintragId);

  @override
  String toString() => 'AnhangZiel($storagePfad)';
}

abstract class AnhangRepository {
  /// Anhänge eines Eintrags, älteste zuerst.
  Stream<List<Anhang>> beobachten(AnhangZiel ziel);

  /// Anzahl der Anhänge (Kennzeichen in Listenzeilen).
  Stream<int> anzahl(AnhangZiel ziel) =>
      beobachten(ziel).map((l) => l.length).distinct();

  Future<void> hinzufuegen(AnhangZiel ziel, Anhang anhang);

  Future<void> entfernen(AnhangZiel ziel, String anhangId);
}

class FirestoreAnhangRepository extends AnhangRepository {
  FirestoreAnhangRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(AnhangZiel z) =>
      _db.collection(z.sammlung.name).doc(z.eintragId).collection('anhaenge');

  @override
  Stream<List<Anhang>> beobachten(AnhangZiel ziel) => _col(ziel)
      .orderBy('hochgeladenAm')
      .snapshots()
      .map((s) => s.docs.map((d) => Anhang.fromJson(d.data())).toList());

  @override
  Future<void> hinzufuegen(AnhangZiel ziel, Anhang anhang) =>
      _col(ziel).doc(anhang.id).set(anhang.toJson());

  @override
  Future<void> entfernen(AnhangZiel ziel, String anhangId) =>
      _col(ziel).doc(anhangId).delete();
}

/// Für Tests, Demo und Design-Galerie: alles im Speicher.
class MockAnhangRepository extends AnhangRepository {
  MockAnhangRepository([Map<AnhangZiel, List<Anhang>>? start]) {
    start?.forEach((z, l) => _daten[z] = [...l]);
  }

  final Map<AnhangZiel, List<Anhang>> _daten = {};
  final Map<AnhangZiel, StreamController<List<Anhang>>> _strom = {};

  List<Anhang> von(AnhangZiel ziel) => List.unmodifiable(_daten[ziel] ?? []);

  StreamController<List<Anhang>> _c(AnhangZiel z) =>
      _strom.putIfAbsent(z, StreamController<List<Anhang>>.broadcast);

  void _melden(AnhangZiel z) => _c(z).add(von(z));

  @override
  Stream<List<Anhang>> beobachten(AnhangZiel ziel) async* {
    yield von(ziel);
    yield* _c(ziel).stream;
  }

  @override
  Future<void> hinzufuegen(AnhangZiel ziel, Anhang anhang) async {
    (_daten[ziel] ??= []).add(anhang);
    _melden(ziel);
  }

  @override
  Future<void> entfernen(AnhangZiel ziel, String anhangId) async {
    _daten[ziel]?.removeWhere((a) => a.id == anhangId);
    _melden(ziel);
  }
}
