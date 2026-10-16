/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Familien-Spuren: eine waagrechte Spur je Person über den Tag,
/// Termine als Blöcke, Urlaub/Arbeit (ganztägig) als Bänder oben in der
/// Spur, „Jetzt“-Linie. Wochenstreifen darüber zum Tageswechsel.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../widgets/kalender_hilfen.dart';

class SpurenView extends StatefulWidget {
  const SpurenView({
    super.key,
    required this.zustand,
    required this.onTag,
    required this.onVorkommen,
    required this.onFrei,
    this.mitStreifen = true,
    this.heute,
    this.jetzt,
  });

  final KalenderZustand zustand;
  final ValueChanged<DateTime> onTag;
  final ValueChanged<Vorkommen> onVorkommen;

  /// Leere Stelle in einer Spur angetippt: Startzeit (UTC) und Person.
  final void Function(DateTime start, String personId) onFrei;
  final bool mitStreifen;

  /// Für Tests/Demos fest setzbar.
  final DateTime? heute;
  final DateTime? jetzt;

  @override
  State<SpurenView> createState() => _SpurenViewState();
}

class _SpurenViewState extends State<SpurenView> {
  final ScrollController _waagrecht = ScrollController();
  Timer? _ticker;
  bool _anfangGesetzt = false;

  DateTime get _jetzt => widget.jetzt ?? DateTime.now().toUtc();
  DateTime get _heute => widget.heute ?? nurTag(lokal(_jetzt, widget.zustand.zeitzone));

  @override
  void initState() {
    super.initState();
    // Jede Minute neu zeichnen, damit die „Jetzt“-Linie wandert.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _waagrecht.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.zustand;
    final zone = z.zeitzone;
    final tag = z.fokus;
    final von = utcVon(zone, tag.year, tag.month, tag.day);
    final bis = utcVon(zone, tag.year, tag.month, tag.day + 1);
    final vorkommen = z.vorkommen(von, bis);
    final personen = z.sichtbareMitglieder;

    return Column(
      children: [
        if (widget.mitStreifen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TdSpace.md),
            child: TdDatumStreifen(
              gewaehlt: tag,
              heute: _heute,
              onGewaehlt: widget.onTag,
              locale: Localizations.localeOf(context).toString(),
              punkte: _punkteFuerWoche(z, tag),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              final breit = c.maxWidth >= TdBreakpoints.compact;
              // Breite Flächen (iPad/Mac): 6–22 Uhr ohne Scrollen zeigen,
              // wenn genug Platz; sonst 64 px je Stunde und scrollen.
              const spaltenBreite = 64.0;
              final nutzbar = c.maxWidth - spaltenBreite - TdSpace.md;
              final stundenBreite = breit && nutzbar / 16 >= 64
                  ? nutzbar / 16
                  : 64.0;
              const vonStunde = 0;
              const bisStunde = 24;
              if (!_anfangGesetzt) {
                _anfangGesetzt = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_waagrecht.hasClients) return;
                  final l = lokal(_jetzt, zone);
                  final startStunde = tag == _heute
                      ? (l.hour - 1).clamp(0, 18)
                      : (breit ? 6 : 7);
                  _waagrecht.jumpTo(
                    (startStunde * stundenBreite).clamp(0, _waagrecht.position.maxScrollExtent),
                  );
                });
              }
              return AnimatedSwitcher(
                duration: TdMotion.of(context, TdMotion.base),
                switchInCurve: TdMotion.standard,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current],
                ),
                child: _Tagesflaeche(
                  key: ValueKey(tag),
                  personen: personen,
                  vorkommen: vorkommen,
                  von: von,
                  zone: zone,
                  stundenBreite: stundenBreite,
                  vonStunde: vonStunde,
                  bisStunde: bisStunde,
                  spaltenBreite: spaltenBreite,
                  waagrecht: _waagrecht,
                  jetzt: tag == _heute ? _jetzt : null,
                  pulsieren: widget.jetzt == null,
                  onVorkommen: widget.onVorkommen,
                  onFrei: widget.onFrei,
                  zustand: z,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Farbpunkte je Tag der Woche (Farbe der Person, bei „alle“ die Art).
  Map<String, List<Color>> _punkteFuerWoche(KalenderZustand z, DateTime tag) {
    final montag = wochenanfang(tag);
    final out = <String, List<Color>>{};
    final von = utcVon(z.zeitzone, montag.year, montag.month, montag.day);
    final bis = utcVon(z.zeitzone, montag.year, montag.month, montag.day + 7);
    for (final v in z.vorkommen(von, bis)) {
      var t = tagesanfang(v.start, z.zeitzone);
      while (t.isBefore(v.ende) && t.isBefore(bis)) {
        final k = tagSchluessel(t, z.zeitzone);
        final farben = out.putIfAbsent(k, () => []);
        final ids = v.termin.fuerAlle
            ? z.mitgliederIdsDerListe(v.termin.listId)
            : v.termin.personen;
        for (final id in ids) {
          final f = tdPersonFarbe(id, z.nameVon(id));
          if (!farben.contains(f) && farben.length < 4) farben.add(f);
        }
        t = tagesende(t, z.zeitzone);
      }
    }
    return out;
  }
}

class _Tagesflaeche extends StatelessWidget {
  const _Tagesflaeche({
    super.key,
    required this.personen,
    required this.vorkommen,
    required this.von,
    required this.zone,
    required this.stundenBreite,
    required this.vonStunde,
    required this.bisStunde,
    required this.spaltenBreite,
    required this.waagrecht,
    required this.jetzt,
    required this.pulsieren,
    required this.onVorkommen,
    required this.onFrei,
    required this.zustand,
  });

