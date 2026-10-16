/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Auswahl der Feiertagsregion: „Keine“, Österreich, Deutschland und
/// darunter das Bundesland als Chips.
library;

import 'package:flutter/material.dart';

import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../logic/feiertage.dart';

class FeiertagsRegionWahl extends StatelessWidget {
  const FeiertagsRegionWahl({
    super.key,
    required this.region,
    required this.onChanged,
  });

  /// Aktueller Code (`AT-9`, `DE-BY`) oder `null` für keine Feiertage.
  final String? region;
  final ValueChanged<String?> onChanged;

  /// Erste Region eines Landes beim Umschalten (Hauptstadt).
  static const _standard = {'AT': 'AT-9', 'DE': 'DE-BE'};

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final sprache = Localizations.localeOf(context).languageCode;
    final aktuell = feiertagsRegion(region);
    final land = aktuell?.land;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.feiertagRegion,
          style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: TdSpace.sm),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            TdChip(
              label: s.feiertagKeine,
              icon: Icons.block_rounded,
              selected: land == null,
              onTap: () => onChanged(null),
            ),
            TdChip(
              label: s.feiertagOesterreich,
              selected: land == 'AT',
              onTap: () => onChanged(_standard['AT']),
            ),
            TdChip(
              label: s.feiertagDeutschland,
              selected: land == 'DE',
              onTap: () => onChanged(_standard['DE']),
            ),
          ],
        ),
        AnimatedSize(
          duration: TdMotion.of(context, TdMotion.base),
          curve: TdMotion.standard,
          alignment: Alignment.topLeft,
          child: land == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: TdSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.feiertagBundesland,
                        style: context.text.labelSmall?.copyWith(
                          color: context.td.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: TdSpace.sm),
                      Wrap(
                        spacing: TdSpace.sm,
                        runSpacing: TdSpace.sm,
                        children: [
                          for (final r in feiertagsRegionen.where((r) => r.land == land))
                            TdChip(
                              label: r.name(sprache),
                              selected: r.code == region,
                              dense: true,
                              onTap: () => onChanged(r.code),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
