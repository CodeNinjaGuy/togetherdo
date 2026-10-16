/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/td_button.dart';
import '../components/td_chip.dart';
import '../components/td_sheet.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'td_monatsgitter.dart';

/// Pille für Datum oder Uhrzeit im Formular: Symbol + Text, antippbar.
class TdZeitPille extends StatelessWidget {
  const TdZeitPille({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.betont = false,
    this.gedaempft = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool betont;
  final bool gedaempft;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TdRadius.md),
        child: AnimatedContainer(
          duration: TdMotion.of(context, TdMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: betont
                ? td.palette.primary.withValues(alpha: td.isDark ? 0.25 : 0.1)
                : scheme.surfaceContainerHighest.withValues(alpha: td.isDark ? 0.5 : 0.8),
            borderRadius: BorderRadius.circular(TdRadius.md),
            border: Border.all(
              color: betont ? td.palette.primary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: betont ? td.palette.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  color: gedaempft
                      ? td.muted
                      : betont
                          ? td.palette.primary
                          : scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Datum wählen: Monatsgitter mit Blättern, Schnellwahl (heute/morgen).
Future<DateTime?> showTdDatumWaehler(
  BuildContext context, {
  required DateTime gewaehlt,
  required DateTime heute,
  required String titel,
  required String heuteLabel,
  required String morgenLabel,
  required String fertigLabel,
  String? locale,
}) {
  return showTdSheet<DateTime>(
    context,
    title: titel,
    builder: (ctx) => _DatumWaehler(
      gewaehlt: DateTime.utc(gewaehlt.year, gewaehlt.month, gewaehlt.day),
      heute: DateTime.utc(heute.year, heute.month, heute.day),
      heuteLabel: heuteLabel,
      morgenLabel: morgenLabel,
      fertigLabel: fertigLabel,
      locale: locale,
    ),
  );
}

class _DatumWaehler extends StatefulWidget {
  const _DatumWaehler({
    required this.gewaehlt,
    required this.heute,
    required this.heuteLabel,
    required this.morgenLabel,
    required this.fertigLabel,
    this.locale,
  });

  final DateTime gewaehlt;
  final DateTime heute;
  final String heuteLabel;
  final String morgenLabel;
  final String fertigLabel;
  final String? locale;

  @override
  State<_DatumWaehler> createState() => _DatumWaehlerState();
}

class _DatumWaehlerState extends State<_DatumWaehler> {
  late DateTime _tag = widget.gewaehlt;
  late DateTime _monat = DateTime.utc(widget.gewaehlt.year, widget.gewaehlt.month);
  int _richtung = 0;

  void _blaettern(int delta) => setState(() {
    _richtung = delta;
    _monat = DateTime.utc(_monat.year, _monat.month + delta);
  });

  void _waehlen(DateTime t) => setState(() {
    _tag = t;
    _monat = DateTime.utc(t.year, t.month);
  });

  @override
  Widget build(BuildContext context) {
    final monatName = DateFormat.yMMMM(widget.locale).format(_monat);
    final reduziert = TdMotion.reduced(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            TdChip(
              label: widget.heuteLabel,
              selected: _tag == widget.heute,
              dense: true,
              onTap: () => _waehlen(widget.heute),
            ),
            const SizedBox(width: TdSpace.sm),
            TdChip(
              label: widget.morgenLabel,
              selected: _tag == widget.heute.add(const Duration(days: 1)),
              dense: true,
              onTap: () => _waehlen(widget.heute.add(const Duration(days: 1))),
            ),
          ],
        ),
        const SizedBox(height: TdSpace.md),
        Row(
          children: [
            TdIconButton(
              icon: Icons.chevron_left_rounded,
              onPressed: () => _blaettern(-1),
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: TdMotion.of(context, TdMotion.fast),
                  child: Text(
                    monatName,
                    key: ValueKey(monatName),
                    style: context.text.titleMedium,
                  ),
                ),
              ),
            ),
            TdIconButton(
              icon: Icons.chevron_right_rounded,
              onPressed: () => _blaettern(1),
            ),
          ],
        ),
        const SizedBox(height: TdSpace.sm),
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) _blaettern(1);
            if (v > 200) _blaettern(-1);
          },
          child: AnimatedSwitcher(
            duration: TdMotion.of(context, TdMotion.base),
            switchInCurve: TdMotion.standard,
            transitionBuilder: (child, anim) {
              if (reduziert) return FadeTransition(opacity: anim, child: child);
              final eingehend = child.key == ValueKey(_monat);
              final offset = Tween<Offset>(
                begin: Offset(eingehend ? 0.25 * _richtung : -0.25 * _richtung, 0),
                end: Offset.zero,
              ).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: offset, child: child),
              );
            },
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            child: TdMonatsGitter(
              key: ValueKey(_monat),
              monat: _monat,
              heute: widget.heute,
              gewaehlt: _tag,
              kompakt: true,
              locale: widget.locale,
              onTagGewaehlt: (t, _) => _waehlen(t),
            ),
          ),
        ),
        const SizedBox(height: TdSpace.lg),
        TdButton.primary(
          label: widget.fertigLabel,
          expanded: true,
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(_tag),
        ),
      ],
    );
  }
}

/// Uhrzeit wählen: Schnellwahl-Chips und Rad.
Future<TimeOfDay?> showTdZeitWaehler(
  BuildContext context, {
  required TimeOfDay gewaehlt,
  required String titel,
  required String fertigLabel,
  List<TimeOfDay> schnellwahl = const [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 15, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
  ],
}) {
  return showTdSheet<TimeOfDay>(
    context,
    title: titel,
    builder: (ctx) => _ZeitWaehler(
      gewaehlt: gewaehlt,
      fertigLabel: fertigLabel,
      schnellwahl: schnellwahl,
    ),
  );
}

class _ZeitWaehler extends StatefulWidget {
  const _ZeitWaehler({
    required this.gewaehlt,
    required this.fertigLabel,
    required this.schnellwahl,
  });

  final TimeOfDay gewaehlt;
  final String fertigLabel;
  final List<TimeOfDay> schnellwahl;

  @override
  State<_ZeitWaehler> createState() => _ZeitWaehlerState();
}

class _ZeitWaehlerState extends State<_ZeitWaehler> {
  late TimeOfDay _zeit = widget.gewaehlt;
  late DateTime _rad = DateTime(2000, 1, 1, _zeit.hour, _zeit.minute);
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final loc = MaterialLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in widget.schnellwahl) ...[
                TdChip(
                  label: loc.formatTimeOfDay(s, alwaysUse24HourFormat: use24),
                  selected: s == _zeit,
                  dense: true,
                  onTap: () => setState(() {
                    _zeit = s;
                    _rad = DateTime(2000, 1, 1, s.hour, s.minute);
                    _version++;
                  }),
                ),
                const SizedBox(width: TdSpace.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: TdSpace.sm),
        SizedBox(
          height: 180,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: context.td.isDark ? Brightness.dark : Brightness.light,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: context.text.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            child: CupertinoDatePicker(
              key: ValueKey(_version),
              mode: CupertinoDatePickerMode.time,
              use24hFormat: use24,
              minuteInterval: 5,
              initialDateTime: DateTime(
                2000,
                1,
                1,
                _rad.hour,
                _rad.minute - _rad.minute % 5,
              ),
              onDateTimeChanged: (d) =>
                  _zeit = TimeOfDay(hour: d.hour, minute: d.minute),
            ),
          ),
        ),
        const SizedBox(height: TdSpace.md),
        TdButton.primary(
          label: widget.fertigLabel,
          expanded: true,
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(_zeit),
        ),
      ],
    );
  }
}
