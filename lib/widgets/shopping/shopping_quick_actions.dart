/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';

/// Schnellaktionen der Einkaufsliste unten rechts: kleine Knöpfe für
/// Scannen (und Sprache) über dem großen „Hinzufügen“. Blenden gestaffelt
/// ein; Knöpfe ohne Aktion werden ausgeblendet (Plattform ohne Kamera).
class ShoppingQuickActions extends StatelessWidget {
  const ShoppingQuickActions({
    super.key,
    required this.onAdd,
    this.onScan,
    this.onVoice,
  });

  final VoidCallback onAdd;
  final VoidCallback? onScan;
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = context.colors;
    final td = context.td;
    final secondaries =
        <({IconData icon, String label, VoidCallback onTap, String tag})>[
          if (onVoice != null)
            (
              icon: Icons.mic_rounded,
              label: l10n.voiceInput,
              onTap: onVoice!,
              tag: 'fab-voice',
            ),
          if (onScan != null)
            (
              icon: Icons.qr_code_scanner_rounded,
              label: l10n.scanBarcode,
              onTap: onScan!,
              tag: 'fab-scan',
            ),
        ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < secondaries.length; i++) ...[
          TdFadeSlideIn(
            index: secondaries.length - i,
            offset: const Offset(0, 0.3),
            child: Tooltip(
              message: secondaries[i].label,
              child: FloatingActionButton.small(
                heroTag: secondaries[i].tag,
                tooltip: null,
                elevation: 2,
                backgroundColor: scheme.surfaceContainerHigh,
                foregroundColor: scheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: TdRadius.control,
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                onPressed: secondaries[i].onTap,
                child: Icon(secondaries[i].icon),
              ),
            ),
          ),
          const SizedBox(height: TdSpace.md),
        ],
        TdFadeSlideIn(
          offset: const Offset(0, 0.3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: TdRadius.control,
              boxShadow: TdShadows.glow(td.palette.primary),
            ),
            child: FloatingActionButton.extended(
              heroTag: 'fab-add',
              onPressed: onAdd,
              elevation: 0,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addItem),
            ),
          ),
        ),
      ],
    );
  }
}
