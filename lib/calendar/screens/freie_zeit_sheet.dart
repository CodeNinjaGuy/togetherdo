/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// „Wann haben alle Zeit?“ – Personen wählen, Dauer und Zeitraum, dann die
/// freien gemeinsamen Fenster als Liste; Antippen legt dort einen Termin an.
library;

import 'package:flutter/material.dart';

import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../../services/speech_service.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/freie_zeiten.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../widgets/kalender_hilfen.dart';
import 'termin_sheet.dart';

Future<Termin?> zeigeFreieZeitSheet(
  BuildContext context, {
  required KalenderCubit cubit,
  SpeechService? speech,
}) {
  final s = AppLocalizations.of(context)!;
  return showTdSheet<Termin>(
    context,
    title: s.kalWannHabenAlleZeit,
    maxWidth: 600,
    builder: (ctx) => FreieZeitSuche(cubit: cubit, speech: speech),
  );
}

class FreieZeitSuche extends StatefulWidget {
  const FreieZeitSuche({super.key, required this.cubit, this.speech, this.jetzt});

  final KalenderCubit cubit;
  final SpeechService? speech;
  final DateTime? jetzt;

  @override
  State<FreieZeitSuche> createState() => _FreieZeitSucheState();
}

class _FreieZeitSucheState extends State<FreieZeitSuche> {
  Set<String> _personen = {};
  Duration _dauer = const Duration(hours: 2);
  int _tage = 7;

  static const _dauern = [
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
  ];
  static const _zeitraeume = [1, 3, 7, 14];

  List<Zeitfenster> _suchen(KalenderZustand z) {
    final jetzt = (widget.jetzt ?? DateTime.now()).toUtc();
    final von = jetzt;
    final heute = lokal(jetzt, z.zeitzone);
    final bis = utcVon(z.zeitzone, heute.year, heute.month, heute.day + _tage);
    final personen = _personen.isEmpty ? z.mitglieder.map((m) => m.id).toSet() : _personen;
    // Alle Termine (nicht nur gefilterte) der gewählten Personen zählen.
    final alle = z.copyWith(personenFilter: {}, artenFilter: {});
    return freieZeitfenster(
      vorkommen: alle.vorkommen(von, bis),
      personen: personen,
      von: von,
      bis: bis,
      mindestDauer: _dauer,
      zeitzone: z.zeitzone,
      maxErgebnisse: 40,
    );
  }

  Future<void> _anlegen(Zeitfenster f) async {
    final t = await zeigeTerminSheet(
      context,
      cubit: widget.cubit,
      start: f.start,
      speech: widget.speech,
    );
    if (t != null && mounted) Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final z = widget.cubit.state;
    final fenster = _suchen(z);
    final personen = personenVon(z.mitglieder);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdPersonenAuswahl(
          personen: personen,
          gewaehlt: _personen,
          alleLabel: s.kalAlle,
          onAlle: () => setState(() => _personen = {}),
          onToggle: (id) => setState(() {
            if (!_personen.remove(id)) _personen.add(id);
          }),
        ),
        const SizedBox(height: TdSpace.lg),
        Text(s.kalFreieZeitDauer, style: context.text.labelMedium?.copyWith(color: context.td.muted)),
        const SizedBox(height: TdSpace.sm),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final d in _dauern)
              TdChip(
                label: s.dauerLabel(d),
                selected: d == _dauer,
                dense: true,
                onTap: () => setState(() => _dauer = d),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.md),
        Text(s.kalFreieZeitZeitraum, style: context.text.labelMedium?.copyWith(color: context.td.muted)),
        const SizedBox(height: TdSpace.sm),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final t in _zeitraeume)
              TdChip(
                label: s.kalFreieZeitNaechsteTage(t),
                selected: t == _tage,
                dense: true,
                onTap: () => setState(() => _tage = t),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.lg),
        if (fenster.isEmpty)
          TdEmptyState(
            icon: Icons.event_busy_rounded,
            title: s.kalFreieZeitKeine,
            compact: true,
          )
        else ...[
          Text(s.kalFreieZeitHinweis, style: context.text.bodySmall),
          const SizedBox(height: TdSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fenster.length,
              itemBuilder: (ctx, i) {
                final f = fenster[i];
                final tag = lokal(f.start, z.zeitzone);
                final neuerTag = i == 0 ||
                    lokal(fenster[i - 1].start, z.zeitzone).day != tag.day;
                return TdFadeSlideIn(
                  index: i,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (neuerTag)
                        Padding(
                          padding: const EdgeInsets.only(top: TdSpace.sm, bottom: TdSpace.xs),
                          child: Text(
                            datumText(ctx, DateTime(tag.year, tag.month, tag.day)),
                            style: ctx.text.titleSmall,
                          ),
                        ),
                      _FensterZeile(
                        zeit: '${zeitText(ctx, f.start, z.zeitzone)} – ${zeitText(ctx, f.ende, z.zeitzone)}',
                        dauer: s.dauerLabel(f.dauer),
                        onTap: () => _anlegen(f),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _FensterZeile extends StatelessWidget {
  const _FensterZeile({required this.zeit, required this.dauer, required this.onTap});

  final String zeit;
  final String dauer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return TdCard(
      margin: const EdgeInsets.only(bottom: TdSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: TdSpace.md, vertical: TdSpace.sm),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: td.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: TdSpace.md),
          Expanded(child: Text(zeit, style: context.text.titleSmall)),
          Text(dauer, style: context.text.bodySmall),
          const SizedBox(width: TdSpace.sm),
          Icon(Icons.add_circle_outline_rounded, color: td.palette.primary),
        ],
      ),
    );
  }
}
