/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Jahresüberblick auf einem Bildschirm:
///
/// 1. **Jahresband** – das ganze Jahr als ein durchgehender Streifen
///    (365 Tage nebeneinander). Je Mitglied eine schmale Zeile: Urlaub und
///    mehrtägige Termine als Farbbänder in der Personenfarbe; darunter eine
///    Feiertagszeile und eine **Heatmap-Zeile** je Woche in der Markenfarbe
///    (je voller die Woche, je kräftiger). Heute als senkrechte Linie.
///    **Urlaubsplanung** direkt im Band: lange drücken und ziehen oder Anfang
///    und Ende antippen → `onZeitraum(von, bis)`.
/// 2. **Alle frei** – Chips mit den Zeiträumen, in denen alle Mitglieder
///    Urlaub haben.
/// 3. **12 Monatskacheln** – kompakte Mini-Monate (eigener Painter) mit
///    Feiertagen, Geburtstagen und Urlaubs-Minibändern; Tipp → `onMonat`.
///
/// Flüssig: Band, Heatmap und Mini-Monate sind CustomPainter hinter
/// `RepaintBoundary`; die Auswahl liegt als eigener Painter darüber, damit
/// beim Ziehen nur die Auswahl neu gezeichnet wird. Alle Daten des Jahres
/// werden einmal vorberechnet (`_JahresDaten`), keine 365 Widgets.
/// Unter „Bewegung reduzieren“ wechselt das Jahr nur per Überblendung.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../design/calendar/td_calendar.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';
import '../bloc/kalender_cubit.dart';
import '../logic/feiertage.dart';
import '../logic/monatsvorschau.dart';
import '../logic/zeit.dart';
import '../models/termin.dart';
import '../widgets/kalender_hilfen.dart';
import '../widgets/zeitraum_text.dart';

class JahrView extends StatefulWidget {
  const JahrView({
    super.key,
    required this.zustand,
    required this.onMonat,
    required this.onZeitraum,
    this.heute,
  });

  final KalenderZustand zustand;

  /// Monat angetippt; `zelle` ist das Rechteck der Kachel (für den Zoom).
  final void Function(DateTime monat, Rect zelle) onMonat;

  /// Zeitraum im Jahresband gewählt (reine Tage, `bis` einschließlich).
  final void Function(DateTime von, DateTime bis) onZeitraum;
  final DateTime? heute;

  @override
  State<JahrView> createState() => _JahrViewState();
}

class _JahrViewState extends State<JahrView> {
  late int _jahr = widget.zustand.fokus.year;
  int _richtung = 1;
  _JahresDaten? _daten;
  KalenderZustand? _datenZustand;

  /// Laufende Auswahl im Band (Tagindex im Jahr).
  int? _auswahlStart;
  int? _auswahlEnde;
  bool _ziehen = false;

  DateTime get _heute =>
      widget.heute ?? nurTag(lokal(DateTime.now().toUtc(), widget.zustand.zeitzone));

  _JahresDaten _datenFuer(int jahr) {
    if (_daten == null || _daten!.jahr != jahr || !identical(_datenZustand, widget.zustand)) {
      _daten = _JahresDaten.berechnen(widget.zustand, jahr, _heute);
      _datenZustand = widget.zustand;
    }
    return _daten!;
  }

