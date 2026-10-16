/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'td_termin_block.dart';

/// Wochenstreifen: sieben Tage, gewählter Tag als Pille, heute mit Punkt,
/// darunter kleine Farbpunkte je Person. Wischen wechselt die Woche.
class TdDatumStreifen extends StatefulWidget {
  const TdDatumStreifen({
    super.key,
    required this.gewaehlt,
    required this.onGewaehlt,
    required this.heute,
    this.punkte = const {},
    this.locale,
  });

  /// Reiner Tag (UTC-Mitternacht).
  final DateTime gewaehlt;
  final ValueChanged<DateTime> onGewaehlt;
  final DateTime heute;

  /// Farbpunkte je Tag (`JJJJ-MM-TT` → Farben, max. 4 gezeigt).
  final Map<String, List<Color>> punkte;
  final String? locale;

  @override
  State<TdDatumStreifen> createState() => _TdDatumStreifenState();
}

class _TdDatumStreifenState extends State<TdDatumStreifen> {
  static const _basis = 5000;
  late final PageController _controller;
  late DateTime _basisMontag;

  @override
  void initState() {
    super.initState();
    _basisMontag = _montag(widget.gewaehlt);
    _controller = PageController(initialPage: _basis);
  }

  static DateTime _montag(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  int _seiteFuer(DateTime tag) =>
      _basis + _montag(tag).difference(_basisMontag).inDays ~/ 7;

  @override
  void didUpdateWidget(covariant TdDatumStreifen old) {
    super.didUpdateWidget(old);
    if (_montag(old.gewaehlt) != _montag(widget.gewaehlt) && _controller.hasClients) {
      final ziel = _seiteFuer(widget.gewaehlt);
      if ((_controller.page ?? _basis).round() != ziel) {
        final reduziert = TdMotion.reduced(context);
        if (reduziert) {
          _controller.jumpToPage(ziel);
        } else {
          _controller.animateToPage(
            ziel,
            duration: TdMotion.base,
            curve: TdMotion.standard,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _schluessel(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final wochentag = DateFormat.E(widget.locale);
    return SizedBox(
      height: 74,
      child: PageView.builder(
        controller: _controller,
        onPageChanged: (seite) {
          // Beim Wischen den gleichen Wochentag der neuen Woche wählen.
          final montag = _basisMontag.add(Duration(days: (seite - _basis) * 7));
          final neu = montag.add(Duration(days: widget.gewaehlt.weekday - 1));
          if (neu != widget.gewaehlt) widget.onGewaehlt(neu);
        },
        itemBuilder: (ctx, seite) {
          final montag = _basisMontag.add(Duration(days: (seite - _basis) * 7));
          return Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _Tag(
                    tag: montag.add(Duration(days: i)),
                    gewaehlt: montag.add(Duration(days: i)) == widget.gewaehlt,
                    heute: montag.add(Duration(days: i)) == widget.heute,
                    label: wochentag.format(montag.add(Duration(days: i))),
                    punkte: widget.punkte[_schluessel(montag.add(Duration(days: i)))] ?? const [],
                    onTap: () => widget.onGewaehlt(montag.add(Duration(days: i))),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.tag,
    required this.gewaehlt,
    required this.heute,
    required this.label,
    required this.punkte,
    required this.onTap,
  });

  final DateTime tag;
  final bool gewaehlt;
  final bool heute;
  final String label;
  final List<Color> punkte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    final wochenende = tag.weekday >= 6;
    final textFarbe = gewaehlt
        ? td.palette.onPrimary
        : heute
            ? td.palette.primary
            : wochenende
                ? td.muted
                : scheme.onSurface;
    return Semantics(
      button: true,
      selected: gewaehlt,
      label: DateFormat.yMMMMEEEEd().format(tag),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: TdMotion.of(context, TdMotion.base),
            curve: TdMotion.emphasized,
            decoration: BoxDecoration(
              gradient: gewaehlt ? td.primaryGradient : null,
              borderRadius: BorderRadius.circular(TdRadius.md),
              boxShadow: gewaehlt ? TdShadows.glow(td.palette.primary) : null,
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.replaceAll('.', ''),
                  style: context.text.labelSmall?.copyWith(
                    color: textFarbe.withValues(alpha: gewaehlt ? 0.9 : 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tag.day}',
                  style: context.text.titleMedium?.copyWith(
                    color: textFarbe,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 6,
                  child: punkte.isEmpty
                      ? (heute && !gewaehlt
                            ? TdTerminPunkt(farbe: td.palette.primary)
                            : null)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final f in punkte.take(4)) ...[
                              TdTerminPunkt(
                                farbe: gewaehlt ? td.palette.onPrimary.withValues(alpha: 0.9) : f,
                              ),
                              const SizedBox(width: 2),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
