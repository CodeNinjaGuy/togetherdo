/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Einstieg des Familienkalenders (Route `/kalender`, optional
/// `?liste=<listId>`). Kopf mit Datum, Ansicht-Umschalter (Spuren, Agenda,
/// Monat, Jahr), Filter (Listen, Personen, Arten), Schnellaktionen
/// „Neuer Termin“ und „Wann haben alle Zeit?“.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../design/attachments/td_attachments.dart';
import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../../models/list_model.dart';
import '../../repositories/list_repository.dart';
import '../../services/speech_service.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../repositories/termin_repository.dart';
import '../views/agenda_view.dart';
import '../views/jahr_view.dart';
import '../views/monat_view.dart';
import '../views/spuren_view.dart';
import '../views/tag_view.dart';
import '../widgets/feiertags_region_wahl.dart';
import '../widgets/kalender_hilfen.dart';
import 'freie_zeit_sheet.dart';
import 'termin_detail_sheet.dart';
import 'termin_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.listId,
    this.userId,
    this.termine,
    this.listen,
    this.anhaenge,
    this.speech,
    this.heute,
    this.jetzt,
    this.eingebettet = false,
    this.startAnsicht = KalenderAnsicht.spuren,
  });

  /// Vorgewählte Liste (`?liste=`).
  final String? listId;

  /// Ohne Angabe aus dem `AuthBloc`.
  final String? userId;
  final TerminRepository? termine;
  final ListRepository? listen;
  final AttachmentService? anhaenge;
  final SpeechService? speech;

  /// Für Tests/Demos fest setzbar.
  final DateTime? heute;
  final DateTime? jetzt;

  /// Ansicht beim Öffnen (Demo/Screenshots).
  final KalenderAnsicht startAnsicht;

  /// In einer Shell mit eigener Navigation: kein eigener Zurück-Pfeil.
  final bool eingebettet;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final KalenderCubit _cubit;
  late final AttachmentService _anhaenge;
  late final SpeechService? _speech;
  bool _filterOffen = false;

  /// Mittelpunkt des Zoom-Übergangs (Jahr → Monat), relativ zum Bildschirm.
  Alignment _zoomZentrum = Alignment.center;

  @override
  void initState() {
    super.initState();
    kalenderZeitInit();
    final userId = widget.userId ?? _userIdAusAuth();
    final listen = widget.listen ?? context.read<ListRepository>();
    _cubit = KalenderCubit(
      userId: userId,
      termine: widget.termine ?? FirebaseTerminRepository(),
      listen: listen,
      vorgewaehlteListe: widget.listId,
      heute: widget.heute,
      ansicht: widget.startAnsicht,
    );
    _anhaenge = widget.anhaenge ?? AttachmentService();
    _speech = widget.speech ?? (speechInputSupported ? DeviceSpeechService() : null);
    _cubit.starten().then((_) {
      if (mounted) profilbilderLaden(_cubit.state.mitglieder, () => setState(() {}));
    });
  }

  String _userIdAusAuth() {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.user.id : '';
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  // -------------------------------------------------------------- Aktionen

  Future<void> _neu({DateTime? start, String? personId}) async {
    final s = AppLocalizations.of(context)!;
    final t = await zeigeTerminSheet(
      context,
      cubit: _cubit,
      start: start,
      personId: personId,
      speech: _speech,
    );
    if (t != null && mounted) {
      _cubit.fokusSetzen(lokal(t.start, t.zeitzone));
      TdToast.show(context, s.kalGespeichert, variant: TdToastVariant.success, icon: Icons.event_available_rounded);
    }
  }

  Future<void> _freieZeit() async {
    final s = AppLocalizations.of(context)!;
    final t = await zeigeFreieZeitSheet(context, cubit: _cubit, speech: _speech);
    if (t != null && mounted) {
      _cubit.fokusSetzen(lokal(t.start, t.zeitzone));
      TdToast.show(context, s.kalGespeichert, variant: TdToastVariant.success);
    }
  }

  void _detail(Vorkommen v) => zeigeTerminDetail(
    context,
    cubit: _cubit,
    vorkommen: v,
    anhaenge: _anhaenge,
    speech: _speech,
  );

  void _tagAusMonat(DateTime tag, Rect zelle) {
    _cubit.fokusSetzen(tag);
    if (zelle == Rect.zero) return; // nur Monat gewechselt
    zeigeTagMitZoom(
      context,
      cubit: _cubit,
      tag: tag,
      zelle: zelle,
      onVorkommen: _detail,
      onFrei: (start, person) => _neu(start: start, personId: person),
    );
  }

  void _monatAusJahr(DateTime monat, Rect zelle) {
    final groesse = MediaQuery.sizeOf(context);
    _zoomZentrum = zelle == Rect.zero
        ? Alignment.center
        : Alignment(
            (zelle.center.dx / groesse.width) * 2 - 1,
            (zelle.center.dy / groesse.height) * 2 - 1,
          );
    _cubit.fokusSetzen(DateTime.utc(monat.year, monat.month, 1));
    _cubit.ansichtSetzen(KalenderAnsicht.monat);
  }

  Future<void> _urlaubAusJahr(DateTime von, DateTime bis) async {
    final s = AppLocalizations.of(context)!;
    final z = _cubit.state;
    final listId = z.aktiveListen.isNotEmpty ? z.aktiveListen.first : z.listen.first.id;
    final t = await zeigeTerminSheet(
      context,
      cubit: _cubit,
      speech: _speech,
      vorlage: Termin(
        id: '',
        listId: listId,
        titel: s.kalArtUrlaub,
        art: TerminArt.urlaub,
        personen: [z.userId],
        start: utcVon(z.zeitzone, von.year, von.month, von.day),
        ende: utcVon(z.zeitzone, bis.year, bis.month, bis.day + 1),
        ganztaegig: true,
        zeitzone: z.zeitzone,
        erinnerungen: const [1440],
        erstelltVon: z.userId,
      ),
    );
    if (t != null && mounted) {
      TdToast.show(context, s.kalGespeichert, variant: TdToastVariant.success);
    }
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<KalenderCubit, KalenderZustand>(
        builder: (ctx, z) {
          final s = AppLocalizations.of(ctx)!;
          final kompakt = ctx.tdIsCompact;
          return Scaffold(
            backgroundColor: ctx.colors.surface,
            floatingActionButton: _Aktionen(
              kompakt: kompakt,
              onNeu: () => _neu(),
              onFrei: _freieZeit,
            ),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Kopf(
                    zustand: z,
                    filterOffen: _filterOffen,
                    eingebettet: widget.eingebettet,
                    onHeute: _cubit.heute,
                    onAnsicht: (i) => _cubit.ansichtSetzen(KalenderAnsicht.values[i]),
                    onFilter: () => setState(() => _filterOffen = !_filterOffen),
                  ),
                  AnimatedSize(
                    duration: TdMotion.of(ctx, TdMotion.base),
                    curve: TdMotion.emphasized,
                    alignment: Alignment.topCenter,
                    child: _filterOffen
                        ? _Filter(zustand: z, cubit: _cubit)
                        : const SizedBox(width: double.infinity),
                  ),
                  if (z.fehler != null)
                    Padding(
                      padding: const EdgeInsets.all(TdSpace.lg),
                      child: Text(s.kalFehler(z.fehler!), style: ctx.text.bodySmall?.copyWith(color: ctx.td.danger)),
                    ),
                  Expanded(
                    child: z.laedt && z.termine.isEmpty && z.listen.isEmpty
                        ? const Center(child: CircularProgressIndicator.adaptive())
                        : AnimatedSwitcher(
                            duration: TdMotion.of(ctx, TdMotion.page),
                            switchInCurve: TdMotion.emphasized,
                            switchOutCurve: TdMotion.exit,
                            transitionBuilder: (child, anim) {
                              if (TdMotion.reduced(ctx)) {
                                return FadeTransition(opacity: anim, child: child);
                              }
                              final eingehend = child.key == ValueKey(z.ansicht);
                              return FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: eingehend ? 0.92 : 1.04, end: 1).animate(anim),
                                  alignment: _zoomZentrum,
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(z.ansicht),
                              child: _ansicht(ctx, z),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ansicht(BuildContext ctx, KalenderZustand z) {
    switch (z.ansicht) {
      case KalenderAnsicht.spuren:
        return SpurenView(
          zustand: z,
          heute: widget.heute,
          jetzt: widget.jetzt,
          onTag: _cubit.fokusSetzen,
          onVorkommen: _detail,
          onFrei: (start, person) => _neu(start: start, personId: person),
        );
      case KalenderAnsicht.agenda:
        return AgendaView(zustand: z, heute: widget.heute, onVorkommen: _detail);
      case KalenderAnsicht.monat:
        return MonatView(zustand: z, heute: widget.heute, onTag: _tagAusMonat);
      case KalenderAnsicht.jahr:
        return JahrView(
          zustand: z,
          heute: widget.heute,
          onMonat: _monatAusJahr,
          onZeitraum: _urlaubAusJahr,
        );
    }
  }
}

// -------------------------------------------------------------------- Kopf

class _Kopf extends StatelessWidget {
  const _Kopf({
    required this.zustand,
    required this.filterOffen,
    required this.eingebettet,
    required this.onHeute,
    required this.onAnsicht,
    required this.onFilter,
  });

  final KalenderZustand zustand;
  final bool filterOffen;
  final bool eingebettet;
  final VoidCallback onHeute;
  final ValueChanged<int> onAnsicht;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final kompakt = context.tdIsCompact;
    final fokus = zustand.fokus;
    final titel = zustand.ansicht == KalenderAnsicht.jahr
        ? '${fokus.year}'
        : zustand.ansicht == KalenderAnsicht.spuren
            ? datumText(context, fokus)
            : DateFormat.yMMMM(locale).format(DateTime(fokus.year, fokus.month));
    final filterAktiv = zustand.personenFilter.isNotEmpty ||
        zustand.artenFilter.isNotEmpty ||
        zustand.aktiveListen.length != zustand.listen.length;
    final umschalter = TdAnsichtUmschalter(
      nurSymbole: kompakt,
      index: zustand.ansicht.index,
      onChanged: onAnsicht,
      eintraege: [
        TdUmschalterEintrag(label: s.kalAnsichtSpuren, icon: Icons.view_timeline_rounded),
        TdUmschalterEintrag(label: s.kalAnsichtAgenda, icon: Icons.view_agenda_rounded),
        TdUmschalterEintrag(label: s.kalAnsichtMonat, icon: Icons.calendar_view_month_rounded),
        TdUmschalterEintrag(label: s.kalJahr, icon: Icons.grid_view_rounded),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(TdSpace.md, TdSpace.sm, TdSpace.md, TdSpace.sm),
      child: Column(
        children: [
          Row(
            children: [
              if (!eingebettet && Navigator.of(context).canPop())
                TdIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.kalTitel, style: context.text.labelSmall),
                    AnimatedSwitcher(
                      duration: TdMotion.of(context, TdMotion.fast),
                      child: Text(
                        titel,
                        key: ValueKey(titel),
                        style: context.text.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TdButton.ghost(
                label: s.kalHeute,
                icon: Icons.today_rounded,
                size: TdButtonSize.small,
                onPressed: onHeute,
              ),
              TdIconButton(
                icon: filterOffen ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                tooltip: s.kalFilter,
                filled: filterAktiv,
                onPressed: onFilter,
              ),
              if (!kompakt) ...[
                const SizedBox(width: TdSpace.sm),
                SizedBox(width: 420, child: umschalter),
              ],
            ],
          ),
          if (kompakt) ...[
            const SizedBox(height: TdSpace.sm),
            umschalter,
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Filter

class _Filter extends StatelessWidget {
  const _Filter({required this.zustand, required this.cubit});

  final KalenderZustand zustand;
  final KalenderCubit cubit;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final z = zustand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(TdSpace.md, 0, TdSpace.md, TdSpace.sm),
      child: TdCard(
        padding: const EdgeInsets.all(TdSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (z.listen.length > 1) ...[
              Text(s.kalListen, style: context.text.labelMedium?.copyWith(color: context.td.muted)),
              const SizedBox(height: TdSpace.xs),
              Wrap(
                spacing: TdSpace.sm,
                runSpacing: TdSpace.sm,
                children: [
                  for (final l in z.listen)
                    TdChip(
                      label: l.name,
                      icon: l.type == ListType.shopping ? Icons.shopping_basket_rounded : Icons.checklist_rounded,
                      selected: z.aktiveListen.contains(l.id),
                      dense: true,
                      onTap: () => cubit.listeUmschalten(l.id),
                    ),
                ],
              ),
              const SizedBox(height: TdSpace.md),
            ],
            Text(s.kalPersonen, style: context.text.labelMedium?.copyWith(color: context.td.muted)),
            const SizedBox(height: TdSpace.xs),
            TdPersonenAuswahl(
              personen: personenVon(z.mitglieder),
              gewaehlt: z.personenFilter,
              alleLabel: s.kalAlle,
              onAlle: cubit.personenFilterLeeren,
              onToggle: cubit.personUmschalten,
              size: 40,
            ),
            const SizedBox(height: TdSpace.md),
            Text(s.kalArten, style: context.text.labelMedium?.copyWith(color: context.td.muted)),
            const SizedBox(height: TdSpace.xs),
            Wrap(
              spacing: TdSpace.sm,
              runSpacing: TdSpace.sm,
              children: [
                TdChip(
                  label: s.kalAlle,
                  selected: z.artenFilter.isEmpty,
                  dense: true,
                  onTap: cubit.artenFilterLeeren,
                ),
                for (final a in TerminArt.values)
                  TdChip(
                    label: s.artLabel(a),
                    icon: TdTerminStil.of(context, a).symbol,
                    color: TdTerminStil.of(context, a).farbe,
                    selected: z.artenFilter.contains(a),
                    dense: true,
                    onTap: () => cubit.artUmschalten(a),
                  ),
              ],
            ),
            const SizedBox(height: TdSpace.md),
            FeiertagsRegionWahl(
              region: z.feiertagsRegion,
              onChanged: cubit.feiertagsRegionSetzen,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Aktionen

class _Aktionen extends StatelessWidget {
  const _Aktionen({required this.kompakt, required this.onNeu, required this.onFrei});

  final bool kompakt;
  final VoidCallback onNeu;
  final VoidCallback onFrei;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final td = context.td;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'kal-frei',
          tooltip: s.kalWannHabenAlleZeit,
          backgroundColor: context.colors.surfaceContainerHigh,
          foregroundColor: td.palette.primary,
          onPressed: onFrei,
          child: const Icon(Icons.people_alt_rounded),
        ),
        const SizedBox(height: TdSpace.md),
        FloatingActionButton.extended(
          heroTag: 'kal-neu',
          onPressed: onNeu,
          icon: const Icon(Icons.add_rounded),
          label: Text(s.kalNeuerTermin),
        ),
      ],
    );
  }
}
