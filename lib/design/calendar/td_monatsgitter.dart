/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

/// Inhalt unter der Tageszahl einer Monatszelle (Punkte, Bänder).
typedef TdZellenInhalt = Widget? Function(BuildContext context, DateTime tag);

/// Monatsgitter (Mo–So, 6 Reihen). Zellen zeigen Tageszahl, heute als
/// Ring, gewählt als gefüllte Pille; darunter beliebiger Inhalt.
/// Zellen melden ihr Rechteck beim Antippen (für den Zoom-Übergang).
class TdMonatsGitter extends StatelessWidget {
  const TdMonatsGitter({
    super.key,
    required this.monat,
    required this.heute,
    this.gewaehlt,
    this.onTagGewaehlt,
    this.inhalt,
    this.locale,
    this.kompakt = false,
    this.zellenHoehe,
  });

  /// Erster Tag des Monats (reiner Tag).
  final DateTime monat;
  final DateTime heute;
  final DateTime? gewaehlt;

  /// Liefert den Tag und das Rechteck der Zelle (global).
  final void Function(DateTime tag, Rect zelle)? onTagGewaehlt;
  final TdZellenInhalt? inhalt;
  final String? locale;
  final bool kompakt;
  final double? zellenHoehe;

  /// Montag vor oder am 1. des Monats.
  DateTime get _erster =>
      DateTime.utc(monat.year, monat.month, 1).subtract(
        Duration(days: DateTime.utc(monat.year, monat.month, 1).weekday - 1),
      );

  @override
  Widget build(BuildContext context) {
    final wochentage = DateFormat.E(locale);
    final erster = _erster;
    final montag = DateTime.utc(2024, 1, 1); // ein Montag für die Köpfe
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    wochentage.format(montag.add(Duration(days: i))).replaceAll('.', ''),
                    style: context.text.labelSmall?.copyWith(
                      color: i >= 5 ? context.td.muted.withValues(alpha: 0.7) : context.td.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.xs),
        for (var reihe = 0; reihe < 6; reihe++)
          Row(
            children: [
              for (var spalte = 0; spalte < 7; spalte++)
                Expanded(
                  child: _Zelle(
                    tag: erster.add(Duration(days: reihe * 7 + spalte)),
                    imMonat: erster.add(Duration(days: reihe * 7 + spalte)).month == monat.month,
                    heute: erster.add(Duration(days: reihe * 7 + spalte)) == heute,
                    gewaehlt: erster.add(Duration(days: reihe * 7 + spalte)) == gewaehlt,
                    inhalt: inhalt,
                    kompakt: kompakt,
                    hoehe: zellenHoehe ?? (kompakt ? 40 : 64),
                    onTap: onTagGewaehlt,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Zelle extends StatelessWidget {
  const _Zelle({
    required this.tag,
    required this.imMonat,
    required this.heute,
    required this.gewaehlt,
    required this.inhalt,
    required this.kompakt,
    required this.hoehe,
    required this.onTap,
  });

  final DateTime tag;
  final bool imMonat;
  final bool heute;
  final bool gewaehlt;
  final TdZellenInhalt? inhalt;
  final bool kompakt;
  final double hoehe;
  final void Function(DateTime, Rect)? onTap;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    final zahlFarbe = gewaehlt
        ? td.palette.onPrimary
        : !imMonat
            ? td.muted.withValues(alpha: 0.4)
            : heute
                ? td.palette.primary
                : tag.weekday >= 6
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface;
    final inhaltWidget = imMonat ? inhalt?.call(context, tag) : null;
    return Semantics(
      button: onTap != null,
      selected: gewaehlt,
      label: DateFormat.yMMMMEEEEd().format(tag),
      child: Builder(
        builder: (ctx) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  final box = ctx.findRenderObject() as RenderBox?;
                  final rect = box == null
                      ? Rect.zero
                      : box.localToGlobal(Offset.zero) & box.size;
                  onTap!(tag, rect);
                },
          child: SizedBox(
            height: hoehe,
            child: Column(
              children: [
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: TdMotion.of(context, TdMotion.fast),
                  width: kompakt ? 28 : 30,
                  height: kompakt ? 28 : 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gewaehlt ? td.primaryGradient : null,
                    border: heute && !gewaehlt
                        ? Border.all(color: td.palette.primary, width: 1.5)
                        : null,
                    boxShadow: gewaehlt ? TdShadows.glow(td.palette.primary) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${tag.day}',
                    style: (kompakt ? context.text.labelMedium : context.text.titleSmall)
                        ?.copyWith(
                      color: zahlFarbe,
                      fontWeight: heute || gewaehlt ? FontWeight.w800 : FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (inhaltWidget != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 3, 2, 2),
                      child: inhaltWidget,
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
