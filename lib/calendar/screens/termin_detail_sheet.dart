/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Detailansicht eines Vorkommens im Sheet: Kopf in der Art-Farbe, Zeit,
/// Personen, Ort, Notiz, Wiederholung, Erinnerungen, Anhänge (Galerie mit
/// Upload) und Aktionen: Bearbeiten, Teilen (.ics), Löschen (bei Serien:
/// nur dieses Mal oder ganze Serie).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/attachments/td_attachments.dart';
import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../../services/speech_service.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/ical.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../widgets/kalender_hilfen.dart';
import 'termin_sheet.dart';

Future<void> zeigeTerminDetail(
  BuildContext context, {
  required KalenderCubit cubit,
  required Vorkommen vorkommen,
  required AttachmentService anhaenge,
  SpeechService? speech,
}) {
  return showTdSheet<void>(
    context,
    maxWidth: 600,
    builder: (ctx) => BlocProvider.value(
      value: cubit,
      child: TerminDetail(vorkommen: vorkommen, anhaenge: anhaenge, speech: speech),
    ),
  );
}

class TerminDetail extends StatefulWidget {
  const TerminDetail({
    super.key,
    required this.vorkommen,
    required this.anhaenge,
    this.speech,
  });

  final Vorkommen vorkommen;
  final AttachmentService anhaenge;
  final SpeechService? speech;

  @override
  State<TerminDetail> createState() => _TerminDetailState();
}

class _TerminDetailState extends State<TerminDetail> {
  final Map<String, UploadFortschritt> _laufend = {};
  final List<StreamSubscription<UploadFortschritt>> _subs = [];

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// Aktueller Termin aus dem Zustand (nach Änderungen frisch).
  Termin _aktuell(KalenderZustand z) {
    for (final t in z.termine) {
      if (t.id == widget.vorkommen.termin.id) return t;
    }
    return widget.vorkommen.termin;
  }

  Future<void> _bearbeiten(KalenderCubit cubit, Termin t) async {
    final s = AppLocalizations.of(context)!;
    final neu = await zeigeTerminSheet(context, cubit: cubit, vorhanden: t, speech: widget.speech);
    if (neu != null && mounted) {
      TdToast.show(context, s.kalGespeichert, variant: TdToastVariant.success);
    }
  }