  void _jahrWechseln(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _richtung = delta.sign;
      _jahr += delta;
      _auswahlStart = null;
      _auswahlEnde = null;
    });
  }

  // --- Auswahl im Band -----------------------------------------------------

  void _tipp(int tag) {
    if (_auswahlStart == null) {
      HapticFeedback.selectionClick();
      setState(() {
        _auswahlStart = tag;
        _auswahlEnde = tag;
      });
    } else {
      _abschliessen(_auswahlStart!, tag);
    }
  }

  void _ziehenStart(int tag) {
    HapticFeedback.mediumImpact();
    setState(() {
      _ziehen = true;
      _auswahlStart = tag;
      _auswahlEnde = tag;
    });
  }

  void _ziehenUpdate(int tag) {
    if (_auswahlEnde == tag) return;
    HapticFeedback.selectionClick();
    setState(() => _auswahlEnde = tag);
  }

  void _ziehenEnde() {
    if (_auswahlStart == null) return;
    _abschliessen(_auswahlStart!, _auswahlEnde ?? _auswahlStart!);
  }

  void _abschliessen(int a, int b) {
    final d = _datenFuer(_jahr);
    final von = d.tag(a < b ? a : b);
    final bis = d.tag(a < b ? b : a);
    HapticFeedback.mediumImpact();
    setState(() {
      _ziehen = false;
      _auswahlStart = null;
      _auswahlEnde = null;
    });
    widget.onZeitraum(von, bis);
  }

  void _auswahlAufheben() => setState(() {
    _ziehen = false;
    _auswahlStart = null;
    _auswahlEnde = null;
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final daten = _datenFuer(_jahr);
    final reduced = TdMotion.reduced(context);

    return GestureDetector(
      // Wischen wechselt das Jahr; das Band gewinnt bei langem Drücken.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 300) return;
        _jahrWechseln(v < 0 ? 1 : -1);
      },
      child: LayoutBuilder(
        builder: (ctx, c) {
          final breit = c.maxWidth >= 800;
          final inhaltBreite = c.maxWidth.clamp(0.0, 1100.0);
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: TdSpace.lg + (c.maxWidth - inhaltBreite) / 2,
              vertical: TdSpace.sm,
            ).copyWith(bottom: 120),
            children: [
              _JahrKopf(
                jahr: _jahr,
                onZurueck: () => _jahrWechseln(-1),
                onVor: () => _jahrWechseln(1),
              ),
              const SizedBox(height: TdSpace.sm),
              AnimatedSwitcher(
                duration: TdMotion.of(context, TdMotion.base),
                switchInCurve: TdMotion.standard,
                switchOutCurve: TdMotion.exit,
                layoutBuilder: (aktuell, alte) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...alte, if (aktuell != null) aktuell],
                ),
                transitionBuilder: (child, anim) {
                  final fade = FadeTransition(opacity: anim, child: child);
                  if (reduced) return fade;
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0.04 * _richtung, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: fade,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_jahr),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TdCard(
                        padding: const EdgeInsets.fromLTRB(
                          TdSpace.md,
                          TdSpace.md,
                          TdSpace.md,
                          TdSpace.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Jahresband(
                              key: const Key('jahr-band'),
                              daten: daten,
                              locale: locale,
                              auswahlStart: _auswahlStart,
                              auswahlEnde: _auswahlEnde,
                              onTipp: _tipp,
                              onZiehenStart: _ziehenStart,
                              onZiehenUpdate: _ziehenUpdate,
                              onZiehenEnde: _ziehenEnde,
                            ),
                            const SizedBox(height: TdSpace.sm),
                            _AuswahlHinweis(
                              daten: daten,
                              start: _auswahlStart,
                              ende: _auswahlEnde,
                              ziehen: _ziehen,
                              locale: locale,
                              onAufheben: _auswahlAufheben,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: TdSpace.lg),
                      _AlleFrei(
                        daten: daten,
                        locale: locale,
                        onMonat: widget.onMonat,
                      ),
                      const SizedBox(height: TdSpace.lg),
                      Text(
                        s.jahrMonate.toUpperCase(),
                        style: context.text.labelSmall?.copyWith(
                          color: context.td.muted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: TdSpace.sm),
                      _MonatsKacheln(
                        daten: daten,
                        spalten: breit ? 4 : 3,
                        locale: locale,
                        onMonat: widget.onMonat,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daten
// ---------------------------------------------------------------------------

/// Ein Band im Jahresband: Tagindizes (einschließlich) und Farbe.
class _Band {
  const _Band(this.von, this.bis, this.farbe, this.urlaub);

  final int von;
  final int bis;
  final Color farbe;
  final bool urlaub;
}

/// Alles, was Band, Heatmap und Mini-Monate zum Zeichnen brauchen, einmal
/// je Jahr berechnet.
class _JahresDaten {
  _JahresDaten({
    required this.jahr,
    required this.erster,
    required this.tage,
    required this.mitglieder,
    required this.baender,
    required this.feiertage,
    required this.geburtstage,
    required this.urlaubFarben,
    required this.wochen,
    required this.alleFrei,
    required this.heuteIdx,
  });

  final int jahr;
  final DateTime erster;
  final int tage;
  final List<Mitglied> mitglieder;

  /// Je Mitglied (gleiche Reihenfolge) die Bänder.
  final List<List<_Band>> baender;

  /// Tagindex → Feiertag.
  final Map<int, Feiertag> feiertage;
  final Set<int> geburtstage;

  /// Tagindex → Personenfarben mit Urlaub (höchstens 3).
  final Map<int, List<Color>> urlaubFarben;

  /// Je Woche: (Tagindex Montag, Auslastung 0..1).
  final List<(int, double)> wochen;
  final List<Zeitraum> alleFrei;

  /// Tagindex von heute oder -1.
  final int heuteIdx;

  DateTime tag(int idx) => erster.add(Duration(days: idx));

  int idx(DateTime tag) => tageZwischen(erster, tag);

  static _JahresDaten berechnen(KalenderZustand z, int jahr, DateTime heute) {
    final zone = z.zeitzone;
    final erster = DateTime.utc(jahr, 1, 1);
    final letzter = DateTime.utc(jahr, 12, 31);
    final tage = tageZwischen(erster, letzter) + 1;
    final mitglieder = z.sichtbareMitglieder;
    final index = {for (var i = 0; i < mitglieder.length; i++) mitglieder[i].id: i};
    final baender = List.generate(mitglieder.length, (_) => <_Band>[]);
    final geburtstage = <int>{};
    final urlaubFarben = <int, List<Color>>{};

    final von = utcVon(zone, jahr, 1, 1);
    final bis = utcVon(zone, jahr + 1, 1, 1);
    for (final v in z.vorkommen(von, bis)) {
      final t = tageVon(v, zone);
      final a = tageZwischen(erster, t.von).clamp(0, tage - 1);
      final b = tageZwischen(erster, t.bis).clamp(0, tage - 1);
      if (v.art == TerminArt.geburtstag) {
        geburtstage.add(a);
        continue;
      }
      final urlaub = v.art == TerminArt.urlaub;
      final mehrtaegig = b > a;
      if (!urlaub && (!mehrtaegig || v.art == TerminArt.arbeit)) continue;
      for (final id in betroffenePersonen(z, v)) {
        final i = index[id];
        if (i == null) continue;
        final farbe = tdPersonFarbe(id, mitglieder[i].name);
        baender[i].add(_Band(a, b, farbe, urlaub));
        if (urlaub) {
          for (var d = a; d <= b; d++) {
            final l = urlaubFarben.putIfAbsent(d, () => []);
            if (l.length < 3 && !l.contains(farbe)) l.add(farbe);
          }
        }
      }
    }
    for (final l in baender) {
      l.sort((x, y) => x.von.compareTo(y.von));
    }

    final feiertage = <int, Feiertag>{};
    for (final f in feiertageIm(jahr, z.feiertagsRegion ?? '')) {
      feiertage[tageZwischen(erster, f.tag)] = f;
    }

    final dichte = wochenDichte(z, erster, letzter);
    final wochen = <(int, double)>[
      for (final e in dichte.entries) (tageZwischen(erster, e.key), e.value),
    ]..sort((x, y) => x.$1.compareTo(y.$1));

    final h = tageZwischen(erster, heute);
    return _JahresDaten(
      jahr: jahr,
      erster: erster,
      tage: tage,
      mitglieder: mitglieder,
      baender: baender,
      feiertage: feiertage,
      geburtstage: geburtstage,
      urlaubFarben: urlaubFarben,
      wochen: wochen,
      alleFrei: gemeinsamerUrlaub(z, jahr),
      heuteIdx: h >= 0 && h < tage ? h : -1,
    );
  }
}

// ---------------------------------------------------------------------------
// Kopf
// ---------------------------------------------------------------------------

class _JahrKopf extends StatelessWidget {
  const _JahrKopf({required this.jahr, required this.onZurueck, required this.onVor});

  final int jahr;
  final VoidCallback onZurueck;
  final VoidCallback onVor;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Row(
      children: [
        IconButton(
          tooltip: s.jahrZurueck,
          onPressed: onZurueck,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '$jahr',
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          tooltip: s.jahrVor,
          onPressed: onVor,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Jahresband
// ---------------------------------------------------------------------------

/// Maße des Bands; Painter und Treffer-Logik teilen sie sich.
class _BandMasse {
  const _BandMasse({
    required this.monatsZeile,
    required this.zeile,
    required this.luecke,
    required this.feiertagsZeile,
    required this.heatZeile,
    required this.mitglieder,
    required this.mitFeiertagen,
  });

  final double monatsZeile;
  final double zeile;
  final double luecke;
  final double feiertagsZeile;
  final double heatZeile;
  final int mitglieder;
  final bool mitFeiertagen;

  double zeileOben(int i) => monatsZeile + i * (zeile + luecke);
  double get feiertagsOben => zeileOben(mitglieder);
  double get heatOben => feiertagsOben + (mitFeiertagen ? feiertagsZeile + luecke : 0);
  double get hoehe => heatOben + heatZeile + 2;
}

class _Jahresband extends StatelessWidget {
  const _Jahresband({
    super.key,
    required this.daten,
    required this.locale,
    required this.auswahlStart,
    required this.auswahlEnde,
    required this.onTipp,
    required this.onZiehenStart,
    required this.onZiehenUpdate,
    required this.onZiehenEnde,
  });

  final _JahresDaten daten;
  final String locale;
  final int? auswahlStart;
  final int? auswahlEnde;
  final ValueChanged<int> onTipp;
  final ValueChanged<int> onZiehenStart;
  final ValueChanged<int> onZiehenUpdate;
  final VoidCallback onZiehenEnde;

  static const double _avatarSpalte = 24;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final td = context.td;
    final m = _BandMasse(
      monatsZeile: 16,
      zeile: daten.mitglieder.length > 4 ? 10 : 13,
      luecke: 3,
      feiertagsZeile: 6,
      heatZeile: 10,
      mitglieder: daten.mitglieder.length,
      mitFeiertagen: daten.feiertage.isNotEmpty,
    );
    final personen = personenVon(daten.mitglieder);
    final heute = daten.heuteIdx;

    return Semantics(
      label: '${s.jahrBandTitel}. ${s.jahrBandHinweis}',
      child: SizedBox(
        height: m.hoehe,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linke Spalte: wer ist welche Zeile.
            SizedBox(
              width: _avatarSpalte,
              child: Column(
                children: [
                  SizedBox(height: m.monatsZeile),
                  for (final p in personen)
                    SizedBox(
                      height: m.zeile + m.luecke,
                      child: Center(
                        child: TdAvatar(data: p.avatar, size: (m.zeile + 1).clamp(10, 14)),
                      ),
                    ),
                  if (m.mitFeiertagen)
                    SizedBox(
                      height: m.feiertagsZeile + m.luecke,
                      child: Icon(Icons.celebration_rounded, size: 9, color: td.muted),
                    ),
                  SizedBox(
                    height: m.heatZeile,
                    child: Icon(Icons.bar_chart_rounded, size: 11, color: td.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TdSpace.xs),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, c) {
                  final breite = c.maxWidth;
                  int tagBei(Offset lokal) =>
                      (lokal.dx / breite * daten.tage).floor().clamp(0, daten.tage - 1);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => onTipp(tagBei(d.localPosition)),
                    onLongPressStart: (d) => onZiehenStart(tagBei(d.localPosition)),
                    onLongPressMoveUpdate: (d) => onZiehenUpdate(tagBei(d.localPosition)),
                    onLongPressEnd: (_) => onZiehenEnde(),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(
                            child: CustomPaint(
                              painter: _JahresbandPainter(
                                daten: daten,
                                masse: m,
                                locale: locale,
                                spur: ctx.colors.onSurface.withValues(alpha: td.isDark ? 0.08 : 0.05),
                                raster: ctx.colors.outlineVariant.withValues(alpha: 0.6),
                                text: td.muted,
                                heat: td.palette.primary,
                                heute: td.palette.primary,
                                feiertag: td.palette.secondary,
                                dunkel: td.isDark,
                                heuteIdx: heute,
                              ),
                            ),
                          ),
                          if (auswahlStart != null)
                            CustomPaint(
                              painter: _AuswahlPainter(
                                tage: daten.tage,
                                von: auswahlStart!,
                                bis: auswahlEnde ?? auswahlStart!,
                                oben: m.monatsZeile - 2,
                                farbe: td.palette.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JahresbandPainter extends CustomPainter {
  _JahresbandPainter({
    required this.daten,
    required this.masse,
    required this.locale,
    required this.spur,
    required this.raster,
    required this.text,
    required this.heat,
    required this.heute,
    required this.feiertag,
    required this.dunkel,
    required this.heuteIdx,
  });

  final _JahresDaten daten;
  final _BandMasse masse;
  final String locale;
  final Color spur;
  final Color raster;
  final Color text;
  final Color heat;
  final Color heute;
  final Color feiertag;
  final bool dunkel;
  final int heuteIdx;

  @override
  void paint(Canvas canvas, Size size) {
    final m = masse;
    final tagB = size.width / daten.tage;
    double x(int idx) => idx * tagB;
    final paint = Paint()..isAntiAlias = true;

    // Monatsraster und -namen.
    final monatsFormat = DateFormat.MMM(locale);
    final monatsStil = TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: text);
    for (var monat = 1; monat <= 12; monat++) {
      final idx = daten.idx(DateTime.utc(daten.jahr, monat, 1));
      final x0 = x(idx);
      paint
        ..color = raster
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x0, m.monatsZeile - 3), Offset(x0, size.height), paint);
      var name = monatsFormat.format(DateTime(daten.jahr, monat)).replaceAll('.', '');
      final monatsBreite = tagB * 30;
      if (monatsBreite < 26) name = name.substring(0, 1);
      final tp = TextPainter(
        text: TextSpan(text: name, style: monatsStil),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x0 + 2, 0));
    }

    // Spuren je Mitglied mit Bändern.
    for (var i = 0; i < daten.mitglieder.length; i++) {
      final oben = m.zeileOben(i);
      final spurRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, oben, size.width, m.zeile),
        const Radius.circular(3),
      );
      paint.color = spur;
      canvas.drawRRect(spurRect, paint);
      for (final b in daten.baender[i]) {
        final r = Rect.fromLTRB(x(b.von), oben, x(b.bis + 1).clamp(x(b.von) + 1.5, size.width), oben + m.zeile);
        paint.color = b.urlaub
            ? b.farbe.withValues(alpha: dunkel ? 0.95 : 0.9)
            : b.farbe.withValues(alpha: dunkel ? 0.5 : 0.4);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), paint);
      }
    }

    // Feiertage als kleine Punkte.
    if (m.mitFeiertagen) {
      final cy = m.feiertagsOben + m.feiertagsZeile / 2;
      paint.color = feiertag;
      for (final idx in daten.feiertage.keys) {
        canvas.drawCircle(Offset(x(idx) + tagB / 2, cy), 2.2, paint);
      }
    }

    // Heatmap je Woche.
    final heatOben = m.heatOben;
    for (final (mo, wert) in daten.wochen) {
      final a = mo < 0 ? 0 : mo;
      final b = (mo + 7).clamp(0, daten.tage);
      if (b <= a) continue;
      paint.color = heat.withValues(alpha: 0.06 + 0.84 * wert);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x(a) + 0.5, heatOben, x(b) - 0.5, heatOben + m.heatZeile),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    // Heute.
    if (heuteIdx >= 0) {
      final hx = x(heuteIdx) + tagB / 2;
      paint
        ..color = heute
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(hx, m.monatsZeile - 4), Offset(hx, size.height), paint);
      canvas.drawCircle(Offset(hx, m.monatsZeile - 4), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(_JahresbandPainter old) =>
      !identical(old.daten, daten) ||
      old.locale != locale ||
      old.heat != heat ||
      old.spur != spur ||
      old.dunkel != dunkel ||
      old.heuteIdx != heuteIdx;
}

/// Markierung des gewählten Zeitraums; eigener Painter, damit beim Ziehen
/// nur diese Schicht neu gezeichnet wird.
class _AuswahlPainter extends CustomPainter {
  _AuswahlPainter({
    required this.tage,
    required this.von,
    required this.bis,
    required this.oben,
    required this.farbe,
  });

  final int tage;
  final int von;
  final int bis;
  final double oben;
  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    final tagB = size.width / tage;
    final a = von < bis ? von : bis;
    final b = von < bis ? bis : von;
    final r = Rect.fromLTRB(a * tagB, oben, ((b + 1) * tagB).clamp(a * tagB + 2, size.width), size.height);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(rr, Paint()..color = farbe.withValues(alpha: 0.22));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = farbe
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Griffe links und rechts.
    final griff = Paint()..color = farbe;
    for (final gx in [r.left, r.right]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(gx, r.center.dy), width: 4, height: 16),
          const Radius.circular(2),
        ),
        griff,
      );
    }
  }

  @override
  bool shouldRepaint(_AuswahlPainter old) =>
      old.von != von || old.bis != bis || old.farbe != farbe || old.tage != tage;
}

class _AuswahlHinweis extends StatelessWidget {
  const _AuswahlHinweis({
    required this.daten,
    required this.start,
    required this.ende,
    required this.ziehen,
    required this.locale,
    required this.onAufheben,
  });

  final _JahresDaten daten;
  final int? start;
  final int? ende;
  final bool ziehen;
  final String locale;
  final VoidCallback onAufheben;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final td = context.td;
    final String text;
    var aktiv = false;
    if (start == null) {
      text = s.jahrBandHinweis;
    } else if (ziehen) {
      final a = start!, b = ende ?? start!;
      text = s.jahrUrlaubAuswahl(
        zeitraumKurz(daten.tag(a < b ? a : b), daten.tag(a < b ? b : a), locale),
      );
      aktiv = true;
    } else {
      text = s.jahrAuswahlStart(datumKurz(daten.tag(start!), locale));
      aktiv = true;
    }
    return AnimatedSwitcher(
      duration: TdMotion.of(context, TdMotion.fast),
      child: Row(
        key: ValueKey('$aktiv-$ziehen'),
        children: [
          Icon(
            aktiv ? Icons.beach_access_rounded : Icons.touch_app_rounded,
            size: 14,
            color: aktiv ? td.palette.primary : td.muted,
          ),
          const SizedBox(width: TdSpace.xs + 2),
          Expanded(
            child: Text(
              text,
              style: context.text.labelSmall?.copyWith(
                color: aktiv ? context.colors.onSurface : td.muted,
                fontWeight: aktiv ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (aktiv && !ziehen)
            IconButton(
              tooltip: s.jahrAuswahlAbbrechen,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: onAufheben,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alle frei
// ---------------------------------------------------------------------------

class _AlleFrei extends StatelessWidget {
  const _AlleFrei({required this.daten, required this.locale, required this.onMonat});

  final _JahresDaten daten;
  final String locale;
  final void Function(DateTime monat, Rect zelle) onMonat;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final td = context.td;
    final urlaub = TdTerminStil.of(context, TerminArt.urlaub).farbe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded, size: 16, color: urlaub),
            const SizedBox(width: TdSpace.xs + 2),
            Text(
              s.jahrAlleFrei.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: td.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: TdSpace.sm),
        if (daten.alleFrei.isEmpty)
          Text(s.jahrAlleFreiKeine, style: context.text.bodySmall?.copyWith(color: td.muted))
        else
          Wrap(
            spacing: TdSpace.sm,
            runSpacing: TdSpace.sm,
            children: [
              for (var i = 0; i < daten.alleFrei.length; i++)
                TdFadeSlideIn(
                  index: i,
                  child: Builder(
                    builder: (ctx) => TdChip(
                      label: s.jahrAlleFreiChip(
                        zeitraumKurz(daten.alleFrei[i].von, daten.alleFrei[i].bis, locale),
                      ),
                      icon: Icons.beach_access_rounded,
                      color: urlaub,
                      selected: true,
                      dense: true,
                      onTap: () {
                        final box = ctx.findRenderObject() as RenderBox?;
                        final rect = box == null
                            ? Rect.zero
                            : box.localToGlobal(Offset.zero) & box.size;
                        final v = daten.alleFrei[i].von;
                        onMonat(DateTime.utc(v.year, v.month, 1), rect);
                      },
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Monatskacheln
// ---------------------------------------------------------------------------

class _MonatsKacheln extends StatelessWidget {
  const _MonatsKacheln({
    required this.daten,
    required this.spalten,
    required this.locale,
    required this.onMonat,
  });

  final _JahresDaten daten;
  final int spalten;
  final String locale;
  final void Function(DateTime monat, Rect zelle) onMonat;

  @override
  Widget build(BuildContext context) {
    final reihen = (12 / spalten).ceil();
    return Column(
      children: [
        for (var r = 0; r < reihen; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r < reihen - 1 ? TdSpace.sm : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < spalten; c++) ...[
                  if (c > 0) const SizedBox(width: TdSpace.sm),
                  Expanded(
                    child: r * spalten + c < 12
                        ? TdFadeSlideIn(
                            index: r * spalten + c,
                            child: _MonatKachel(
                              daten: daten,
                              monat: r * spalten + c + 1,
                              locale: locale,
                              onMonat: onMonat,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MonatKachel extends StatelessWidget {
  const _MonatKachel({
    required this.daten,
    required this.monat,
    required this.locale,
    required this.onMonat,
  });

  final _JahresDaten daten;
  final int monat;
  final String locale;
  final void Function(DateTime monat, Rect zelle) onMonat;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final td = context.td;
    final name = DateFormat.MMMM(locale).format(DateTime(daten.jahr, monat));
    final ersterIdx = daten.idx(DateTime.utc(daten.jahr, monat, 1));
    final istAktuell = daten.heuteIdx >= 0 && daten.tag(daten.heuteIdx).month == monat;
    return Semantics(
      button: true,
      label: s.jahrMonatOeffnen(name),
      child: Builder(
        builder: (ctx) => TdCard(
          key: Key('jahr-monat-$monat'),
          padding: const EdgeInsets.fromLTRB(TdSpace.sm, TdSpace.sm, TdSpace.sm, TdSpace.xs),
          borderRadius: BorderRadius.circular(TdRadius.md),
          variant: istAktuell ? TdCardVariant.elevated : TdCardVariant.surface,
          onTap: () {
            HapticFeedback.selectionClick();
            final box = ctx.findRenderObject() as RenderBox?;
            final rect = box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
            onMonat(DateTime.utc(daten.jahr, monat, 1), rect);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: istAktuell ? td.palette.primary : context.colors.onSurface,
                ),
              ),
              const SizedBox(height: TdSpace.xs),
              AspectRatio(
                aspectRatio: 7 / 6.4,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _MiniMonatPainter(
                      daten: daten,
                      monat: monat,
                      ersterIdx: ersterIdx,
                      text: context.colors.onSurface,
                      gedaempft: td.muted.withValues(alpha: 0.7),
                      heute: td.palette.primary,
                      feiertag: td.palette.secondary,
                      geburtstag: TdTerminStil.of(context, TerminArt.geburtstag).farbe,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini-Monat: Tageszahlen in 7 Spalten, Feiertag farbig, Geburtstag als
/// Punkt, Urlaub als Mini-Bänder (Personenfarben) am Zellenboden.
class _MiniMonatPainter extends CustomPainter {
  _MiniMonatPainter({
    required this.daten,
    required this.monat,
    required this.ersterIdx,
    required this.text,
    required this.gedaempft,
    required this.heute,
    required this.feiertag,
    required this.geburtstag,
  });

  final _JahresDaten daten;
  final int monat;
  final int ersterIdx;
  final Color text;
  final Color gedaempft;
  final Color heute;
  final Color feiertag;
  final Color geburtstag;

  @override
  void paint(Canvas canvas, Size size) {
    final erster = DateTime.utc(daten.jahr, monat, 1);
    final tageImMonat = DateTime.utc(daten.jahr, monat + 1, 0).day;
    final versatz = erster.weekday - 1; // Montag = 0
    final zellB = size.width / 7;
    final zellH = size.height / 6;
    final schrift = (zellB * 0.55).clamp(7.0, 11.0);
    final paint = Paint()..isAntiAlias = true;

    for (var d = 1; d <= tageImMonat; d++) {
      final pos = versatz + d - 1;
      final spalte = pos % 7;
      final reihe = pos ~/ 7;
      final idx = ersterIdx + d - 1;
      final cx = spalte * zellB + zellB / 2;
      final cy = reihe * zellH + zellH / 2 - 1;
      final istHeute = idx == daten.heuteIdx;
      final istFeiertag = daten.feiertage.containsKey(idx);
      final wochenende = spalte >= 5;

      if (istHeute) {
        paint
          ..color = heute
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), (zellB * 0.42).clamp(6, 10), paint);
      }
      final farbe = istHeute
          ? Colors.white
          : istFeiertag
              ? feiertag
              : wochenende
                  ? gedaempft
                  : text;
      final tp = TextPainter(
        text: TextSpan(
          text: '$d',
          style: TextStyle(
            fontSize: schrift,
            fontWeight: istHeute || istFeiertag ? FontWeight.w800 : FontWeight.w600,
            color: farbe,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

      // Geburtstag: Punkt rechts oben.
      if (daten.geburtstage.contains(idx)) {
        paint.color = geburtstag;
        canvas.drawCircle(Offset(cx + zellB * 0.32, cy - zellH * 0.32), 1.8, paint);
      }
      // Urlaub: Mini-Bänder am Zellenboden.
      final farben = daten.urlaubFarben[idx];
      if (farben != null && farben.isNotEmpty) {
        final breite = (zellB - 3) / farben.length;
        final y = reihe * zellH + zellH - 2.5;
        for (var i = 0; i < farben.length; i++) {
          paint.color = farben[i];
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(spalte * zellB + 1.5 + i * breite, y, breite - 0.8, 2),
              const Radius.circular(1),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MiniMonatPainter old) =>
      !identical(old.daten, daten) ||
      old.monat != monat ||
      old.text != text ||
      old.heute != heute ||
      old.feiertag != feiertag;
}
