/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Karte „Was kommt im {Monat}“: Highlights, freie Wochenenden, wer wie
/// viel unterwegs ist und gemeinsame Urlaube. Wird oben in der
/// Monatsansicht und im Jahresüberblick eingebaut.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/monatsvorschau.dart';
import '../models/termin.dart';
import 'kalender_hilfen.dart';
import 'zeitraum_text.dart';

class MonatsvorschauKarte extends StatelessWidget {
  const MonatsvorschauKarte({
    super.key,
    required this.zustand,
    required this.monat,
    this.onTag,
    this.heute,
    this.vorschau,
  });

  final KalenderZustand zustand;

  /// Erster Tag des Monats (reiner Tag).
  final DateTime monat;

  /// Tag angetippt (freies Wochenende, Highlight, gemeinsamer Urlaub).
  final ValueChanged<DateTime>? onTag;
  final DateTime? heute;

  /// Fertig berechnete Vorschau (sonst wird sie hier berechnet).
  final Monatsvorschau? vorschau;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final v = vorschau ??
        berechneMonatsvorschau(zustand: zustand, monat: monat, heute: heute);
    final monatsName = DateFormat.MMMM(locale).format(DateTime(monat.year, monat.month));
    final td = context.td;

    return TdCard(
      padding: const EdgeInsets.all(TdSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: td.palette.primary),
              const SizedBox(width: TdSpace.sm),
              Expanded(
                child: Text(
                  s.vorschauTitel(monatsName),
                  style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (v.ruhig) ...[
            const SizedBox(height: TdSpace.sm),
            Text(s.vorschauRuhig, style: context.text.bodyMedium?.copyWith(color: td.muted)),
          ],
          if (v.highlights.isNotEmpty) ...[
            const SizedBox(height: TdSpace.md),
            _Abschnitt(titel: s.vorschauHighlights),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: v.highlights.length,
                separatorBuilder: (_, _) => const SizedBox(width: TdSpace.sm),
                itemBuilder: (ctx, i) => _HighlightChip(
                  highlight: v.highlights[i],
                  locale: locale,
                  onTap: onTag == null ? null : () => onTag!(v.highlights[i].erster),
                ),
              ),
            ),
          ],
          const SizedBox(height: TdSpace.md),
          _Abschnitt(titel: s.vorschauFreieWochenenden),
          if (v.freieWochenenden.isEmpty)
            Text(
              s.vorschauKeineFreienWochenenden,
              style: context.text.bodySmall?.copyWith(color: td.muted),
            )
          else
            Wrap(
              spacing: TdSpace.sm,
              runSpacing: TdSpace.sm,
              children: [
                for (final sa in v.freieWochenenden)
                  TdChip(
                    key: ValueKey('wochenende-${sa.day}'),
                    label: wochenendeKurz(sa, locale),
                    icon: Icons.weekend_rounded,
                    color: td.success,
                    selected: true,
                    dense: true,
                    onTap: onTag == null ? null : () => onTag!(sa),
                  ),
              ],
            ),
          if (v.unterwegs.any((u) => !u.leer)) ...[
            const SizedBox(height: TdSpace.md),
            _Abschnitt(titel: s.vorschauUnterwegs),
            for (final u in v.unterwegs.where((u) => !u.leer))
              Padding(
                padding: const EdgeInsets.only(bottom: TdSpace.sm),
                child: _UnterwegsZeile(
                  unterwegs: u,
                  maxUrlaub: _max(v.unterwegs.map((x) => x.urlaubstage.toDouble())),
                  maxArbeit: _max(v.unterwegs.map((x) => x.arbeitsstunden)),
                ),
              ),
          ],
          if (v.gemeinsamerUrlaub.isNotEmpty) ...[
            const SizedBox(height: TdSpace.xs),
            _Abschnitt(titel: s.vorschauAlleFrei),
            Wrap(
              spacing: TdSpace.sm,
              runSpacing: TdSpace.sm,
              children: [
                for (final zr in v.gemeinsamerUrlaub)
                  TdChip(
                    label: zeitraumKurz(zr.von, zr.bis, locale),
                    icon: Icons.beach_access_rounded,
                    color: TdTerminStil.of(context, TerminArt.urlaub).farbe,
                    selected: true,
                    dense: true,
                    onTap: onTag == null ? null : () => onTag!(zr.von),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static double _max(Iterable<double> werte) {
    var m = 0.0;
    for (final w in werte) {
      if (w > m) m = w;
    }
    return m;
  }
}

class _Abschnitt extends StatelessWidget {
  const _Abschnitt({required this.titel});

  final String titel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TdSpace.sm),
    child: Text(
      titel.toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        color: context.td.muted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.highlight, required this.locale, this.onTap});

  final Highlight highlight;
  final String locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stil = TdTerminStil.of(context, highlight.art);
    final datum = highlight.mehrtaegig
        ? zeitraumKurz(highlight.erster, highlight.letzter, locale)
        : DateFormat.d(locale).format(highlight.erster) + (locale.startsWith('de') ? '.' : '');
    return TdChip(
      label: '${highlight.vorkommen.termin.titel} · $datum',
      icon: stil.symbol,
      color: stil.farbe,
      selected: true,
      dense: true,
      onTap: onTap,
    );
  }
}

/// Avatar, Name und zwei schmale Balken (Urlaubstage, Arbeitsstunden).
class _UnterwegsZeile extends StatelessWidget {
  const _UnterwegsZeile({
    required this.unterwegs,
    required this.maxUrlaub,
    required this.maxArbeit,
  });

  final Unterwegs unterwegs;
  final double maxUrlaub;
  final double maxArbeit;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final u = unterwegs;
    final person = personenVon([u.mitglied]).first;
    final urlaub = TdTerminStil.of(context, TerminArt.urlaub).farbe;
    final arbeit = TdTerminStil.of(context, TerminArt.arbeit).farbe;
    final teile = <String>[
      if (u.urlaubstage > 0) s.vorschauUrlaubstage(u.urlaubstage),
      if (u.arbeitsstunden > 0) s.vorschauArbeitsstunden(u.arbeitsstunden.round()),
      if (u.termine > 0) s.vorschauTermine(u.termine),
    ];
    return Row(
      children: [
        TdAvatar(data: person.avatar, size: 28),
        const SizedBox(width: TdSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      u.mitglied.name.split(' ').first,
                      style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    teile.join(' · '),
                    style: context.text.labelSmall?.copyWith(color: context.td.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              _Balken(anteil: maxUrlaub == 0 ? 0 : u.urlaubstage / maxUrlaub, farbe: urlaub),
              const SizedBox(height: 2),
              _Balken(anteil: maxArbeit == 0 ? 0 : u.arbeitsstunden / maxArbeit, farbe: arbeit),
            ],
          ),
        ),
      ],
    );
  }
}

class _Balken extends StatelessWidget {
  const _Balken({required this.anteil, required this.farbe});

  final double anteil;
  final Color farbe;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: SizedBox(
      height: 4,
      child: Stack(
        children: [
          Container(color: farbe.withValues(alpha: 0.12)),
          AnimatedFractionallySizedBox(
            duration: TdMotion.of(context, TdMotion.slow),
            curve: TdMotion.standard,
            widthFactor: anteil.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(color: farbe),
          ),
        ],
      ),
    ),
  );
}
