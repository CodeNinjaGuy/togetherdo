/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';

/// Waagrechte Stundenachse der Spuren-Ansicht: Stundenstriche, Beschriftung
/// und sanfte Halbstunden-Linien. Zeichnet nur, was sichtbar ist.
class TdZeitachse extends StatelessWidget {
  const TdZeitachse({
    super.key,
    required this.stundenBreite,
    required this.vonStunde,
    required this.bisStunde,
    this.hoehe = 28,
    this.beschriftung,
  });

  final double stundenBreite;
  final int vonStunde;
  final int bisStunde;
  final double hoehe;

  /// Text je Stunde (Standard „6“, „12“ …; mit Lokalisierung „6 Uhr“/„6 am“).
  final String Function(int stunde)? beschriftung;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hoehe,
      width: stundenBreite * (bisStunde - vonStunde),
      child: CustomPaint(
        painter: _AchsePainter(
          stundenBreite: stundenBreite,
          von: vonStunde,
          bis: bisStunde,
          textStil: context.text.labelSmall!.copyWith(
            color: context.td.muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          beschriftung: beschriftung ?? (h) => '$h',
          linie: context.colors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _AchsePainter extends CustomPainter {
  _AchsePainter({
    required this.stundenBreite,
    required this.von,
    required this.bis,
    required this.textStil,
    required this.beschriftung,
    required this.linie,
  });

  final double stundenBreite;
  final int von;
  final int bis;
  final TextStyle textStil;
  final String Function(int) beschriftung;
  final Color linie;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = linie
      ..strokeWidth = 1;
    for (var h = von; h <= bis; h++) {
      final x = (h - von) * stundenBreite;
      canvas.drawLine(Offset(x, size.height - 6), Offset(x, size.height), p);
      if (h == bis) continue;
      final tp = TextPainter(
        text: TextSpan(text: beschriftung(h), style: textStil),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 4, size.height - 8 - tp.height));
    }
  }

  @override
  bool shouldRepaint(_AchsePainter old) =>
      old.stundenBreite != stundenBreite ||
      old.von != von ||
      old.bis != bis ||
      old.linie != linie ||
      old.textStil != textStil;
}

/// Senkrechte Rasterlinien hinter den Spuren (Stunden kräftiger, halbe
/// Stunden zart) – ein Painter für die gesamte Fläche, sehr günstig.
class TdStundenraster extends StatelessWidget {
  const TdStundenraster({
    super.key,
    required this.stundenBreite,
    required this.anzahlStunden,
  });

  final double stundenBreite;
  final int anzahlStunden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.outlineVariant;
    return CustomPaint(
      painter: _RasterPainter(
        stundenBreite: stundenBreite,
        anzahl: anzahlStunden,
        stunde: c.withValues(alpha: 0.55),
        halb: c.withValues(alpha: 0.22),
      ),
    );
  }
}

class _RasterPainter extends CustomPainter {
  _RasterPainter({
    required this.stundenBreite,
    required this.anzahl,
    required this.stunde,
    required this.halb,
  });

  final double stundenBreite;
  final int anzahl;
  final Color stunde;
  final Color halb;

  @override
  void paint(Canvas canvas, Size size) {
    final ps = Paint()
      ..color = stunde
      ..strokeWidth = 1;
    final ph = Paint()
      ..color = halb
      ..strokeWidth = 1;
    for (var h = 0; h <= anzahl; h++) {
      final x = h * stundenBreite;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), ps);
      if (h < anzahl && stundenBreite >= 48) {
        final xh = x + stundenBreite / 2;
        canvas.drawLine(Offset(xh, 0), Offset(xh, size.height), ph);
      }
    }
  }

  @override
  bool shouldRepaint(_RasterPainter old) =>
      old.stundenBreite != stundenBreite ||
      old.anzahl != anzahl ||
      old.stunde != stunde ||
      old.halb != halb;
}

/// „Jetzt“-Linie: feine Linie in der Akzentfarbe mit Punkt oben, pulsiert
/// sanft (nicht bei „Bewegung reduzieren“).
class TdJetztLinie extends StatefulWidget {
  const TdJetztLinie({super.key, this.farbe, this.breite = 2, this.pulsieren = true});

  final Color? farbe;
  final double breite;

  /// Sanftes Pulsieren des Punkts (aus bei fester Zeit, z. B. in Tests).
  final bool pulsieren;

  @override
  State<TdJetztLinie> createState() => _TdJetztLinieState();
}

class _TdJetztLinieState extends State<TdJetztLinie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.pulsieren || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farbe = widget.farbe ?? context.td.palette.secondary;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final puls = 1 + 0.35 * Curves.easeInOut.transform(_c.value);
          return Column(
            children: [
              Transform.scale(
                scale: puls,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: farbe,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: farbe.withValues(alpha: 0.5), blurRadius: 8),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(width: widget.breite, color: farbe),
              ),
            ],
          );
        },
      ),
    );
  }
}
