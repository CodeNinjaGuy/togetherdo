/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Anlegen/Bearbeiten eines Termins im `showTdSheet`: Schnelleingabe in
/// Alltagssprache (Tippen oder Sprechen), Art-Chips, Personen-Avatare,
/// Datum/Zeit-Pillen, Wiederholung, Erinnerung, Ort, Notiz. Konflikt-Hinweis
/// vor dem Speichern.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../../models/list_model.dart';
import '../../services/speech_service.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/konflikte.dart';
import '../logic/schnelleingabe_parser.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../widgets/kalender_hilfen.dart';

/// Öffnet das Formular. Liefert den gespeicherten Termin oder `null`.
Future<Termin?> zeigeTerminSheet(
  BuildContext context, {
  required KalenderCubit cubit,
  Termin? vorhanden,
  Termin? vorlage,
  DateTime? start,
  String? personId,
  String? listId,
  SpeechService? speech,
}) {
  final s = AppLocalizations.of(context)!;
  return showTdSheet<Termin>(
    context,
    title: vorhanden == null ? s.kalNeuerTermin : s.kalTerminBearbeiten,
    maxWidth: 640,
    builder: (ctx) => TerminFormular(
      cubit: cubit,
      vorhanden: vorhanden,
      vorlage: vorlage,
      start: start,
      personId: personId,
      listId: listId,
      speech: speech,
    ),
  );
}

class TerminFormular extends StatefulWidget {
  const TerminFormular({
    super.key,
    required this.cubit,
    this.vorhanden,
    this.vorlage,
    this.start,
    this.personId,
    this.listId,
    this.speech,
  });

  final KalenderCubit cubit;
  final Termin? vorhanden;

  /// Vorbelegung für einen neuen Termin (z. B. Urlaub aus dem Jahresüberblick).
  final Termin? vorlage;
  final DateTime? start;
  final String? personId;
  final String? listId;
  final SpeechService? speech;

  @override
  State<TerminFormular> createState() => _TerminFormularState();
}

class _TerminFormularState extends State<TerminFormular> {
  late final KalenderZustand _z = widget.cubit.state;
  late final String _zone = (widget.vorhanden ?? widget.vorlage)?.zeitzone ?? _z.zeitzone;

  final _schnell = TextEditingController();
  late final TextEditingController _titel;
  late final TextEditingController _ort;
  late final TextEditingController _notiz;

  late String _listId;
  late TerminArt _art;
  late Set<String> _personen;
  late bool _ganztaegig;
  late DateTime _start; // Wanduhrzeit (lokal in _zone, als naive DateTime)
  late DateTime _ende;
  Wiederholung? _wiederholung;
  late List<int> _erinnerungen;

