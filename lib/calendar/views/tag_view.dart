/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Tagesansicht als Zoom-Ziel aus dem Monat: wächst aus der angetippten
/// Zelle heraus (bei „Bewegung reduzieren“ nur Überblenden). Zeigt die
/// Spuren des Tages und darunter die Liste.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../widgets/kalender_hilfen.dart';
import 'agenda_view.dart';
import 'spuren_view.dart';

/// Öffnet die Tagesansicht mit Zoom aus `zelle` (globales Rechteck).
Future<void> zeigeTagMitZoom(
  BuildContext context, {
  required KalenderCubit cubit,
  required DateTime tag,
  required Rect zelle,
  required ValueChanged<Vorkommen> onVorkommen,
  required void Function(DateTime, String) onFrei,
}) {
  final groesse = MediaQuery.sizeOf(context);
  final reduziert = TdMotion.reduced(context);
  final zentrum = zelle == Rect.zero
      ? Alignment.center
      : Alignment(
          (zelle.center.dx / groesse.width) * 2 - 1,
          (zelle.center.dy / groesse.height) * 2 - 1,
        );
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: reduziert ? TdMotion.fast : TdMotion.page,
      reverseTransitionDuration: reduziert ? TdMotion.fast : TdMotion.base,
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      pageBuilder: (ctx, a, s) => BlocProvider.value(
        value: cubit,
        child: TagView(tag: tag, onVorkommen: onVorkommen, onFrei: onFrei),
      ),
      transitionsBuilder: (ctx, anim, _, child) {
        final kurve = CurvedAnimation(parent: anim, curve: TdMotion.emphasized);
        if (reduziert) return FadeTransition(opacity: kurve, child: child);
        return FadeTransition(
          opacity: kurve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.2, end: 1).animate(kurve),
            alignment: zentrum,
            child: child,
          ),
        );
      },
    ),
  );
}

class TagView extends StatelessWidget {
  const TagView({
    super.key,
    required this.tag,
    required this.onVorkommen,
    required this.onFrei,
  });

  final DateTime tag;
  final ValueChanged<Vorkommen> onVorkommen;
  final void Function(DateTime, String) onFrei;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return BlocBuilder<KalenderCubit, KalenderZustand>(
      builder: (ctx, z) {
        final zustand = z.copyWith(fokus: tag);
        final von = utcVon(z.zeitzone, tag.year, tag.month, tag.day);
        final anzahl = zustand.vorkommen(von, von.add(const Duration(days: 1))).length;
        final hoehe = MediaQuery.sizeOf(ctx).height;
        return Scaffold(
          backgroundColor: ctx.colors.surface,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(datumText(ctx, tag), style: ctx.text.titleMedium),
                Text(
                  s.kalTermineAnzahl(anzahl),
                  style: ctx.text.bodySmall,
                ),
              ],
            ),
            leading: TdIconButton(
              icon: Icons.close_rounded,
              tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
              onPressed: () => Navigator.of(ctx).maybePop(),
            ),
          ),
          body: Column(
            children: [
              SizedBox(
                height: (zustand.sichtbareMitglieder.length * 76.0 + 40).clamp(160.0, hoehe * 0.55),
                child: SpurenView(
                  zustand: zustand,
                  mitStreifen: false,
                  onTag: (_) {},
                  onVorkommen: onVorkommen,
                  onFrei: onFrei,
                ),
              ),
              Divider(height: 1, color: ctx.colors.outlineVariant.withValues(alpha: 0.5)),
              Expanded(
                child: AgendaView(
                  zustand: zustand,
                  onVorkommen: onVorkommen,
                  heute: tag,
                  tage: 1,
                  mitAbschnitten: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
