/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Agenda/Zeitstrahl: Heute, Morgen, Diese Woche, Später – Termine und
/// Aufgaben-Fälligkeiten (nur lesend) als Zeitstrahl mit Punkten.
library;

import 'package:flutter/material.dart';

import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../../models/todo_model.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../widgets/kalender_hilfen.dart';

class AgendaView extends StatelessWidget {
  const AgendaView({
    super.key,
    required this.zustand,
    required this.onVorkommen,
    this.heute,
    this.tage = 30,
    this.mitAbschnitten = true,
  });

  final KalenderZustand zustand;
  final ValueChanged<Vorkommen> onVorkommen;
  final DateTime? heute;
  final int tage;

  /// Überschriften „Heute/Morgen/Diese Woche/Später“ (aus in der Tagesansicht).
  final bool mitAbschnitten;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final z = zustand;
    final zone = z.zeitzone;
    final heuteTag = heute ?? nurTag(lokal(DateTime.now().toUtc(), zone));
    final von = utcVon(zone, heuteTag.year, heuteTag.month, heuteTag.day);
    final bis = utcVon(zone, heuteTag.year, heuteTag.month, heuteTag.day + tage);
    final vorkommen = z.vorkommen(von, bis);
    final aufgaben = z.aufgabenIm(von, bis);

    // Nach Tagen gruppieren.
    final tageMap = <DateTime, List<Object>>{};
    for (final v in vorkommen) {
      var t = nurTag(lokal(v.start.isBefore(von) ? von : v.start, zone));
      final letzter = nurTag(lokal(v.ende.subtract(const Duration(minutes: 1)), zone));
      // Mehrtägige nur am ersten sichtbaren Tag und bei ganztägigen je Tag.
      if (v.ganztaegig) {
        while (!t.isAfter(letzter) && t.isBefore(nurTag(lokal(bis, zone)))) {
          tageMap.putIfAbsent(t, () => []).add(v);
          t = t.add(const Duration(days: 1));
        }
      } else {
        tageMap.putIfAbsent(t, () => []).add(v);
      }
    }
    for (final a in aufgaben) {
      final t = nurTag(lokal(a.dueDate!.toUtc(), zone));
      tageMap.putIfAbsent(t, () => []).add(a);
    }
    final tageSortiert = tageMap.keys.toList()..sort();
    if (tageSortiert.isEmpty) {
      return Center(
        child: TdEmptyState(
          icon: Icons.event_available_rounded,
          title: s.kalKeineTermine,
          message: s.kalKeineTermineHinweis,
        ),
      );
    }

    // Abschnitte: Heute / Morgen / Diese Woche / Später.
    final morgen = heuteTag.add(const Duration(days: 1));
    final wochenende = wochenanfang(heuteTag).add(const Duration(days: 7));
    String abschnitt(DateTime t) {
      if (t == heuteTag) return s.kalHeute;
      if (t == morgen) return s.kalMorgen;
      if (t.isBefore(wochenende)) return s.kalDieseWoche;
      return s.kalSpaeter;
    }

    final kinder = <Widget>[];
    String? letzterAbschnitt;
    var index = 0;
    for (final t in tageSortiert) {
      final a = abschnitt(t);
      if (mitAbschnitten && a != letzterAbschnitt) {
        kinder.add(_Abschnitt(label: a, betont: a == s.kalHeute));
        letzterAbschnitt = a;
      }
      final eintraege = tageMap[t]!
        ..sort((x, y) {
          DateTime zeit(Object o) => o is Vorkommen ? o.start : (o as TodoModel).dueDate!.toUtc();
          bool ganz(Object o) => o is Vorkommen && o.ganztaegig;
          if (ganz(x) != ganz(y)) return ganz(x) ? -1 : 1;
          return zeit(x).compareTo(zeit(y));
        });
      kinder.add(
        TdFadeSlideIn(
          index: index++,
          child: _TagKarte(
            tag: t,
            heute: t == heuteTag,
            eintraege: eintraege,
            zustand: z,
            onVorkommen: onVorkommen,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(TdSpace.page, TdSpace.sm, TdSpace.page, 120),
      children: kinder,
    );
  }
}

class _Abschnitt extends StatelessWidget {
  const _Abschnitt({required this.label, required this.betont});

  final String label;
  final bool betont;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: TdSpace.lg, bottom: TdSpace.sm),
    child: Text(
      label,
      style: context.text.headlineSmall?.copyWith(
        color: betont ? context.td.palette.primary : null,
      ),
    ),
  );
}