  Future<void> _loeschen(KalenderCubit cubit, Termin t) async {
    final s = AppLocalizations.of(context)!;
    final serie = t.wiederholt;
    final wahl = await showTdSheet<String>(
      context,
      title: s.kalLoeschenFrage,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (serie) ...[
            Text(s.kalLoeschenSerieFrage, style: ctx.text.bodyMedium),
            const SizedBox(height: TdSpace.md),
            TdButton.tonal(
              label: s.kalNurDiesesMal,
              icon: Icons.event_busy_rounded,
              onPressed: () => Navigator.of(ctx).pop('einmal'),
            ),
            const SizedBox(height: TdSpace.sm),
          ],
          TdButton.danger(
            label: serie ? s.kalGanzeSerie : s.delete,
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.of(ctx).pop('alles'),
          ),
          const SizedBox(height: TdSpace.sm),
          TdButton.ghost(label: s.cancel, onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
    if (wahl == null || !mounted) return;
    try {
      if (wahl == 'einmal') {
        await cubit.vorkommenUeberspringen(widget.vorkommen);
      } else {
        for (final a in t.anhaenge) {
          unawaited(widget.anhaenge.loeschen(a));
        }
        await cubit.loeschen(t);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      TdToast.show(
        context,
        wahl == 'einmal' ? s.kalUebersprungen : s.kalGeloescht,
        variant: TdToastVariant.info,
      );
    } catch (e) {
      if (!mounted) return;
      TdToast.show(context, s.kalFehler('$e'), variant: TdToastVariant.error);
    }
  }

  Future<void> _teilen(Termin t) async {
    final s = AppLocalizations.of(context)!;
    try {
      final ics = terminAlsIcs(t);
      final dir = await getTemporaryDirectory();
      final name = t.titel.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final datei = File('${dir.path}/$name.ics');
      await datei.writeAsString(ics);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(datei.path, mimeType: 'text/calendar', name: '$name.ics')],
          subject: t.titel,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      TdToast.show(context, s.kalFehler('$e'), variant: TdToastVariant.error);
    }
  }

  Future<void> _anhangHinzufuegen(KalenderCubit cubit, Termin t) async {
    final s = AppLocalizations.of(context)!;
    final quelle = await showTdAnhangQuelleSheet(context);
    if (quelle == null || !mounted) return;
    List<AnhangAuswahl> dateien;
    try {
      anhangAnzahlPruefen(t.anhaenge.length + _laufend.length);
      dateien = await widget.anhaenge.waehlen(quelle);
      for (final d in dateien) {
        anhangPruefen(d);
      }
    } catch (e) {
      if (!mounted) return;
      TdToast.show(context, s.anhangFehler(e), variant: TdToastVariant.warning);
      return;
    }
    for (final d in dateien) {
      final strom = widget.anhaenge.hochladen(
        basisPfad: 'termine/${t.listId}/${t.id}',
        datei: d,
        userId: cubit.userId,
      );
      late StreamSubscription<UploadFortschritt> sub;
      sub = strom.listen(
        (f) async {
          if (!mounted) return;
          setState(() => _laufend[f.anhangId] = f);
          if (f.istFertig && f.fertig != null) {
            final frisch = _aktuell(cubit.state);
            await cubit.anhaengeSetzen(frisch, [...frisch.anhaenge, f.fertig!]);
            if (mounted) setState(() => _laufend.remove(f.anhangId));
          }
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() => _laufend.removeWhere((_, f) => f.name == d.name));
          TdToast.show(context, s.anhangFehler(e), variant: TdToastVariant.error);
        },
      );
      _subs.add(sub);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final cubit = context.read<KalenderCubit>();
    return BlocBuilder<KalenderCubit, KalenderZustand>(
      builder: (ctx, z) {
        final t = _aktuell(z);
        final v = Vorkommen(
          termin: t,
          start: widget.vorkommen.start,
          ende: widget.vorkommen.ende,
        );
        final stil = TdTerminStil.of(ctx, t.art);
        final darf = z.darfBearbeiten(t);
        final ids = t.fuerAlle ? z.mitgliederIdsDerListe(t.listId) : t.personen;
        final personen = personenVon(ids.map((id) => Mitglied(id: id, name: z.nameVon(id))));
        final liste = z.listen.where((l) => l.id == t.listId).firstOrNull;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kopf
            Container(
              padding: const EdgeInsets.all(TdSpace.lg),
              decoration: BoxDecoration(
                color: stil.fuellung(ctx),
                borderRadius: BorderRadius.circular(TdRadius.lg),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: stil.farbe,
                      borderRadius: BorderRadius.circular(TdRadius.md),
                    ),
                    child: Icon(stil.symbol, color: Colors.white),
                  ),
                  const SizedBox(width: TdSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.titel, style: ctx.text.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${s.artLabel(t.art)}${liste != null ? ' · ${liste.name}' : ''}',
                          style: ctx.text.bodySmall?.copyWith(color: stil.text(ctx)),
                        ),
                      ],
                    ),
                  ),
                  if (t.wiederholt)
                    Tooltip(
                      message: s.wiederholungLabel(t.wiederholung),
                      child: Icon(Icons.repeat_rounded, color: stil.text(ctx)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: TdSpace.lg),
            _Zeile(
              icon: Icons.schedule_rounded,
              titel: datumText(ctx, lokalTag(v.start, t.zeitzone)),
              text: zeitraumText(ctx, v),
            ),
            _Zeile(
              icon: Icons.groups_rounded,
              titel: t.fuerAlle ? s.kalPersonenAlle : personen.map((p) => p.name).join(', '),
              trailing: TdAvatarStack(people: personen.map((p) => p.avatar).toList(), size: 28, max: 5),
            ),
            if ((t.ort ?? '').isNotEmpty) _Zeile(icon: Icons.place_outlined, titel: t.ort!),
            if (t.wiederholt)
              _Zeile(icon: Icons.repeat_rounded, titel: s.wiederholungLabel(t.wiederholung)),
            if (t.erinnerungen.isNotEmpty)
              _Zeile(
                icon: Icons.notifications_active_outlined,
                titel: t.erinnerungen.map(s.erinnerungLabel).join(' · '),
              ),
            if ((t.notiz ?? '').isNotEmpty)
              _Zeile(icon: Icons.notes_rounded, titel: t.notiz!, mehrzeilig: true),
            _Zeile(
              icon: Icons.person_outline_rounded,
              titel: s.kalErstelltVon(z.nameVon(t.erstelltVon)),
              gedaempft: true,
            ),
            const SizedBox(height: TdSpace.md),
            // Anhänge
            Text(s.kalAnhaenge, style: ctx.text.labelMedium?.copyWith(color: ctx.td.muted)),
            const SizedBox(height: TdSpace.sm),
            TdAnhangGalerie(
              anhaenge: t.anhaenge,
              service: widget.anhaenge,
              laufend: _laufend,
              padding: EdgeInsets.zero,
              darfLoeschen: (a) => darf || a.hochgeladenVon == z.userId,
              onLoeschen: (a) => cubit.anhaengeSetzen(
                t,
                t.anhaenge.where((x) => x.id != a.id).toList(),
              ),
              onHinzufuegen: () => _anhangHinzufuegen(cubit, t),
            ),
            const SizedBox(height: TdSpace.lg),
            // Aktionen
            Row(
              children: [
                if (darf)
                  Expanded(
                    child: TdButton.primary(
                      label: s.edit,
                      icon: Icons.edit_rounded,
                      onPressed: () => _bearbeiten(cubit, t),
                    ),
                  ),
                if (darf) const SizedBox(width: TdSpace.sm),
                TdIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: s.kalTeilenIcs,
                  filled: true,
                  onPressed: () => _teilen(t),
                ),
                if (darf) ...[
                  const SizedBox(width: TdSpace.sm),
                  TdIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: s.delete,
                    filled: true,
                    color: ctx.td.danger,
                    onPressed: () => _loeschen(cubit, t),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Reiner Tag (lokal) eines UTC-Zeitpunkts in der Zeitzone.
DateTime lokalTag(DateTime utc, String zone) {
  final l = lokal(utc, zone);
  return DateTime(l.year, l.month, l.day);
}

class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.icon,
    required this.titel,
    this.text,
    this.trailing,
    this.mehrzeilig = false,
    this.gedaempft = false,
  });

  final IconData icon;
  final String titel;
  final String? text;
  final Widget? trailing;
  final bool mehrzeilig;
  final bool gedaempft;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TdSpace.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.td.muted),
        const SizedBox(width: TdSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titel,
                style: gedaempft
                    ? context.text.bodySmall
                    : context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                maxLines: mehrzeilig ? null : 2,
                overflow: mehrzeilig ? null : TextOverflow.ellipsis,
              ),
              if (text != null) Text(text!, style: context.text.bodyMedium?.copyWith(color: context.td.muted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}
