/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Zugriff auf `termine` in Firestore (flache Sammlung mit `listId`) und
/// lesender Zugriff auf Aufgaben mit Fälligkeit. Dazu eine Speicher-Fassung
/// für Tests und den Demo-Einstieg.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../models/todo_model.dart';
import '../logic/wiederholung.dart';
import '../models/termin.dart';

abstract class TerminRepository {
  /// Alle Termine der Listen, deren Sichtbarkeit nicht vor `ab` endet.
  /// Serien werden hier nicht expandiert (macht `vorkommenIm`).
  Stream<List<Termin>> beobachten(List<String> listIds, {required DateTime ab});

  /// Aufgaben mit Fälligkeit (nur lesen; Termine werden nie in `todos`
  /// geschrieben).
  Stream<List<TodoModel>> faelligeAufgaben(List<String> listIds);

  Future<void> anlegen(Termin t);

  Future<void> aktualisieren(Termin t);

  Future<void> loeschen(String id);

  /// Nur das Feld `anhaenge` ändern (jedes Mitglied darf eigene hinzufügen).
  Future<void> anhaengeSetzen(String id, List<Anhang> anhaenge);

  String neueId();
}

/// Firestore-Fassung. Abfragen: `listId in […]` (Blöcke bis 30) und
/// `sichtbarBis >= ab`, sortiert nach `sichtbarBis` – braucht den Index
/// (listId ASC, sichtbarBis ASC) aus `firestore.indexes.json`.
class FirebaseTerminRepository implements TerminRepository {
  FirebaseTerminRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _termine =>
      _db.collection('termine');

  @override
  String neueId() => _uuid.v4();

  static List<List<String>> _bloecke(List<String> ids, [int groesse = 30]) {
    final out = <List<String>>[];
    for (var i = 0; i < ids.length; i += groesse) {
      out.add(ids.sublist(i, (i + groesse).clamp(0, ids.length)));
    }
    return out;
  }

  /// Mehrere Teilabfragen zu einem Strom zusammenführen (jede Änderung
  /// liefert den Gesamtstand).
  static Stream<List<T>> _zusammen<T>(List<Stream<List<T>>> quellen) {
    if (quellen.isEmpty) return Stream.value(const []);
    if (quellen.length == 1) return quellen.first;
    final controller = StreamController<List<T>>();
    final stand = List<List<T>?>.filled(quellen.length, null);
    final subs = <StreamSubscription<List<T>>>[];
    void emit() {
      if (stand.any((s) => s == null)) return;
      controller.add([for (final s in stand) ...s!]);
    }
    for (var i = 0; i < quellen.length; i++) {
      subs.add(
        quellen[i].listen(
          (v) {
            stand[i] = v;
            emit();
          },
          onError: controller.addError,
        ),
      );
    }
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }

  @override
  Stream<List<Termin>> beobachten(List<String> listIds, {required DateTime ab}) {
    if (listIds.isEmpty) return Stream.value(const []);
    final quellen = _bloecke(listIds).map(
      (block) => _termine
          .where('listId', whereIn: block)
          .where('sichtbarBis', isGreaterThanOrEqualTo: Timestamp.fromDate(ab))
          .orderBy('sichtbarBis')
          .snapshots()
          .map((s) => s.docs.map((d) => Termin.fromJson(d.data())).toList()),
    );
    return _zusammen(quellen.toList());
  }

  @override
  Stream<List<TodoModel>> faelligeAufgaben(List<String> listIds) {
    if (listIds.isEmpty) return Stream.value(const []);
    final quellen = _bloecke(listIds).map(
      (block) => _db
          .collection('todos')
          .where('listId', whereIn: block)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => TodoModel.fromJson(d.data()))
                .where((t) => t.dueDate != null)
                .toList(),
          ),
    );
    return _zusammen(quellen.toList());
  }

  Map<String, dynamic> _mitAbgeleitet(Termin t) {
    final abgeleitet = abgeleiteteFelder(t);
    return {
      ...t.toJson(),
      'sichtbarBis': Timestamp.fromDate(abgeleitet['sichtbarBis'] as DateTime),
      'naechsteErinnerungAm': abgeleitet['naechsteErinnerungAm'] == null
          ? null
          : Timestamp.fromDate(abgeleitet['naechsteErinnerungAm'] as DateTime),
      'aktualisiertAm': FieldValue.serverTimestamp(),
    };
  }

  @override
  Future<void> anlegen(Termin t) => _termine.doc(t.id).set({
    ..._mitAbgeleitet(t),
    'erstelltAm': FieldValue.serverTimestamp(),
    'letzteErinnerungSchluessel': null,
  });

  @override
  Future<void> aktualisieren(Termin t) {
    final daten = _mitAbgeleitet(t)
      ..remove('erstelltVon')
      ..remove('id')
      ..remove('listId');
    return _termine.doc(t.id).update(daten);
  }

  @override
  Future<void> loeschen(String id) => _termine.doc(id).delete();

  @override
  Future<void> anhaengeSetzen(String id, List<Anhang> anhaenge) =>
      _termine.doc(id).update({
        'anhaenge': anhaenge.map((a) => a.toJson()).toList(),
        'aktualisiertAm': FieldValue.serverTimestamp(),
      });
}

/// Speicher-Fassung für Tests und den Demo-Einstieg ohne Firebase.
class SpeicherTerminRepository implements TerminRepository {
  SpeicherTerminRepository({List<Termin>? termine, List<TodoModel>? aufgaben})
    : _termine = {for (final t in termine ?? const []) t.id: t},
      _aufgaben = aufgaben ?? [];

  final Map<String, Termin> _termine;
  final List<TodoModel> _aufgaben;
  final _controller = StreamController<void>.broadcast();
  var _zaehler = 0;

  List<Termin> get alle => _termine.values.toList();

  void _melden() => _controller.add(null);

  @override
  String neueId() => 'termin-${++_zaehler}';

  @override
  Stream<List<Termin>> beobachten(List<String> listIds, {required DateTime ab}) {
    List<Termin> stand() => _termine.values
        .where((t) => listIds.contains(t.listId))
        .where((t) => !sichtbarBis(t).isBefore(ab))
        .toList();
    return Stream<List<Termin>>.multi((c) {
      c.add(stand());
      final sub = _controller.stream.listen((_) => c.add(stand()));
      c.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<TodoModel>> faelligeAufgaben(List<String> listIds) =>
      Stream.value(
        _aufgaben
            .where((t) => listIds.contains(t.listId) && t.dueDate != null)
            .toList(),
      );

  @override
  Future<void> anlegen(Termin t) async {
    _termine[t.id] = t.copyWith(
      erstelltAm: DateTime.now().toUtc(),
      aktualisiertAm: DateTime.now().toUtc(),
    );
    _melden();
  }

  @override
  Future<void> aktualisieren(Termin t) async {
    _termine[t.id] = t.copyWith(aktualisiertAm: DateTime.now().toUtc());
    _melden();
  }

  @override
  Future<void> loeschen(String id) async {
    _termine.remove(id);
    _melden();
  }

  @override
  Future<void> anhaengeSetzen(String id, List<Anhang> anhaenge) async {
    final t = _termine[id];
    if (t != null) _termine[id] = t.copyWith(anhaenge: anhaenge);
    _melden();
  }
}
