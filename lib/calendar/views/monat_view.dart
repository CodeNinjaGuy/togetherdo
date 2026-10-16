/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Monatsansicht: Wischen zwischen Monaten, Zellen mit Farbbändern je
/// Person (Urlaub/Arbeit) und Punkten je Termin; Antippen zoomt in den Tag.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../widgets/monatsvorschau_karte.dart';

class MonatView extends StatefulWidget {
  const MonatView({
    super.key,
    required this.zustand,
    required this.onTag,
    this.heute,
  });

  final KalenderZustand zustand;

  /// Tag angetippt; `zelle` ist das Rechteck der Zelle (für den Zoom).
  final void Function(DateTime tag, Rect zelle) onTag;
  final DateTime? heute;

  @override
  State<MonatView> createState() => _MonatViewState();
}

class _MonatViewState extends State<MonatView> {
  static const _basis = 2400;
  late final PageController _controller;
  late DateTime _basisMonat;

  @override
  void initState() {
    super.initState();
    _basisMonat = DateTime.utc(widget.zustand.fokus.year, widget.zustand.fokus.month);
    _controller = PageController(initialPage: _basis);
  }

  int _seite(DateTime monat) =>
      _basis + (monat.year - _basisMonat.year) * 12 + (monat.month - _basisMonat.month);

  DateTime _monatFuer(int seite) =>
      DateTime.utc(_basisMonat.year, _basisMonat.month + (seite - _basis));

  @override
  void didUpdateWidget(covariant MonatView old) {
    super.didUpdateWidget(old);
    final neu = DateTime.utc(widget.zustand.fokus.year, widget.zustand.fokus.month);
    if (!_controller.hasClients) return;
    final ziel = _seite(neu);
    if ((_controller.page ?? _basis).round() != ziel) {
      if (TdMotion.reduced(context)) {
        _controller.jumpToPage(ziel);
      } else {
        _controller.animateToPage(ziel, duration: TdMotion.base, curve: TdMotion.standard);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.zustand;
    final heute = widget.heute ?? nurTag(lokal(DateTime.now().toUtc(), z.zeitzone));
    final locale = Localizations.localeOf(context).toString();
    return LayoutBuilder(
      builder: (ctx, c) {
        final zellenHoehe = ((c.maxHeight - 60) / 6).clamp(56.0, 84.0);
        return PageView.builder(
          controller: _controller,
          onPageChanged: (seite) {
            final m = _monatFuer(seite);
            if (m.year != z.fokus.year || m.month != z.fokus.month) {
              // Gleichen Tag im neuen Monat behalten (soweit vorhanden).
              final tag = z.fokus.day.clamp(1, DateTime.utc(m.year, m.month + 1, 0).day);
              widget.onTag(DateTime.utc(m.year, m.month, tag), Rect.zero);
            }
          },
          itemBuilder: (ctx, seite) {
            final monat = _monatFuer(seite);
            final von = utcVon(z.zeitzone, monat.year, monat.month, 1);
            final bis = utcVon(z.zeitzone, monat.year, monat.month + 1, 1);
            final inhalte = _inhalte(z, von, bis);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(TdSpace.md, TdSpace.sm, TdSpace.md, 120),
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    label: DateFormat.yMMMM(locale).format(monat),
                    child: const SizedBox.shrink(),
                  ),
                  TdCard(
                    padding: const EdgeInsets.all(TdSpace.sm),
                    child: TdMonatsGitter(
                      monat: monat,
                      heute: heute,
                      gewaehlt: z.fokus,
                      locale: locale,
                      zellenHoehe: zellenHoehe,
                      onTagGewaehlt: widget.onTag,
                      inhalt: (ctx, tag) {
                        final k = tagSchluesselVon(tag.year, tag.month, tag.day);
                        final i = inhalte[k];
                        if (i == null) return null;
                        return _ZellenInhalt(inhalt: i, hoehe: zellenHoehe - 40);
                      },
                    ),
                  ),
                  const SizedBox(height: TdSpace.md),
                  MonatsvorschauKarte(
                    zustand: z,
                    monat: monat,
                    heute: heute,
                    onTag: (t) => widget.onTag(t, Rect.zero),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Je Tag: Bänder (ganztägig, Farbe der Art) und Punkte (Personenfarbe).
  Map<String, _TagInhalt> _inhalte(KalenderZustand z, DateTime von, DateTime bis) {
    final out = <String, _TagInhalt>{};
    for (final v in z.vorkommen(von, bis)) {
      var t = tagesanfang(v.start.isBefore(von) ? von : v.start, z.zeitzone);
      while (t.isBefore(v.ende) && t.isBefore(bis)) {
        final k = tagSchluessel(t, z.zeitzone);
        final i = out.putIfAbsent(k, _TagInhalt.new);
        if (v.ganztaegig && v.art.istBand) {
          i.baender.add(v.art);
        } else {
          final ids = v.termin.fuerAlle ? z.mitgliederIdsDerListe(v.termin.listId) : v.termin.personen;
          for (final id in ids) {
            i.punkte.add(tdPersonFarbe(id, z.nameVon(id)));
          }
          if (v.art == TerminArt.geburtstag) i.geburtstag = true;
        }
        i.anzahl++;
        t = tagesende(t, z.zeitzone);
      }
    }
    for (final a in z.aufgabenIm(von, bis)) {
      final k = tagSchluessel(a.dueDate!.toUtc(), z.zeitzone);
      out.putIfAbsent(k, _TagInhalt.new).aufgaben++;
    }
    return out;
  }
}

class _TagInhalt {
  final List<TerminArt> baender = [];
  final Set<Color> punkte = {};
  int anzahl = 0;
  int aufgaben = 0;
  bool geburtstag = false;
}

class _ZellenInhalt extends StatelessWidget {
  const _ZellenInhalt({required this.inhalt, required this.hoehe});

  final _TagInhalt inhalt;
  final double hoehe;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final baender = inhalt.baender.toSet().take(hoehe > 40 ? 2 : 1).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final art in baender)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: TdTerminStil.of(context, art).farbe.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (inhalt.geburtstag)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.cake_rounded,
                  size: 10,
                  color: TdTerminStil.of(context, TerminArt.geburtstag).farbe,
                ),
              ),
            for (final f in inhalt.punkte.take(4)) ...[
              TdTerminPunkt(farbe: f),
              const SizedBox(width: 2),
            ],
            if (inhalt.aufgaben > 0)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: td.palette.tertiary, width: 1.5),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
