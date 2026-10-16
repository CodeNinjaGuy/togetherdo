/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal_links.dart';

/// Öffnet [uri] im Browser; zeigt bei Fehlschlag einen Hinweis.
Future<void> openLegalLink(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final errorText = AppLocalizations.of(context)?.linkOpenError;
  bool opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && errorText != null) {
    messenger?.showSnackBar(SnackBar(content: Text(errorText)));
  }
}

/// Zwei Textlinks „Datenschutzerklärung · Impressum“.
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => openLegalLink(context, LegalLinks.privacyPolicy),
          child: Text(l10n.privacyPolicy),
        ),
        const Text('·'),
        TextButton(
          onPressed: () => openLegalLink(context, LegalLinks.imprint),
          child: Text(l10n.imprint),
        ),
      ],
    );
  }
}
