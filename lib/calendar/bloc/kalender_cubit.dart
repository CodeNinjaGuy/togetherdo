/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Zustand des Kalenders: Listen, Termine, Aufgaben-Fälligkeiten, Filter,
/// gewählter Tag und Ansicht. Ein Cubit genügt – alle Änderungen sind kleine,
/// direkte Schritte.
library;

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/list_model.dart';
import '../../models/todo_model.dart';
import '../../repositories/list_repository.dart';
import '../logic/konflikte.dart';
import '../logic/wiederholung.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../repositories/termin_repository.dart';

enum KalenderAnsicht { spuren, agenda, monat, jahr }

/// Person im Kalender (aus den Mitgliedern aller aktiven Listen).
class Mitglied extends Equatable {
  const Mitglied({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

class KalenderZustand extends Equatable {
  const KalenderZustand({
    required this.userId,
    required this.fokus,
    this.listen = const [],
    this.aktiveListen = const {},
    this.termine = const [],
    this.aufgaben = const [],
    this.personenFilter = const {},
    this.artenFilter = const {},
    this.ansicht = KalenderAnsicht.spuren,
    this.laedt = true,
    this.fehler,
    this.zeitzone = 'Europe/Vienna',
    this.feiertagsRegion,
  });

  final String userId;
  final List<ListModel> listen;
  final Set<String> aktiveListen;
  final List<Termin> termine;
  final List<TodoModel> aufgaben;

  /// Leer = alle Personen.
  final Set<String> personenFilter;

  /// Leer = alle Arten.
  final Set<TerminArt> artenFilter;

  /// Gewählter Tag (reiner Tag, UTC-Mitternacht).
  final DateTime fokus;
  final KalenderAnsicht ansicht;
  final bool laedt;
  final String? fehler;
  final String zeitzone;

  /// Region für Feiertage/Ferien im Jahresüberblick, z. B. `AT-9` (Wien),
  /// `DE-BY`; `null` = keine Feiertage anzeigen.
  final String? feiertagsRegion;

  List<ListModel> get aktiveListenModelle =>
      listen.where((l) => aktiveListen.contains(l.id)).toList();

  /// Alle Personen der aktiven Listen, Besitzer zuerst, ohne Doppelte.
  List<Mitglied> get mitglieder {
    final gesehen = <String>{};
    final out = <Mitglied>[];
    for (final l in aktiveListenModelle) {
      if (gesehen.add(l.ownerId)) {
        out.add(Mitglied(id: l.ownerId, name: l.ownerName));
      }
      for (var i = 0; i < l.memberIds.length; i++) {
        final id = l.memberIds[i];
        if (gesehen.add(id)) {
          out.add(
            Mitglied(
              id: id,
              name: i < l.memberNames.length ? l.memberNames[i] : '?',
            ),
          );
        }
      }
    }
    // Ich selbst zuerst.
    out.sort((a, b) {
      if (a.id == userId) return -1;
      if (b.id == userId) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  /// Mitglieder, die der Personenfilter zulässt.
  List<Mitglied> get sichtbareMitglieder => personenFilter.isEmpty
      ? mitglieder
      : mitglieder.where((m) => personenFilter.contains(m.id)).toList();

  Mitglied? mitglied(String id) {
    for (final m in mitglieder) {
      if (m.id == id) return m;
    }
    return null;
  }

  String nameVon(String id) => mitglied(id)?.name ?? '?';

  List<String> mitgliederIdsDerListe(String listId) {
    for (final l in listen) {
      if (l.id == listId) return [l.ownerId, ...l.memberIds];
    }
    return const [];
  }

  /// Besitzer der Liste oder Mitglied mit Bearbeitungsrecht (z. B. für
  /// das Löschen fremder Anhänge, wie in den Regeln).
  bool darfListeBearbeiten(String listId) {
    for (final l in listen) {
      if (l.id == listId) {
        return l.ownerId == userId ||
            (l.memberIds.contains(userId) && l.allowEdit);
      }
    }
    return false;
  }

  bool darfBearbeiten(Termin t) {
    if (t.erstelltVon == userId) return true;
    for (final l in listen) {
      if (l.id == t.listId) {
        return l.ownerId == userId ||
            (l.memberIds.contains(userId) && l.allowEdit);
      }
    }
    return false;
  }

  /// Termine nach Listen-, Personen- und Artfilter.
  List<Termin> get gefilterteTermine => termine.where((t) {
    if (!aktiveListen.contains(t.listId)) return false;
    if (artenFilter.isNotEmpty && !artenFilter.contains(t.art)) return false;
    if (personenFilter.isNotEmpty) {
      if (t.fuerAlle) {
        final ids = mitgliederIdsDerListe(t.listId);
        if (!ids.any(personenFilter.contains)) return false;
      } else if (!t.personen.any(personenFilter.contains)) {
        return false;
      }
    }
    return true;
  }).toList();

  /// Konkrete Vorkommen im Fenster, nach Start sortiert.
  List<Vorkommen> vorkommen(DateTime von, DateTime bis) {
    final out = <Vorkommen>[];
    for (final t in gefilterteTermine) {
      out.addAll(vorkommenIm(t, von, bis));
    }
    out.sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.ende.compareTo(b.ende);
    });
    return out;
  }

  /// Aufgaben mit Fälligkeit im Fenster (nur lesend, sichtbar in Agenda
  /// und Monat).
  List<TodoModel> aufgabenIm(DateTime von, DateTime bis) => aufgaben
      .where((a) => aktiveListen.contains(a.listId))
      .where((a) => a.dueDate != null)
      .where((a) {
        final d = a.dueDate!.toUtc();
        return !d.isBefore(von) && d.isBefore(bis);
      })
      .toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  KalenderZustand copyWith({
    List<ListModel>? listen,
    Set<String>? aktiveListen,
    List<Termin>? termine,
    List<TodoModel>? aufgaben,
    Set<String>? personenFilter,
    Set<TerminArt>? artenFilter,
    DateTime? fokus,
    KalenderAnsicht? ansicht,
    bool? laedt,
    String? fehler,
    bool fehlerLoeschen = false,
    String? zeitzone,
    String? feiertagsRegion,
    bool feiertagsRegionLoeschen = false,
  }) => KalenderZustand(
    userId: userId,
    listen: listen ?? this.listen,
    aktiveListen: aktiveListen ?? this.aktiveListen,
    termine: termine ?? this.termine,
    aufgaben: aufgaben ?? this.aufgaben,
    personenFilter: personenFilter ?? this.personenFilter,
    artenFilter: artenFilter ?? this.artenFilter,
    fokus: fokus ?? this.fokus,
    ansicht: ansicht ?? this.ansicht,
    laedt: laedt ?? this.laedt,
    fehler: fehlerLoeschen ? null : fehler ?? this.fehler,
    zeitzone: zeitzone ?? this.zeitzone,
    feiertagsRegion: feiertagsRegionLoeschen
        ? null
        : feiertagsRegion ?? this.feiertagsRegion,
  );

  @override
  List<Object?> get props => [
    userId,
    listen,
    aktiveListen,
    termine,
    aufgaben,
    personenFilter,
    artenFilter,
    fokus,
    ansicht,
    laedt,
    fehler,
    zeitzone,
    feiertagsRegion,
  ];
}

class KalenderCubit extends Cubit<KalenderZustand> {
  KalenderCubit({
    required this.userId,
    required TerminRepository termine,
    required ListRepository listen,
    String? zeitzone,
    DateTime? heute,
    String? vorgewaehlteListe,
    KalenderAnsicht ansicht = KalenderAnsicht.spuren,
  }) : _termine = termine,
       _listen = listen,
       _vorgewaehlteListe = vorgewaehlteListe,
       super(
         KalenderZustand(
           userId: userId,
           fokus: nurTag(heute ?? DateTime.now()),
           zeitzone: zeitzone ?? standardZeitzone(),
           ansicht: ansicht,
         ),
       );

  final String userId;
  final TerminRepository _termine;
  final ListRepository _listen;
  final String? _vorgewaehlteListe;
  StreamSubscription<List<Termin>>? _terminSub;
  StreamSubscription<List<TodoModel>>? _aufgabenSub;

  /// Listen laden und Termine beobachten.
  Future<void> starten() async {
    try {
      final listen = await _listen.getUserLists(userId);
      listen.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final aktive = _vorgewaehlteListe != null &&
              listen.any((l) => l.id == _vorgewaehlteListe)
          ? {_vorgewaehlteListe}
          : listen.map((l) => l.id).toSet();
      emit(state.copyWith(listen: listen, aktiveListen: aktive, fehlerLoeschen: true));
      _abonnieren(listen.map((l) => l.id).toList());
    } catch (e) {
      emit(state.copyWith(laedt: false, fehler: e.toString()));
    }
  }

  void _abonnieren(List<String> alleListen) {
    _terminSub?.cancel();
    _aufgabenSub?.cancel();
    // Ein Jahr zurück reicht für Monats- und Wochenansichten; Serien ohne
    // Ende sind über `sichtbarBis` immer dabei.
    final ab = DateTime.now().toUtc().subtract(const Duration(days: 400));
    _terminSub = _termine
        .beobachten(alleListen, ab: ab)
        .listen(
          (t) => emit(state.copyWith(termine: t, laedt: false, fehlerLoeschen: true)),
          onError: (Object e) =>
              emit(state.copyWith(laedt: false, fehler: e.toString())),
        );
    _aufgabenSub = _termine
        .faelligeAufgaben(alleListen)
        .listen((a) => emit(state.copyWith(aufgaben: a)), onError: (_) {});
  }

  void ansichtSetzen(KalenderAnsicht a) => emit(state.copyWith(ansicht: a));

  void fokusSetzen(DateTime tag) => emit(state.copyWith(fokus: nurTag(tag)));

  void heute() => fokusSetzen(DateTime.now());

  void listeUmschalten(String listId) {
    final neu = {...state.aktiveListen};
    if (neu.contains(listId)) {
      if (neu.length == 1) return; // mindestens eine Liste bleibt sichtbar
      neu.remove(listId);
    } else {
      neu.add(listId);
    }
    emit(state.copyWith(aktiveListen: neu));
  }

  void personUmschalten(String id) {
    final neu = {...state.personenFilter};
    if (!neu.remove(id)) neu.add(id);
    emit(state.copyWith(personenFilter: neu));
  }

  void personenFilterLeeren() => emit(state.copyWith(personenFilter: {}));

  void artUmschalten(TerminArt art) {
    final neu = {...state.artenFilter};
    if (!neu.remove(art)) neu.add(art);
    emit(state.copyWith(artenFilter: neu));
  }

  void artenFilterLeeren() => emit(state.copyWith(artenFilter: {}));

  void feiertagsRegionSetzen(String? region) => emit(
    region == null
        ? state.copyWith(feiertagsRegionLoeschen: true)
        : state.copyWith(feiertagsRegion: region),
  );

  String neueId() => _termine.neueId();

  /// Konflikte gegen den aktuellen Stand (nicht nur gefilterte Termine).
  List<Konflikt> konflikte(Termin neu) => findeKonflikte(
    neu: neu,
    vorhandene: state.termine.where((t) => t.listId == neu.listId),
    mitglieder: state.mitgliederIdsDerListe(neu.listId),
  );

  Future<void> speichern(Termin t) async {
    final vorhanden = state.termine.any((x) => x.id == t.id);
    if (vorhanden) {
      await _termine.aktualisieren(t);
    } else {
      await _termine.anlegen(t.copyWith(erstelltVon: userId));
    }
  }

  Future<void> loeschen(Termin t) => _termine.loeschen(t.id);

  /// Ein einzelnes Vorkommen einer Serie überspringen (Ausnahme eintragen).
  Future<void> vorkommenUeberspringen(Vorkommen v) async {
    final w = v.termin.wiederholung;
    if (w == null) return loeschen(v.termin);
    final tag = tagSchluessel(v.start, v.termin.zeitzone);
    if (w.ausnahmen.contains(tag)) return;
    await _termine.aktualisieren(
      v.termin.copyWith(
        wiederholung: w.copyWith(ausnahmen: [...w.ausnahmen, tag]),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _terminSub?.cancel();
    await _aufgabenSub?.cancel();
    return super.close();
  }
}
