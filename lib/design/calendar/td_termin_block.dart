/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../../calendar/models/termin.dart';
import '../components/td_pressable.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'td_termin_stil.dart';

/// Terminblock in Spuren-/Tagesansicht: farbige Kante links, zarte Fläche,
/// Titel und Zeit. Passt sich der verfügbaren Höhe/Breite an (nur Titel,
/// wenn wenig Platz).
class TdTerminBlock extends StatelessWidget {
  const TdTerminBlock({
    super.key,
    required this.art,
    required this.titel,
    this.zeit,
    this.onTap,
    this.kompakt = false,
    this.hervorgehoben = false,
    this.waagrecht = false,
  });

  final TerminArt art;
  final String titel;
  final String? zeit;
  final VoidCallback? onTap;
  final bool kompakt;
  final bool hervorgehoben;

  /// In waagrechten Spuren liegt die Kante oben statt links.
  final bool waagrecht;

  @override
  Widget build(BuildContext context) {
    final stil = TdTerminStil.of(context, art);
    final radius = BorderRadius.circular(TdRadius.sm);
    return TdPressable(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: zeit == null ? titel : '$titel, $zeit',
      child: AnimatedContainer(
        duration: TdMotion.of(context, TdMotion.fast),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: stil.fuellung(context),
          borderRadius: radius,
          border: hervorgehoben
              ? Border.all(color: stil.farbe, width: 1.5)
              : null,
        ),
        child: LayoutBuilder(
          builder: (ctx, c) {
            final zeigeZeit =
                !kompakt && zeit != null && c.maxHeight >= 40 && c.maxWidth >= 70;
            final zeigeSymbol = c.maxWidth >= 110 && c.maxHeight >= 22;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: waagrecht ? null : 0,
                  right: waagrecht ? 0 : null,
                  child: Container(
                    width: waagrecht ? null : 3,
                    height: waagrecht ? 3 : null,
                    color: stil.farbe,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: waagrecht ? 6 : 8,
                    right: 6,
                    top: waagrecht ? 5 : 3,
                    bottom: 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (zeigeSymbol) ...[
                            Icon(stil.symbol, size: 12, color: stil.text(ctx)),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              titel,
                              maxLines: c.maxHeight >= 56 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: ctx.text.labelMedium?.copyWith(
                                color: stil.text(ctx),
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (zeigeZeit)
                        Text(
                          zeit!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ctx.text.labelSmall?.copyWith(
                            color: stil.text(ctx).withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Band für ganztägige Einträge (Urlaub, Arbeit ganztägig, Geburtstag):
/// schmal, mit Symbol und Text, Streifenmuster für Urlaub.
class TdTerminBand extends StatelessWidget {
  const TdTerminBand({
    super.key,
    required this.art,
    required this.titel,
    this.onTap,
    this.hoehe = 22,
    this.abgerundetLinks = true,
    this.abgerundetRechts = true,
  });

  final TerminArt art;
  final String titel;
  final VoidCallback? onTap;
  final double hoehe;
  final bool abgerundetLinks;
  final bool abgerundetRechts;

  @override
  Widget build(BuildContext context) {
    final stil = TdTerminStil.of(context, art);
    final r = Radius.circular(hoehe / 2);
    final radius = BorderRadius.horizontal(
      left: abgerundetLinks ? r : Radius.zero,
      right: abgerundetRechts ? r : Radius.zero,
    );
    return TdPressable(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: titel,
      child: Container(
        height: hoehe,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: stil.band(context), borderRadius: radius),
        child: Stack(
          children: [
            if (art == TerminArt.urlaub)
              Positioned.fill(
                child: CustomPaint(
                  painter: _StreifenPainter(stil.farbe.withValues(alpha: 0.18)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(stil.symbol, size: 12, color: stil.text(context)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      titel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: stil.text(context),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreifenPainter extends CustomPainter {
  _StreifenPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4;
    for (var x = -size.height; x < size.width + size.height; x += 12) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_StreifenPainter old) => old.color != color;
}

/// Kleiner Punkt/Strich in der Monatszelle, Farbe je Person oder Art.
class TdTerminPunkt extends StatelessWidget {
  const TdTerminPunkt({super.key, required this.farbe, this.breit = false});

  final Color farbe;
  final bool breit;

  @override
  Widget build(BuildContext context) => Container(
    width: breit ? 14 : 6,
    height: breit ? 4 : 6,
    decoration: BoxDecoration(
      color: farbe,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}
