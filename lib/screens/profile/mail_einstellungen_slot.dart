/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Platz in den Benachrichtigungs-Einstellungen für das Widget
// `lib/calendar/widgets/mail_einstellungen.dart` des Kalender-Helfers
// (E-Mail-Erinnerungen über Amazon SES: Push/E-Mail je Erinnerung,
// Wochenüberblick, Abmelden). Beim Merge wird dieser Slot durch das echte
// Widget ersetzt; bis dahin eine ruhige Hinweiskarte.

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';

class MailEinstellungenSlot extends StatelessWidget {
  const MailEinstellungenSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TdCard(
      variant: TdCardVariant.outlined,
      child: Row(
        children: [
          Icon(Icons.mail_outline_rounded, color: context.td.muted),
          const SizedBox(width: TdSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.mailReminders, style: context.text.titleSmall),
                Text(l10n.comingSoon, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