  SchnelleingabeErgebnis? _erkannt;
  Timer? _debounce;
  bool _hoert = false;
  double _pegel = 0;
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vorhanden ?? widget.vorlage;
    _listId = v?.listId ??
        widget.listId ??
        (_z.aktiveListen.isNotEmpty ? _z.aktiveListen.first : _z.listen.first.id);
    _art = v?.art ?? TerminArt.termin;
    _personen = {...?v?.personen, if (widget.personId != null) widget.personId!};
    _ganztaegig = v?.ganztaegig ?? false;
    if (v != null) {
      _start = _naiv(lokal(v.start, _zone));
      _ende = _naiv(lokal(v.ende, _zone));
    } else {
      final basis = widget.start != null
          ? _naiv(lokal(widget.start!, _zone))
          : _naechsteHalbeStunde(_z.fokus);
      _start = basis;
      _ende = basis.add(const Duration(hours: 1));
    }
    _wiederholung = v?.wiederholung;
    _erinnerungen = [...?v?.erinnerungen];
    if (widget.vorhanden == null && widget.vorlage == null && _erinnerungen.isEmpty) {
      _erinnerungen = [30];
    }
    _titel = TextEditingController(text: v?.titel ?? '');
    _ort = TextEditingController(text: v?.ort ?? '');
    _notiz = TextEditingController(text: v?.notiz ?? '');
  }

  DateTime _naiv(DateTime l) => DateTime(l.year, l.month, l.day, l.hour, l.minute);

  DateTime _naechsteHalbeStunde(DateTime tag) {
    final jetzt = lokal(DateTime.now().toUtc(), _zone);
    final heute = jetzt.year == tag.year && jetzt.month == tag.month && jetzt.day == tag.day;
    if (!heute) return DateTime(tag.year, tag.month, tag.day, 9);
    final min = jetzt.minute < 30 ? 30 : 60;
    return DateTime(jetzt.year, jetzt.month, jetzt.day, jetzt.hour, min);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.speech?.cancel();
    _schnell.dispose();
    _titel.dispose();
    _ort.dispose();
    _notiz.dispose();
    super.dispose();
  }

  // ------------------------------------------------------- Schnelleingabe

  void _schnellGeaendert(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _zerlegen(text));
  }

  void _zerlegen(String text) {
    if (!mounted) return;
    if (text.trim().isEmpty) {
      setState(() => _erkannt = null);
      return;
    }
    final sprache = Localizations.localeOf(context).languageCode;
    final mitglieder = _z.mitglieder.map((m) => m.name).toList();
    setState(() {
      _erkannt = zerlegeSchnelleingabe(
        text,
        jetzt: _naiv(lokal(DateTime.now().toUtc(), _zone)),
        mitglieder: mitglieder,
        sprache: sprache,
      );
    });
  }

  void _uebernehmen() {
    final e = _erkannt;
    if (e == null) return;
    setState(() {
      if (e.titel.isNotEmpty) _titel.text = e.titel;
      if (e.art != null) _art = e.art!;
      if (e.alle) {
        _personen = {};
      } else if (e.personenNamen.isNotEmpty) {
        _personen = {
          for (final m in _z.mitglieder)
            if (e.personenNamen.any((n) => n.toLowerCase() == m.name.toLowerCase() ||
                n.toLowerCase() == m.name.split(' ').first.toLowerCase()))
              m.id,
        };
      }
      if (e.start != null) {
        _ganztaegig = e.ganztaegig;
        _start = e.start!;
        _ende = e.ende ?? e.start!.add(e.ganztaegig ? const Duration(days: 1) : const Duration(hours: 1));
      }
      if (e.wiederholung != null) _wiederholung = e.wiederholung;
      _schnell.clear();
      _erkannt = null;
    });
  }

  Future<void> _diktieren() async {
    final speech = widget.speech;
    if (speech == null) return;
    if (_hoert) {
      await speech.stop();
      setState(() => _hoert = false);
      return;
    }
    final s = AppLocalizations.of(context)!;
    final status = await speech.start(
      localeId: Localizations.localeOf(context).toString(),
      onText: (text, fertig) {
        if (!mounted) return;
        _schnell.text = text;
        _zerlegen(text);
        if (fertig) setState(() => _hoert = false);
      },
      onLevel: (l) => setState(() => _pegel = l),
      onDone: () => mounted ? setState(() => _hoert = false) : null,
    );
    if (!mounted) return;
    switch (status) {
      case SpeechStartStatus.listening:
        setState(() => _hoert = true);
      case SpeechStartStatus.permissionDenied:
        TdToast.show(context, s.voiceMicDenied, variant: TdToastVariant.warning);
      case SpeechStartStatus.unavailable:
        TdToast.show(context, s.voiceUnavailable, variant: TdToastVariant.warning);
    }
  }

  // --------------------------------------------------------------- Zeiten

  Future<void> _datumWaehlen(bool fuerStart) async {
    final s = AppLocalizations.of(context)!;
    final heute = lokal(DateTime.now().toUtc(), _zone);
    final basis = fuerStart ? _start : (_ganztaegig ? _ende.subtract(const Duration(days: 1)) : _ende);
    final tag = await showTdDatumWaehler(
      context,
      gewaehlt: basis,
      heute: DateTime(heute.year, heute.month, heute.day),
      titel: fuerStart ? s.kalStart : s.kalEnde,
      heuteLabel: s.kalHeute,
      morgenLabel: s.kalMorgen,
      fertigLabel: s.save,
      locale: Localizations.localeOf(context).toString(),
    );
    if (tag == null) return;
    setState(() {
      if (fuerStart) {
        final dauer = _ende.difference(_start);
        _start = DateTime(tag.year, tag.month, tag.day, _start.hour, _start.minute);
        _ende = _start.add(dauer);
      } else {
        final neu = _ganztaegig
            ? DateTime(tag.year, tag.month, tag.day + 1)
            : DateTime(tag.year, tag.month, tag.day, _ende.hour, _ende.minute);
        _ende = neu.isAfter(_start) ? neu : _start.add(_ganztaegig ? const Duration(days: 1) : const Duration(hours: 1));
      }
    });
  }

  Future<void> _zeitWaehlen(bool fuerStart) async {
    final s = AppLocalizations.of(context)!;
    final basis = fuerStart ? _start : _ende;
    final z = await showTdZeitWaehler(
      context,
      gewaehlt: TimeOfDay(hour: basis.hour, minute: basis.minute),
      titel: fuerStart ? s.kalStart : s.kalEnde,
      fertigLabel: s.save,
    );
    if (z == null) return;
    setState(() {
      if (fuerStart) {
        final dauer = _ende.difference(_start);
        _start = DateTime(_start.year, _start.month, _start.day, z.hour, z.minute);
        _ende = _start.add(dauer);
      } else {
        final neu = DateTime(_ende.year, _ende.month, _ende.day, z.hour, z.minute);
        _ende = neu.isAfter(_start) ? neu : _start.add(const Duration(minutes: 30));
      }
    });
  }

  void _ganztaegigSetzen(bool v) => setState(() {
    _ganztaegig = v;
    if (v) {
      _start = DateTime(_start.year, _start.month, _start.day);
      final endTag = DateTime(_ende.year, _ende.month, _ende.day);
      _ende = endTag.isAfter(_start) ? endTag : _start.add(const Duration(days: 1));
      if (_ende.hour != 0 || _ende.minute != 0) _ende = DateTime(_ende.year, _ende.month, _ende.day + 1);
    } else {
      _start = DateTime(_start.year, _start.month, _start.day, 9);
      _ende = _start.add(const Duration(hours: 1));
    }
  });

  // -------------------------------------------------------------- Speichern

  Termin _bauen() {
    final startUtc = utcVon(_zone, _start.year, _start.month, _start.day, _start.hour, _start.minute);
    final endeUtc = utcVon(_zone, _ende.year, _ende.month, _ende.day, _ende.hour, _ende.minute);
    final v = widget.vorhanden;
    return Termin(
      id: v?.id ?? widget.cubit.neueId(),
      listId: _listId,
      titel: _titel.text.trim(),
      art: _art,
      personen: _personen.toList()..sort(),
      start: startUtc,
      ende: endeUtc.isAfter(startUtc) ? endeUtc : startUtc.add(const Duration(minutes: 30)),
      ganztaegig: _ganztaegig,
      ort: _ort.text.trim().isEmpty ? null : _ort.text.trim(),
      notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
      zeitzone: _zone,
      wiederholung: _wiederholung,
      erinnerungen: _erinnerungen,
      anhaenge: v?.anhaenge ?? const [],
      erstelltVon: v?.erstelltVon ?? _z.userId,
      erstelltAm: v?.erstelltAm,
    );
  }

  Future<void> _speichern() async {
    final s = AppLocalizations.of(context)!;
    if (_titel.text.trim().isEmpty) {
      _titel.text = s.artLabel(_art);
    }
    final t = _bauen();
    final konflikte = widget.cubit.konflikte(t);
    if (konflikte.isNotEmpty) {
      final weiter = await _konflikteBestaetigen(konflikte);
      if (weiter != true || !mounted) return;
    }
    setState(() => _speichert = true);
    try {
      await widget.cubit.speichern(t);
      if (!mounted) return;
      Navigator.of(context).pop(t);
    } catch (e) {
      if (!mounted) return;
      setState(() => _speichert = false);
      TdToast.show(context, s.kalFehler('$e'), variant: TdToastVariant.error);
    }
  }

  Future<bool?> _konflikteBestaetigen(List<Konflikt> konflikte) {
    final s = AppLocalizations.of(context)!;
    return showTdSheet<bool>(
      context,
      title: s.kalKonfliktTitel,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final k in konflikte.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: TdSpace.sm),
              child: Row(
                children: [
                  Icon(
                    k.art == KonfliktArt.urlaub ? Icons.beach_access_rounded : Icons.event_busy_rounded,
                    color: ctx.td.warning,
                  ),
                  const SizedBox(width: TdSpace.sm),
                  Expanded(
                    child: Text(
                      k.art == KonfliktArt.urlaub
                          ? s.kalKonfliktUrlaub(_z.nameVon(k.personId))
                          : s.kalKonfliktBelegt(_z.nameVon(k.personId), k.vorkommen.termin.titel),
                      style: ctx.text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: TdSpace.sm),
          TdButton.primary(
            label: s.kalTrotzdemSpeichern,
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: TdSpace.sm),
          TdButton.ghost(label: s.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final listen = _z.listen;
    final mitglieder = _z.mitgliederIdsDerListe(_listId).toSet();
    final personen = personenVon(_z.mitglieder.where((m) => mitglieder.contains(m.id)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Schnelleingabe
        if (widget.vorhanden == null) ...[
          _Schnelleingabe(
            controller: _schnell,
            hoert: _hoert,
            pegel: _pegel,
            erkannt: _erkannt,
            onChanged: _schnellGeaendert,
            onMic: widget.speech != null && speechInputSupported ? _diktieren : null,
            onUebernehmen: _uebernehmen,
            zone: _zone,
            locale: locale,
          ),
          const SizedBox(height: TdSpace.lg),
        ],
        TdTextField(
          controller: _titel,
          label: s.kalTitelFeld,
          hint: s.kalTitelHinweis,
          prefixIcon: TdTerminStil.of(context, _art).symbol,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TdSpace.md),
        // Art
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final a in TerminArt.values) ...[
                TdChip(
                  label: s.artLabel(a),
                  icon: TdTerminStil.of(context, a).symbol,
                  color: TdTerminStil.of(context, a).farbe,
                  selected: _art == a,
                  dense: true,
                  onTap: () => setState(() => _art = a),
                ),
                const SizedBox(width: TdSpace.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: TdSpace.lg),
        // Liste (nur wenn mehrere)
        if (listen.length > 1 && widget.vorhanden == null) ...[
          _Beschriftung(s.kalListeWaehlen),
          Wrap(
            spacing: TdSpace.sm,
            runSpacing: TdSpace.sm,
            children: [
              for (final l in listen)
                TdChip(
                  label: l.name,
                  icon: l.type == ListType.shopping ? Icons.shopping_basket_rounded : Icons.checklist_rounded,
                  selected: _listId == l.id,
                  dense: true,
                  onTap: () => setState(() {
                    _listId = l.id;
                    _personen.removeWhere((p) => !_z.mitgliederIdsDerListe(l.id).contains(p));
                  }),
                ),
            ],
          ),
          const SizedBox(height: TdSpace.lg),
        ],
        // Personen
        _Beschriftung(s.kalPersonen),
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
        // Zeiten
        Row(
          children: [
            Expanded(child: _Beschriftung(s.kalStart)),
            Text(s.kalGanztaegig, style: context.text.labelMedium),
            const SizedBox(width: TdSpace.xs),
            Switch.adaptive(value: _ganztaegig, onChanged: _ganztaegigSetzen),
          ],
        ),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            TdZeitPille(
              icon: Icons.calendar_today_rounded,
              label: DateFormatHelfer.datum(_start, locale),
              betont: true,
              onTap: () => _datumWaehlen(true),
            ),
            if (!_ganztaegig)
              TdZeitPille(
                icon: Icons.schedule_rounded,
                label: DateFormatHelfer.zeit(context, _start),
                onTap: () => _zeitWaehlen(true),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.md),
        _Beschriftung(s.kalEnde),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            TdZeitPille(
              icon: Icons.event_rounded,
              label: DateFormatHelfer.datum(
                _ganztaegig ? _ende.subtract(const Duration(days: 1)) : _ende,
                locale,
              ),
              gedaempft: _ganztaegig && _ende.difference(_start).inDays <= 1,
              onTap: () => _datumWaehlen(false),
            ),
            if (!_ganztaegig)
              TdZeitPille(
                icon: Icons.schedule_rounded,
                label: DateFormatHelfer.zeit(context, _ende),
                onTap: () => _zeitWaehlen(false),
              ),
            if (!_ganztaegig)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  s.dauerLabel(_ende.difference(_start)),
                  style: context.text.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.lg),
        // Wiederholung
        _Beschriftung(s.kalWiederholung),
        _WiederholungFeld(
          wert: _wiederholung,
          startWochentag: _start.weekday,
          onChanged: (w) => setState(() => _wiederholung = w),
          locale: locale,
        ),
        const SizedBox(height: TdSpace.lg),
        // Erinnerung
        _Beschriftung(s.kalErinnerung),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            TdChip(
              label: s.kalErinnerungKeine,
              selected: _erinnerungen.isEmpty,
              dense: true,
              onTap: () => setState(() => _erinnerungen = []),
            ),
            for (final m in (_ganztaegig ? const [0, 1440, 2880, 10080] : const [0, 10, 30, 60, 1440]))
              TdChip(
                label: s.erinnerungLabel(m),
                selected: _erinnerungen.contains(m),
                dense: true,
                onTap: () => setState(() {
                  if (!_erinnerungen.remove(m)) {
                    if (_erinnerungen.length < 5) _erinnerungen.add(m);
                  }
                  _erinnerungen.sort();
                }),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.lg),
        TdTextField(
          controller: _ort,
          label: s.kalOrt,
          prefixIcon: Icons.place_outlined,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TdSpace.md),
        TdTextField(
          controller: _notiz,
          label: s.kalNotiz,
          prefixIcon: Icons.notes_rounded,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: TdSpace.xl),
        TdButton.primary(
          label: s.save,
          icon: Icons.check_rounded,
          expanded: true,
          loading: _speichert,
          onPressed: _speichert ? null : _speichern,
        ),
      ],
    );
  }
}

/// Datums-/Zeitformate für die Pillen (naive Wanduhrzeit).
abstract final class DateFormatHelfer {
  static String datum(DateTime d, String locale) => datumKurz(d, locale);

  static String zeit(BuildContext context, DateTime d) {
    final l = MaterialLocalizations.of(context);
    return l.formatTimeOfDay(
      TimeOfDay(hour: d.hour, minute: d.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}

class _Beschriftung extends StatelessWidget {
  const _Beschriftung(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TdSpace.sm),
    child: Text(text, style: context.text.labelMedium?.copyWith(color: context.td.muted)),
  );
}

// ------------------------------------------------------------ Schnelleingabe

class _Schnelleingabe extends StatelessWidget {
  const _Schnelleingabe({
    required this.controller,
    required this.hoert,
    required this.pegel,
    required this.erkannt,
    required this.onChanged,
    required this.onMic,
    required this.onUebernehmen,
    required this.zone,
    required this.locale,
  });

  final TextEditingController controller;
  final bool hoert;
  final double pegel;
  final SchnelleingabeErgebnis? erkannt;
  final ValueChanged<String> onChanged;
  final VoidCallback? onMic;
  final VoidCallback onUebernehmen;
  final String zone;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final td = context.td;
    final e = erkannt;
    return TdCard(
      variant: TdCardVariant.gradient,
      padding: const EdgeInsets.all(TdSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: td.palette.onPrimary, size: 18),
              const SizedBox(width: TdSpace.sm),
              Expanded(
                child: Text(
                  hoert ? s.kalDiktatHinweis : s.kalSchnelleingabeHinweis,
                  style: context.text.bodySmall?.copyWith(color: td.palette.onPrimary.withValues(alpha: 0.9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: TdSpace.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.sentences,
                  style: context.text.bodyLarge,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.colors.surface,
                    hintText: s.kalTitelHinweis,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TdRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              if (onMic != null) ...[
                const SizedBox(width: TdSpace.sm),
                _MicKnopf(hoert: hoert, pegel: pegel, onTap: onMic!, label: s.voiceInput),
              ],
            ],
          ),
          if (e != null && (e.start != null || e.art != null || e.personenNamen.isNotEmpty || e.wiederholung != null))
            Padding(
              padding: const EdgeInsets.only(top: TdSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (e.titel.isNotEmpty) _ErkanntChip(label: e.titel),
                        if (e.art != null)
                          _ErkanntChip(
                            label: s.artLabel(e.art!),
                            icon: TdTerminStil.of(context, e.art!).symbol,
                          ),
                        for (final n in e.personenNamen)
                          _ErkanntChip(label: n, icon: Icons.person_rounded),
                        if (e.alle) _ErkanntChip(label: s.kalAlle, icon: Icons.groups_rounded),
                        if (e.start != null)
                          _ErkanntChip(
                            label: e.ganztaegig
                                ? '${datumKurz(e.start!, locale)}${e.ende != null && e.ende!.difference(e.start!).inDays > 1 ? ' – ${datumKurz(e.ende!.subtract(const Duration(days: 1)), locale)}' : ''}'
                                : '${datumKurz(e.start!, locale)} ${DateFormatHelfer.zeit(context, e.start!)}${e.ende != null ? '–${DateFormatHelfer.zeit(context, e.ende!)}' : ''}',
                            icon: Icons.schedule_rounded,
                          ),
                        if (e.wiederholung != null)
                          _ErkanntChip(
                            label: s.wiederholungLabel(e.wiederholung),
                            icon: Icons.repeat_rounded,
                          ),
                        if (e.unbekannt.isNotEmpty)
                          _ErkanntChip(
                            label: s.kalUnbekannteNamen(e.unbekannt.join(', ')),
                            icon: Icons.help_outline_rounded,
                            schwach: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TdSpace.sm),
                  TdButton.secondary(
                    label: s.kalSchnelleingabeUebernehmen,
                    icon: Icons.arrow_downward_rounded,
                    size: TdButtonSize.small,
                    onPressed: onUebernehmen,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Erkannter Bestandteil der Schnelleingabe: helle Pille auf dem Verlauf.
class _ErkanntChip extends StatelessWidget {
  const _ErkanntChip({required this.label, this.icon, this.schwach = false});

  final String label;
  final IconData? icon;
  final bool schwach;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: schwach ? 0.5 : 0.92),
        borderRadius: BorderRadius.circular(TdRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: td.palette.primary),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: const Color(0xFF1C1B22),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicKnopf extends StatelessWidget {
  const _MicKnopf({required this.hoert, required this.pegel, required this.onTap, required this.label});

  final bool hoert;
  final double pegel;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final reduziert = TdMotion.reduced(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: TdMotion.of(context, TdMotion.fast),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hoert ? td.palette.secondary : context.colors.surface,
            boxShadow: hoert && !reduziert
                ? [
                    BoxShadow(
                      color: td.palette.secondary.withValues(alpha: 0.45),
                      blurRadius: 8 + 24 * pegel.clamp(0, 1),
                      spreadRadius: 2 + 10 * pegel.clamp(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            hoert ? Icons.stop_rounded : Icons.mic_rounded,
            color: hoert ? Colors.white : td.palette.primary,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Wiederholung

class _WiederholungFeld extends StatelessWidget {
  const _WiederholungFeld({
    required this.wert,
    required this.startWochentag,
    required this.onChanged,
    required this.locale,
  });

  final Wiederholung? wert;
  final int startWochentag;
  final ValueChanged<Wiederholung?> onChanged;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final w = wert;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            TdChip(label: s.kalWdhKeine, selected: w == null, dense: true, onTap: () => onChanged(null)),
            for (final typ in WiederholungTyp.values)
              TdChip(
                label: switch (typ) {
                  WiederholungTyp.taeglich => s.kalWdhTaeglich,
                  WiederholungTyp.woechentlich => s.kalWdhWoechentlich,
                  WiederholungTyp.monatlich => s.kalWdhMonatlich,
                  WiederholungTyp.jaehrlich => s.kalWdhJaehrlich,
                },
                icon: Icons.repeat_rounded,
                selected: w?.typ == typ,
                dense: true,
                onTap: () => onChanged(
                  Wiederholung(
                    typ: typ,
                    intervall: w?.intervall ?? 1,
                    wochentage: typ == WiederholungTyp.woechentlich ? (w?.wochentage.isNotEmpty == true ? w!.wochentage : [startWochentag]) : const [],
                    bisDatum: w?.bisDatum,
                    anzahl: w?.anzahl,
                    ausnahmen: w?.ausnahmen ?? const [],
                  ),
                ),
              ),
          ],
        ),
        if (w != null) ...[
          const SizedBox(height: TdSpace.md),
          if (w.typ == WiederholungTyp.woechentlich)
            Row(
              children: [
                for (var tag = 1; tag <= 7; tag++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _TagKnopf(
                        label: wochentagKurz(context, tag),
                        selected: w.wochentage.contains(tag),
                        onTap: () {
                          final neu = {...w.wochentage};
                          if (!neu.remove(tag)) neu.add(tag);
                          if (neu.isEmpty) return;
                          onChanged(w.copyWith(wochentage: neu.toList()..sort()));
                        },
                      ),
                    ),
                  ),
              ],
            ),
          if (w.typ == WiederholungTyp.woechentlich) const SizedBox(height: TdSpace.md),
          Row(
            children: [
              Text(s.wiederholungLabel(w), style: context.text.bodyMedium),
              const Spacer(),
              TdIconButton(
                icon: Icons.remove_rounded,
                size: 36,
                onPressed: w.intervall > 1 ? () => onChanged(w.copyWith(intervall: w.intervall - 1)) : null,
              ),
              TdIconButton(
                icon: Icons.add_rounded,
                size: 36,
                onPressed: w.intervall < 52 ? () => onChanged(w.copyWith(intervall: w.intervall + 1)) : null,
              ),
            ],
          ),
          const SizedBox(height: TdSpace.sm),
          Wrap(
            spacing: TdSpace.sm,
            runSpacing: TdSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${s.kalWdhEnde}:', style: context.text.labelMedium?.copyWith(color: context.td.muted)),
              TdChip(
                label: s.kalWdhEndeNie,
                selected: w.endlos,
                dense: true,
                onTap: () => onChanged(w.copyWith(ohneEnde: true)),
              ),
              TdChip(
                label: w.bisDatum == null ? s.kalWdhEndeAm : datumKurz(lokalNaiv(w.bisDatum!), locale),
                icon: Icons.event_rounded,
                selected: w.bisDatum != null,
                dense: true,
                onTap: () async {
                  final heute = DateTime.now();
                  final tag = await showTdDatumWaehler(
                    context,
                    gewaehlt: w.bisDatum ?? heute.add(const Duration(days: 90)),
                    heute: heute,
                    titel: s.kalWdhEndeAm,
                    heuteLabel: s.kalHeute,
                    morgenLabel: s.kalMorgen,
                    fertigLabel: s.save,
                    locale: locale,
                  );
                  if (tag == null) return;
                  onChanged(Wiederholung(
                    typ: w.typ,
                    intervall: w.intervall,
                    wochentage: w.wochentage,
                    bisDatum: DateTime.utc(tag.year, tag.month, tag.day, 12),
                    ausnahmen: w.ausnahmen,
                  ));
                },
              ),
              TdChip(
                label: s.kalWdhEndeNach(w.anzahl ?? 10),
                icon: Icons.tag_rounded,
                selected: w.anzahl != null,
                dense: true,
                onTap: () => onChanged(Wiederholung(
                  typ: w.typ,
                  intervall: w.intervall,
                  wochentage: w.wochentage,
                  anzahl: w.anzahl == null ? 10 : (w.anzahl! >= 50 ? 5 : w.anzahl! + 5),
                  ausnahmen: w.ausnahmen,
                )),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TagKnopf extends StatelessWidget {
  const _TagKnopf({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: TdMotion.of(context, TdMotion.fast),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? td.primaryGradient : null,
            color: selected ? null : context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(TdRadius.sm),
          ),
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: selected ? td.palette.onPrimary : context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// UTC-Datum (Mittag) → naive Wanduhrzeit für die Anzeige des Enddatums.
DateTime lokalNaiv(DateTime utc) => DateTime(utc.year, utc.month, utc.day);
