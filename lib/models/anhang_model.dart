/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Anhang (Foto, PDF, Dokument) an einem Termin oder einer Aufgabe.
/// Gemeinsames Modell für Kalender und Aufgaben; Dateien liegen in
/// Firebase Storage, die Beschreibung je Anhang in der Untersammlung
/// `todos/{todoId}/anhaenge/{id}` bzw. `termine/{terminId}/anhaenge/{id}`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Datei an Termin/Aufgabe. Storage-Pfad: `termine/{listId}/{terminId}/{id}`
/// bzw. `todos/{listId}/{todoId}/{id}`; Vorschaubild `…/{id}_vorschau.jpg`.
class Anhang extends Equatable {
  const Anhang({
    required this.id,
    required this.name,
    required this.typ,
    required this.groesse,
    required this.pfad,
    required this.hochgeladenVon,
    required this.hochgeladenAm,
    this.vorschauPfad,
  });

  final String id;
  final String name;

  /// MIME-Typ, z. B. `image/jpeg`, `application/pdf`.
  final String typ;
  final int groesse;
  final String pfad;
  final String? vorschauPfad;
  final String hochgeladenVon;
  final DateTime hochgeladenAm;

  bool get istBild => typ.startsWith('image/');
  bool get istPdf => typ == 'application/pdf';

  factory Anhang.fromJson(Map<String, dynamic> json) => Anhang(
    id: json['id'] as String,
    name: json['name'] as String,
    typ: json['typ'] as String,
    groesse: (json['groesse'] as num).toInt(),
    pfad: json['pfad'] as String,
    vorschauPfad: json['vorschauPfad'] as String?,
    hochgeladenVon: json['hochgeladenVon'] as String,
    hochgeladenAm: _parseTs(json['hochgeladenAm']) ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'typ': typ,
    'groesse': groesse,
    'pfad': pfad,
    'vorschauPfad': vorschauPfad,
    'hochgeladenVon': hochgeladenVon,
    'hochgeladenAm': Timestamp.fromDate(hochgeladenAm),
  };

  @override
  List<Object?> get props => [id, pfad];
}

DateTime? _parseTs(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  return null;
}
