/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Kalender-Karte für die Startseite „Heute“: die nächsten Termine aller
/// Listen des Nutzers (heute und die kommenden Tage), antippbar zum
/// Kalender. Schnittstelle laut Vertrag:
/// `HeuteKalenderKarte({required List<String> listIds})`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../logic/wiederholung.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../repositories/termin_repository.dart';
import '../widgets/kalender_hilfen.dart';

class HeuteKalenderKarte extends StatefulWidget {
  const HeuteKalenderKarte({
    super.key,
    required this.listIds,
    this.repository,
    this.maxEintraege = 4,
    this.tage = 7,
    this.onOeffnen,
    this.jetzt,
  });

  final List<String> listIds;
  final TerminRepository? repository;
  final int maxEintraege;
  final int tage;

  /// Standard: Route `/kalender` öffnen.
  final VoidCallback? onOeffnen;
  final DateTime? jetzt;

  @override
  State<HeuteKalenderKarte> createState() => _HeuteKalenderKarteState();
}

class _HeuteKalenderKarteState extends State<HeuteKalenderKarte> {
  late final TerminRepository _repo = widget.repository ?? FirebaseTerminRepository();
  late final String _zone = standardZeitzone();
  Stream<List<Termin>>? _stream;

  @override
  void initState() {
    super.initState();
    kalenderZeitInit();
    _abonnieren();
  }

  @override
  void didUpdateWidget(covariant HeuteKalenderKarte old) {
    super.didUpdateWidget(old);
    if (old.listIds.join(',') != widget.listIds.join(',')) _abonnieren();
  }

  void _abonnieren() {
    final ab = (widget.jetzt ?? DateTime.now()).toUtc().subtract(const Duration(days: 1));
    _stream = _repo.beobachten(widget.listIds, ab: ab);
  }

  void _oeffnen() {
    if (widget.onOeffnen != null) return widget.onOeffnen!();
    try {
      GoRouter.of(context).push('/kalender');
    } catch (_) {
      // Ohne Router (Vorschau/Test) nichts tun.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final td = context.td;
    return StreamBuilder<List<Termin>>(
      stream: _stream,
      builder: (ctx, snap) {
        final jetzt = (widget.jetzt ?? DateTime.now()).toUtc();
        final heute = lokal(jetzt, _zone);
        final von = utcVon(_zone, heute.year, heute.month, heute.day);
        final bis = utcVon(_zone, heute.year, heute.month, heute.day + widget.tage);
        final vorkommen = <Vorkommen>[];
        for (final t in snap.data ?? const <Termin>[]) {
          vorkommen.addAll(vorkommenIm(t, jetzt, bis).where((v) => v.ende.isAfter(jetzt)));
        }
        // Laufende Ganztägige zuerst, sonst nach Start.
        vorkommen.sort((a, b) => a.start.compareTo(b.start));
        final gezeigt = vorkommen.take(widget.maxEintraege).toList();
        final rest = vorkommen.length - gezeigt.length;
        return TdCard(
          onTap: _oeffnen,
          padding: const EdgeInsets.all(TdSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: td.primaryGradient,
                      borderRadius: BorderRadius.circular(TdRadius.sm),
                    ),
                    child: Icon(Icons.calendar_month_rounded, color: td.palette.onPrimary, size: 20),
                  ),
                  const SizedBox(width: TdSpace.md),
                  Expanded(
                    child: Text(s.kalNaechsteTermine, style: ctx.text.titleMedium),
                  ),
                  Icon(Icons.chevron_right_rounded, color: td.muted),
                ],
              ),
              const SizedBox(height: TdSpace.md),
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: TdSpace.md),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))),
                )
              else if (gezeigt.isEmpty)
                Text(s.kalKeineNaechsten, style: ctx.text.bodyMedium?.copyWith(color: td.muted))
              else ...[
                for (var i = 0; i < gezeigt.length; i++)
                  TdFadeSlideIn(
                    index: i,
                    child: _Zeile(v: gezeigt[i], zone: _zone, heute: heute, von: von),
                  ),
                if (rest > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: TdSpace.xs),
                    child: Text(s.kalMehr(rest), style: ctx.text.labelSmall),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({required this.v, required this.zone, required this.heute, required this.von});

  final Vorkommen v;
  final String zone;
  final DateTime heute;
  final DateTime von;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final stil = TdTerminStil.of(context, v.art);
    final startL = lokal(v.start, zone);
    final istHeute = startL.day == heute.day && startL.month == heute.month && startL.year == heute.year;
    final tagText = istHeute
        ? s.kalHeute
        : (startL.difference(heute).inDays <= 1 && startL.day == heute.day + 1)
            ? s.kalMorgen
            : wochentagKurz(context, startL.weekday);
    final zeit = v.ganztaegig ? s.kalGanztaegig : zeitText(context, v.start, zone);
    return Padding(
      padding: const EdgeInsets.only(bottom: TdSpace.sm),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(color: stil.farbe, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: TdSpace.md),
          Icon(stil.symbol, size: 16, color: stil.farbe),
          const SizedBox(width: TdSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.termin.titel, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                Text('$tagText · $zeit', style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