  final List<Mitglied> personen;
  final List<Vorkommen> vorkommen;
  final DateTime von;
  final String zone;
  final double stundenBreite;
  final int vonStunde;
  final int bisStunde;
  final double spaltenBreite;
  final ScrollController waagrecht;
  final DateTime? jetzt;
  final bool pulsieren;
  final ValueChanged<Vorkommen> onVorkommen;
  final void Function(DateTime, String) onFrei;
  final KalenderZustand zustand;

  double get _breite => stundenBreite * (bisStunde - vonStunde);

  double _x(DateTime utc) {
    final minuten = utc.difference(von).inMinutes - vonStunde * 60;
    return (minuten / 60) * stundenBreite;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final td = context.td;
    if (personen.isEmpty) {
      return Center(
        child: TdEmptyState(
          icon: Icons.view_timeline_rounded,
          title: s.kalKeineTermine,
          message: s.kalKeineTermineHinweis,
          compact: true,
        ),
      );
    }
    // Spuren vorbereiten: je Person Bänder (ganztägig) und Blöcke.
    final spuren = <_Spur>[];
    for (final p in personen) {
      final eigene = vorkommen.where((v) {
        if (v.termin.fuerAlle) {
          return zustand.mitgliederIdsDerListe(v.termin.listId).contains(p.id);
        }
        return v.termin.personen.contains(p.id);
      }).toList();
      spuren.add(_Spur.bauen(p, eigene));
    }

    final linkeSpalte = SizedBox(
      width: spaltenBreite,
      child: Column(
        children: [
          const SizedBox(height: 28),
          for (final sp in spuren)
            SizedBox(
              height: sp.hoehe,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TdAvatar(
                      data: TdAvatarData(
                        id: sp.person.id,
                        name: sp.person.name,
                        imageUrl: personenVon([sp.person]).first.imageUrl,
                      ),
                      size: 36,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sp.person.name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final flaeche = SizedBox(
      width: _breite + TdSpace.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TdZeitachse(
            stundenBreite: stundenBreite,
            vonStunde: vonStunde,
            bisStunde: bisStunde,
            beschriftung: (h) => use24
                ? '$h'
                : (h == 0 ? '12 am' : h < 12 ? '$h am' : h == 12 ? '12 pm' : '${h - 12} pm'),
          ),
          Stack(
            children: [
              Positioned.fill(
                child: TdStundenraster(
                  stundenBreite: stundenBreite,
                  anzahlStunden: bisStunde - vonStunde,
                ),
              ),
              Column(
                children: [
                  for (final sp in spuren)
                    RepaintBoundary(
                      child: _SpurWidget(
                        spur: sp,
                        breite: _breite,
                        x: _x,
                        stundenBreite: stundenBreite,
                        von: von,
                        vonStunde: vonStunde,
                        onVorkommen: onVorkommen,
                        onFrei: onFrei,
                      ),
                    ),
                ],
              ),
              if (jetzt != null && _x(jetzt!) >= 0 && _x(jetzt!) <= _breite)
                Positioned(
                  left: _x(jetzt!) - 5,
                  top: 0,
                  bottom: 0,
                  child: TdJetztLinie(farbe: td.palette.secondary, pulsieren: pulsieren),
                ),
            ],
          ),
        ],
      ),
    );

    // Senkrecht scrollen beide Spalten gemeinsam; waagrecht nur die Fläche.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          linkeSpalte,
          Expanded(
            child: Scrollbar(
              controller: waagrecht,
              child: SingleChildScrollView(
                controller: waagrecht,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: flaeche,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spur einer Person: Bänder (ganztägig) oben, Blöcke in Reihen ohne
/// Überlappung.
class _Spur {
  _Spur(this.person, this.baender, this.reihen);

  final Mitglied person;
  final List<Vorkommen> baender;
  final List<List<Vorkommen>> reihen;

  static const bandHoehe = 22.0;
  static const reihenHoehe = 44.0;
  static const minHoehe = 72.0;

  double get hoehe {
    final h = (baender.isEmpty ? 0 : bandHoehe + 4) + reihen.length * reihenHoehe + 8;
    return h < minHoehe ? minHoehe : h;
  }

  static _Spur bauen(Mitglied p, List<Vorkommen> eigene) {
    final baender = eigene.where((v) => v.ganztaegig).toList();
    final zeitlich = eigene.where((v) => !v.ganztaegig).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final reihen = <List<Vorkommen>>[];
    for (final v in zeitlich) {
      var platziert = false;
      for (final r in reihen) {
        if (!r.last.ende.isAfter(v.start)) {
          r.add(v);
          platziert = true;
          break;
        }
      }
      if (!platziert) reihen.add([v]);
    }
    if (reihen.isEmpty) reihen.add([]);
    return _Spur(p, baender, reihen);
  }
}

class _SpurWidget extends StatelessWidget {
  const _SpurWidget({
    required this.spur,
    required this.breite,
    required this.x,
    required this.stundenBreite,
    required this.von,
    required this.vonStunde,
    required this.onVorkommen,
    required this.onFrei,
  });

  final _Spur spur;
  final double breite;
  final double Function(DateTime) x;
  final double stundenBreite;
  final DateTime von;
  final int vonStunde;
  final ValueChanged<Vorkommen> onVorkommen;
  final void Function(DateTime, String) onFrei;

  @override
  Widget build(BuildContext context) {
    final bandOffset = spur.baender.isEmpty ? 4.0 : _Spur.bandHoehe + 8;
    final farbe = tdPersonFarbe(spur.person.id, spur.person.name);
    return SizedBox(
      height: spur.hoehe,
      width: breite,
      child: Stack(
        children: [
          // Zarte Trennlinie in der Personenfarbe.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 1, color: farbe.withValues(alpha: 0.25)),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) {
                final minuten = (d.localPosition.dx / stundenBreite * 60).round() + vonStunde * 60;
                final gerundet = (minuten / 30).floor() * 30;
                onFrei(von.add(Duration(minutes: gerundet)), spur.person.id);
              },
            ),
          ),
          for (final b in spur.baender)
            Positioned(
              left: x(b.start).clamp(0.0, breite) + 2,
              width: (x(b.ende).clamp(0.0, breite) - x(b.start).clamp(0.0, breite) - 4).clamp(24.0, breite),
              top: 4,
              height: _Spur.bandHoehe,
              child: TdTerminBand(
                art: b.art,
                titel: b.termin.titel,
                abgerundetLinks: !b.start.isBefore(von),
                abgerundetRechts: !b.ende.isAfter(von.add(const Duration(days: 1))),
                onTap: () => onVorkommen(b),
              ),
            ),
          for (var r = 0; r < spur.reihen.length; r++)
            for (final v in spur.reihen[r])
              Positioned(
                left: x(v.start).clamp(0.0, breite) + 2,
                width: (x(v.ende).clamp(0.0, breite) - x(v.start).clamp(0.0, breite) - 4).clamp(28.0, breite),
                top: bandOffset + r * _Spur.reihenHoehe,
                height: _Spur.reihenHoehe - 6,
                child: TdTerminBlock(
                  art: v.art,
                  titel: v.termin.titel,
                  zeit: zeitraumText(context, v),
                  waagrecht: true,
                  onTap: () => onVorkommen(v),
                ),
              ),
        ],
      ),
    );
  }
}
