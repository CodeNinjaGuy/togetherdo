/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Datenmodell des Familienkalenders.
///
/// Firestore: flache Sammlung `termine/{id}` mit Feld `listId` (wie `todos`
/// und `shopping_items`). Begründung: Eine Abfrage über mehrere Listen
/// (`listId in [...]`, Familie + WG gemeinsam), dieselben Regel-Hilfsfunktionen
/// (`isListMember(resource.data.listId)`), kein Collection-Group-Index und die
/// Erinnerungs-Function kann listenübergreifend nach `naechsteErinnerungAm`
/// suchen.
///
/// Zeiten liegen als Timestamp (UTC-Zeitpunkt) im Dokument; `zeitzone` (IANA)
/// hält die Wanduhr-Zeit für Wiederholungen über die Sommerzeit hinweg.
/// Ganztägige Termine beginnen um 0:00 und enden um 0:00 des Folgetags
/// (Ende exklusiv) in `zeitzone`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Letzter Zeitpunkt, bis zu dem eine endlose Wiederholung „sichtbar“ ist
/// (Abfrage `sichtbarBis >= Fensteranfang`).
final DateTime terminUnendlich = DateTime.utc(2200, 1, 1);

/// Art des Termins. `wert` ist der gespeicherte Schlüssel (auch in den Regeln).
enum TerminArt {
  termin('termin'),
  arzt('arzt'),
  arbeit('arbeit'),
  urlaub('urlaub'),
  schule('schule'),
  geburtstag('geburtstag'),
  sonstiges('sonstiges');

  const TerminArt(this.wert);

  final String wert;

  static TerminArt fromWert(Object? wert) {
    for (final a in TerminArt.values) {
      if (a.wert == wert) return a;
    }
    return TerminArt.sonstiges;
  }

  /// Ganztägige „Bänder“ in der Spuren-Ansicht (jemand ist weg / arbeitet).
  bool get istBand => this == TerminArt.urlaub || this == TerminArt.arbeit;

  /// Zählt als abwesend für „wer ist dran“ (Verfügbarkeit).
  bool get istAbwesenheit => this == TerminArt.urlaub;
}

enum WiederholungTyp {
  taeglich('taeglich'),
  woechentlich('woechentlich'),
  monatlich('monatlich'),
  jaehrlich('jaehrlich');

  const WiederholungTyp(this.wert);

  final String wert;

  static WiederholungTyp? fromWert(Object? wert) {
    for (final t in WiederholungTyp.values) {
      if (t.wert == wert) return t;
    }
    return null;
  }
}

/// Wiederholungsregel. `wochentage` nur bei wöchentlich (1 = Mo … 7 = So,
/// wie `DateTime.weekday`). Ende entweder `bisDatum` (einschließlich) oder
/// `anzahl` Vorkommen oder keins (endlos). `ausnahmen` sind übersprungene
/// Tage als `JJJJ-MM-TT` in `zeitzone` des Termins.
class Wiederholung extends Equatable {
  const Wiederholung({
    required this.typ,
    this.intervall = 1,
    this.wochentage = const [],
    this.bisDatum,
    this.anzahl,
    this.ausnahmen = const [],
  });

  final WiederholungTyp typ;
  final int intervall;
  final List<int> wochentage;
  final DateTime? bisDatum;
  final int? anzahl;
  final List<String> ausnahmen;

  bool get endlos => bisDatum == null && anzahl == null;

