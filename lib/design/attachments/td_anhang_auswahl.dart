/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../../services/attachment_service.dart';
import '../components/td_pressable.dart';
import '../components/td_sheet.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'anhang_texte.dart';

/// Öffnet das Blatt „Foto aufnehmen / Aus Galerie / Dokument“ und liefert
/// die gewählte Quelle; `null`, wenn abgebrochen.
Future<AnhangQuelle?> showTdAnhangQuelleSheet(
  BuildContext context, {
  bool kameraVerfuegbar = true,
}) {
  final l = anhangL10n(context);
  return showTdSheet<AnhangQuelle>(
    context,
    title: l.anhangQuelleTitel,
    builder: (ctx) => TdAnhangAuswahl(
      kameraVerfuegbar: kameraVerfuegbar,
      onAusgewaehlt: (q) => Navigator.of(ctx).pop(q),
    ),
  );
}

/// Inhalt des Auswahl-Blatts: große, freundliche Kacheln je Quelle.
class TdAnhangAuswahl extends StatelessWidget {
  const TdAnhangAuswahl({
    super.key,
    required this.onAusgewaehlt,
    this.kameraVerfuegbar = true,
  });

  final ValueChanged<AnhangQuelle> onAusgewaehlt;
  final bool kameraVerfuegbar;

  @override
  Widget build(BuildContext context) {
    final l = anhangL10n(context);
    final scheme = context.colors;
    final td = context.td;
    final kacheln = <_QuelleKachel>[
      if (kameraVerfuegbar)
        _QuelleKachel(
          quelle: AnhangQuelle.kamera,
          icon: Icons.photo_camera_rounded,
          titel: l.anhangFotoAufnehmen,
          hinweis: l.anhangFotoAufnehmenHinweis,
          farbe: scheme.primary,
        ),
      _QuelleKachel(
        quelle: AnhangQuelle.galerie,
        icon: Icons.photo_library_rounded,
        titel: l.anhangAusGalerie,
        hinweis: l.anhangAusGalerieHinweis,
        farbe: scheme.secondary,
      ),
      _QuelleKachel(
        quelle: AnhangQuelle.dokument,
        icon: Icons.description_rounded,
        titel: l.anhangDokument,
        hinweis: l.anhangDokumentHinweis,
        farbe: scheme.tertiary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Breit: nebeneinander; schmal: untereinander.
        final nebeneinander = constraints.maxWidth >= 420;
        final kinder = [
          for (final k in kacheln)
            _Kachel(
              kachel: k,
              waagerecht: !nebeneinander,
              dark: td.isDark,
              onTap: () => onAusgewaehlt(k.quelle),
            ),
        ];
        if (nebeneinander) {
          // Gleich hohe Kacheln, auch wenn die Texte verschieden umbrechen.
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < kinder.length; i++) ...[
                  if (i > 0) const SizedBox(width: TdSpace.md),
                  Expanded(child: kinder[i]),
                ],
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < kinder.length; i++) ...[
              if (i > 0) const SizedBox(height: TdSpace.md),
              kinder[i],
            ],
          ],
        );
      },
    );
  }
}

class _QuelleKachel {
  const _QuelleKachel({
    required this.quelle,
    required this.icon,
    required this.titel,
    required this.hinweis,
    required this.farbe,
  });

  final AnhangQuelle quelle;
  final IconData icon;
  final String titel;
  final String hinweis;
  final Color farbe;
}

class _Kachel extends StatelessWidget {
  const _Kachel({
    required this.kachel,
    required this.waagerecht,
    required this.dark,
    required this.onTap,
  });

  final _QuelleKachel kachel;
  final bool waagerecht;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final symbol = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: kachel.farbe.withValues(alpha: dark ? 0.28 : 0.14),
        borderRadius: TdRadius.control,
      ),
      alignment: Alignment.center,
      child: Icon(kachel.icon, size: 28, color: kachel.farbe),
    );
    final titel = Text(
      kachel.titel,
      style: context.text.titleMedium,
      textAlign: waagerecht ? TextAlign.start : TextAlign.center,
    );
    final hinweis = Text(
      kachel.hinweis,
      style: context.text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      textAlign: waagerecht ? TextAlign.start : TextAlign.center,
    );

    return TdPressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: kachel.titel,
      borderRadius: TdRadius.card,
      child: Container(
        padding: const EdgeInsets.all(TdSpace.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: TdRadius.card,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: waagerecht
            ? Row(
                children: [
                  symbol,
                  const SizedBox(width: TdSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        titel,
                        const SizedBox(height: TdSpace.xxs),
                        hinweis,
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  symbol,
                  const SizedBox(height: TdSpace.md),
                  titel,
                  const SizedBox(height: TdSpace.xxs),
                  hinweis,
                ],
              ),
      ),
    );
  }
}