class _TagKarte extends StatelessWidget {
  const _TagKarte({
    required this.tag,
    required this.heute,
    required this.eintraege,
    required this.zustand,
    required this.onVorkommen,
  });

  final DateTime tag;
  final bool heute;
  final List<Object> eintraege;
  final KalenderZustand zustand;
  final ValueChanged<Vorkommen> onVorkommen;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final s = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: TdSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Datumsspalte mit Zeitstrahl-Linie.
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  wochentagKurz(context, tag.weekday),
                  style: context.text.labelSmall?.copyWith(
                    color: heute ? td.palette.primary : td.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: heute ? td.primaryGradient : null,
                    boxShadow: heute ? TdShadows.glow(td.palette.primary) : null,
                  ),
                  child: Text(
                    '${tag.day}',
                    style: context.text.titleMedium?.copyWith(
                      color: heute ? td.palette.onPrimary : null,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TdSpace.sm),
          Expanded(
            child: TdCard(
              padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
              child: Column(
                children: [
                  for (var i = 0; i < eintraege.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 68, color: context.colors.outlineVariant.withValues(alpha: 0.5)),
                    if (eintraege[i] is Vorkommen)
                      _VorkommenZeile(
                        v: eintraege[i] as Vorkommen,
                        zustand: zustand,
                        onTap: () => onVorkommen(eintraege[i] as Vorkommen),
                      )
                    else
                      _AufgabeZeile(a: eintraege[i] as TodoModel, label: s.kalAufgabeFaellig, zone: zustand.zeitzone),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VorkommenZeile extends StatelessWidget {
  const _VorkommenZeile({required this.v, required this.zustand, required this.onTap});

  final Vorkommen v;
  final KalenderZustand zustand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stil = TdTerminStil.of(context, v.art);
    final s = AppLocalizations.of(context)!;
    final ids = v.termin.fuerAlle ? zustand.mitgliederIdsDerListe(v.termin.listId) : v.termin.personen;
    final personen = personenVon(ids.map((id) => Mitglied(id: id, name: zustand.nameVon(id))));
    final zeit = v.ganztaegig
        ? zeitraumText(context, v)
        : '${zeitText(context, v.start, v.termin.zeitzone)}\n${zeitText(context, v.ende, v.termin.zeitzone)}';
    return TdPressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TdSpace.md, vertical: TdSpace.sm),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                zeit,
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.3,
                ),
                maxLines: 2,
              ),
            ),
            Container(
              width: 4,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: TdSpace.sm),
              decoration: BoxDecoration(color: stil.farbe, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(stil.symbol, size: 14, color: stil.farbe),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          v.termin.titel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  if ((v.termin.ort ?? '').isNotEmpty)
                    Text(
                      v.termin.ort!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    )
                  else if (v.termin.fuerAlle)
                    Text(s.kalPersonenAlle, style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: TdSpace.sm),
            TdAvatarStack(people: personen.map((p) => p.avatar).toList(), size: 24, max: 3),
          ],
        ),
      ),
    );
  }
}

class _AufgabeZeile extends StatelessWidget {
  const _AufgabeZeile({required this.a, required this.label, required this.zone});

  final TodoModel a;
  final String label;
  final String zone;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TdSpace.md, vertical: TdSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              zeitText(context, a.dueDate!.toUtc(), zone),
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 4,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: TdSpace.sm),
            decoration: BoxDecoration(
              border: Border.all(color: td.palette.tertiary, width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(
            a.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: td.palette.tertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    decoration: a.isCompleted ? TextDecoration.lineThrough : null,
                    color: a.isCompleted ? td.muted : null,
                  ),
                ),
                Text(label, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