  static Wiederholung? fromJson(Object? json) {
    if (json is! Map) return null;
    final typ = WiederholungTyp.fromWert(json['typ']);
    if (typ == null) return null;
    return Wiederholung(
      typ: typ,
      intervall: (json['intervall'] as num?)?.toInt().clamp(1, 365) ?? 1,
      wochentage: List<int>.from(
        (json['wochentage'] as List? ?? const []).map((e) => (e as num).toInt()),
      ),
      bisDatum: parseTimestamp(json['bisDatum']),
      anzahl: (json['anzahl'] as num?)?.toInt(),
      ausnahmen: List<String>.from(json['ausnahmen'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toJson() => {
    'typ': typ.wert,
    'intervall': intervall,
    'wochentage': wochentage,
    'bisDatum': bisDatum == null ? null : Timestamp.fromDate(bisDatum!),
    'anzahl': anzahl,
    'ausnahmen': ausnahmen,
  };

  Wiederholung copyWith({
    WiederholungTyp? typ,
    int? intervall,
    List<int>? wochentage,
    DateTime? bisDatum,
    int? anzahl,
    List<String>? ausnahmen,
    bool ohneEnde = false,
  }) => Wiederholung(
    typ: typ ?? this.typ,
    intervall: intervall ?? this.intervall,
    wochentage: wochentage ?? this.wochentage,
    bisDatum: ohneEnde ? null : bisDatum ?? this.bisDatum,
    anzahl: ohneEnde ? null : anzahl ?? this.anzahl,
    ausnahmen: ausnahmen ?? this.ausnahmen,
  );

  @override
  List<Object?> get props => [
    typ,
    intervall,
    wochentage,
    bisDatum,
    anzahl,
    ausnahmen,
  ];
}

DateTime? parseTimestamp(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  return null;
}

/// Ein Termin (Serie oder Einzeltermin) wie in Firestore gespeichert.
class Termin extends Equatable {
  const Termin({
    required this.id,
    required this.listId,
    required this.titel,
    required this.start,
    required this.ende,
    required this.erstelltVon,
    this.art = TerminArt.termin,
    this.personen = const [],
    this.ganztaegig = false,
    this.ort,
    this.notiz,
    this.zeitzone = 'Europe/Vienna',
    this.wiederholung,
    this.erinnerungen = const [],
    this.erstelltAm,
    this.aktualisiertAm,
    this.naechsteErinnerungAm,
    this.letzteErinnerungSchluessel,
  });

  final String id;
  final String listId;
  final String titel;
  final TerminArt art;

  /// Mitglieder-UIDs. Leer = alle in der Liste.
  final List<String> personen;
  final DateTime start;

  /// Ende (exklusiv). Bei Wiederholungen: Ende des ersten Vorkommens.
  final DateTime ende;
  final bool ganztaegig;
  final String? ort;
  final String? notiz;
  final String zeitzone;
  final Wiederholung? wiederholung;

  /// Minuten vor Start (0 = zum Start).
  final List<int> erinnerungen;
  final String erstelltVon;
  final DateTime? erstelltAm;
  final DateTime? aktualisiertAm;

  /// Von der App beim Speichern gesetzt, von der Function fortgeschrieben.
  final DateTime? naechsteErinnerungAm;

  /// Nur die Function schreibt dies (Idempotenz).
  final String? letzteErinnerungSchluessel;

  bool get fuerAlle => personen.isEmpty;
  bool get wiederholt => wiederholung != null;
  Duration get dauer => ende.difference(start);

  bool betrifft(String userId) => fuerAlle || personen.contains(userId);

  factory Termin.fromJson(Map<String, dynamic> json) => Termin(
    id: json['id'] as String,
    listId: json['listId'] as String,
    titel: json['titel'] as String? ?? '',
    art: TerminArt.fromWert(json['art']),
    personen: List<String>.from(json['personen'] as List? ?? const []),
    start: parseTimestamp(json['start']) ?? DateTime.now().toUtc(),
    ende:
        parseTimestamp(json['ende']) ??
        parseTimestamp(json['start']) ??
        DateTime.now().toUtc(),
    ganztaegig: json['ganztaegig'] as bool? ?? false,
    ort: json['ort'] as String?,
    notiz: json['notiz'] as String?,
    zeitzone: json['zeitzone'] as String? ?? 'Europe/Vienna',
    wiederholung: Wiederholung.fromJson(json['wiederholung']),
    erinnerungen: List<int>.from(
      (json['erinnerungen'] as List? ?? const []).map((e) => (e as num).toInt()),
    ),
    erstelltVon: json['erstelltVon'] as String? ?? '',
    erstelltAm: parseTimestamp(json['erstelltAm']),
    aktualisiertAm: parseTimestamp(json['aktualisiertAm']),
    naechsteErinnerungAm: parseTimestamp(json['naechsteErinnerungAm']),
    letzteErinnerungSchluessel: json['letzteErinnerungSchluessel'] as String?,
  );

  /// Felder fürs Speichern. `sichtbarBis` und `naechsteErinnerungAm` werden
  /// vom Repository über die Wiederholungslogik ergänzt; Zeitstempel für
  /// „erstellt/aktualisiert“ setzt das Repository als Serverzeit.
  Map<String, dynamic> toJson() => {
    'id': id,
    'listId': listId,
    'titel': titel,
    'art': art.wert,
    'personen': personen,
    'start': Timestamp.fromDate(start),
    'ende': Timestamp.fromDate(ende),
    'ganztaegig': ganztaegig,
    'ort': ort,
    'notiz': notiz,
    'zeitzone': zeitzone,
    'wiederholung': wiederholung?.toJson(),
    'erinnerungen': erinnerungen,
    'erstelltVon': erstelltVon,
  };

  Termin copyWith({
    String? id,
    String? listId,
    String? titel,
    TerminArt? art,
    List<String>? personen,
    DateTime? start,
    DateTime? ende,
    bool? ganztaegig,
    String? ort,
    String? notiz,
    String? zeitzone,
    Wiederholung? wiederholung,
    bool ohneWiederholung = false,
    List<int>? erinnerungen,
    String? erstelltVon,
    DateTime? erstelltAm,
    DateTime? aktualisiertAm,
    DateTime? naechsteErinnerungAm,
    String? letzteErinnerungSchluessel,
  }) => Termin(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    titel: titel ?? this.titel,
    art: art ?? this.art,
    personen: personen ?? this.personen,
    start: start ?? this.start,
    ende: ende ?? this.ende,
    ganztaegig: ganztaegig ?? this.ganztaegig,
    ort: ort ?? this.ort,
    notiz: notiz ?? this.notiz,
    zeitzone: zeitzone ?? this.zeitzone,
    wiederholung: ohneWiederholung ? null : wiederholung ?? this.wiederholung,
    erinnerungen: erinnerungen ?? this.erinnerungen,
    erstelltVon: erstelltVon ?? this.erstelltVon,
    erstelltAm: erstelltAm ?? this.erstelltAm,
    aktualisiertAm: aktualisiertAm ?? this.aktualisiertAm,
    naechsteErinnerungAm: naechsteErinnerungAm ?? this.naechsteErinnerungAm,
    letzteErinnerungSchluessel:
        letzteErinnerungSchluessel ?? this.letzteErinnerungSchluessel,
  );

  @override
  List<Object?> get props => [
    id,
    listId,
    titel,
    art,
    personen,
    start,
    ende,
    ganztaegig,
    ort,
    notiz,
    zeitzone,
    wiederholung,
    erinnerungen,
    erstelltVon,
    aktualisiertAm,
    naechsteErinnerungAm,
  ];
}

/// Ein konkretes Vorkommen eines Termins (bei Serien: expandiert).
class Vorkommen extends Equatable {
  const Vorkommen({
    required this.termin,
    required this.start,
    required this.ende,
  });

  final Termin termin;
  final DateTime start;
  final DateTime ende;

  String get id => '${termin.id}@${start.toIso8601String()}';
  TerminArt get art => termin.art;
  bool get ganztaegig => termin.ganztaegig;
  Duration get dauer => ende.difference(start);

  bool ueberlappt(DateTime von, DateTime bis) =>
      start.isBefore(bis) && ende.isAfter(von);

  @override
  List<Object?> get props => [termin.id, start, ende];
}
