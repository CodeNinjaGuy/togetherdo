/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Platzhalter für das Navigationsziel „Kalender“ (Route `/kalender`).
// Laut Vertrag vom 2026-10-16 liefert der Kalender-Helfer `CalendarScreen`
// in `lib/calendar/screens/calendar_screen.dart`; beim Merge wird dieser
// Platzhalter durch den echten Bildschirm ersetzt und die Datei entfernt.

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../design/td_design.dart';

class KalenderPlatzhalter extends StatelessWidget {
  const KalenderPlatzhalter({super.key, this.listId});

  /// Optionale Vorauswahl (`/kalender?liste=<listId>`).
  final String? listId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: TdFadeSlideIn(
            child: TdEmptyState(
              icon: Icons.calendar_month_rounded,
              title: l10n.navCalendar,
              message: l10n.calendarComingSoon,
            ),
          ),
        ),
      ),
    );
  }
}

/// Platz auf „Heute“ für die Karte `HeuteKalenderKarte` (Parameter
/// `listIds`) des Kalender-Helfers. Bis zum Merge eine ruhige
/// Karte mit Verweis auf den Kalender.
class HeuteKalenderSlot extends StatelessWidget {
  const HeuteKalenderSlot({super.key, required this.listIds, this.onOpen});

  final List<String> listIds;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TdCard(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.tertiaryContainer,
              borderRadius: TdRadius.control,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.calendar_month_rounded,
              color: context.colors.tertiary,
            ),
          ),
          const SizedBox(width: TdSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.navCalendar, style: context.text.titleMedium),
                Text(l10n.calendarComingSoon, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.td.muted),
        ],
      ),
    );
  }
}
