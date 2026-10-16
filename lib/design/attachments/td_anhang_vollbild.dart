/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../../models/anhang_model.dart';
import '../../services/attachment_service.dart';
import '../components/td_button.dart';
import '../components/td_toast.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'anhang_texte.dart';
import 'td_anhang_bild.dart';
import 'td_anhang_galerie.dart';

/// Vollbildansicht der Anhänge eines Eintrags: schwarzer Hintergrund,
/// Wischen zwischen Anhängen, Zoom bis 5× bei Bildern, Dokumente als
/// Kachel mit „Öffnen“. Leiste mit Name, Zähler, Teilen, Öffnen und
/// (wenn erlaubt) Löschen mit Rückfrage.
class TdAnhangVollbild extends StatefulWidget {
  const TdAnhangVollbild({
    super.key,
    required this.anhaenge,
    required this.service,
    this.start = 0,
    this.darfLoeschen,
    this.onLoeschen,
    this.heroPraefix = 'galerie',
  });

  final List<Anhang> anhaenge;
  final AttachmentService service;
  final int start;
  final bool Function(Anhang a)? darfLoeschen;

  /// Nach erfolgreichem Löschen in Storage (der Aufrufer entfernt den
  /// Eintrag aus dem Dokument).
  final ValueChanged<Anhang>? onLoeschen;
  final String heroPraefix;

  /// Öffnet das Vollbild als eigene Seite. Mit „Bewegung reduzieren“ nur
  /// Überblenden, sonst Hero-Flug von der Kachel plus Überblenden.
  static Future<void> oeffnen(
    BuildContext context, {
    required List<Anhang> anhaenge,
    required AttachmentService service,
    int start = 0,
    bool Function(Anhang a)? darfLoeschen,
    ValueChanged<Anhang>? onLoeschen,
    String heroPraefix = 'galerie',
  }) {
    final dauer = TdMotion.of(context, TdMotion.page);
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        fullscreenDialog: true,
        transitionDuration: dauer,
        reverseTransitionDuration: dauer,
        pageBuilder: (_, _, _) => TdAnhangVollbild(
          anhaenge: anhaenge,
          service: service,
          start: start,
          darfLoeschen: darfLoeschen,
          onLoeschen: onLoeschen,
          heroPraefix: heroPraefix,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  State<TdAnhangVollbild> createState() => _TdAnhangVollbildState();
}

class _TdAnhangVollbildState extends State<TdAnhangVollbild> {
  late final List<Anhang> _anhaenge = List.of(widget.anhaenge);
  late int _index = widget.start.clamp(0, _anhaenge.length - 1);
  late final PageController _seiten = PageController(initialPage: _index);
  bool _leisteSichtbar = true;
  bool _gezoomt = false;
  bool _beschaeftigt = false;

  @override
  void dispose() {
    _seiten.dispose();
    super.dispose();
  }

  Anhang get _aktuell => _anhaenge[_index];

  bool get _darfLoeschen => widget.darfLoeschen?.call(_aktuell) ?? false;

  Future<void> _loeschen() async {
    if (_beschaeftigt) return;
    final a = _aktuell;
    setState(() => _beschaeftigt = true);
    final ok = await tdAnhangLoeschenMitRueckfrage(
      context,
      anhang: a,
      service: widget.service,
      onGeloescht: widget.onLoeschen,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _beschaeftigt = false);
      return;
    }
    TdToast.show(
      context,
      anhangL10n(context).anhangGeloescht,
      variant: TdToastVariant.success,
    );
    setState(() {
      _anhaenge.remove(a);
      _beschaeftigt = false;
      if (_anhaenge.isEmpty) return;
      _index = _index.clamp(0, _anhaenge.length - 1);
    });
    if (_anhaenge.isEmpty) {
      Navigator.of(context).maybePop();
    } else {
      _seiten.jumpToPage(_index);
    }
  }

  Future<void> _aktion(Future<void> Function(Anhang a) f) async {
    if (_beschaeftigt) return;
    setState(() => _beschaeftigt = true);
    try {
      await f(_aktuell);
    } catch (e) {
      if (mounted) {
        TdToast.show(
          context,
          anhangL10n(context).anhangFehler(e),
          variant: TdToastVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _beschaeftigt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = anhangL10n(context);
    final reduced = TdMotion.reduced(context);
    final dauer = TdMotion.of(context, TdMotion.base);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_anhaenge.isNotEmpty)
            PageView.builder(
              controller: _seiten,
              physics: _gezoomt
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: _anhaenge.length,
              itemBuilder: (context, i) {
                final a = _anhaenge[i];
                // Hero nur für die sichtbare Seite; bei Dokumenten fliegt
                // nur das Symbol, damit die Kachel beim Flug nicht überläuft.
                final heroTag = (!reduced && i == _index)
                    ? tdAnhangHeroTag(widget.heroPraefix, a)
                    : null;
                if (a.istBild) {
                  Widget seite = _BildSeite(
                    anhang: a,
                    service: widget.service,
                    onZoom: (z) {
                      if (z != _gezoomt) setState(() => _gezoomt = z);
                    },
                    onTap: () =>
                        setState(() => _leisteSichtbar = !_leisteSichtbar),
                  );
                  if (heroTag != null) seite = Hero(tag: heroTag, child: seite);
                  return seite;
                }
                return _DokumentSeite(
                  anhang: a,
                  heroTag: heroTag,
                  onOeffnen: () => _aktion(widget.service.oeffnen),
                );
              },
            ),
          // Obere Leiste
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: AnimatedSlide(
              offset: _leisteSichtbar ? Offset.zero : const Offset(0, -1),
              duration: dauer,
              curve: TdMotion.standard,
              child: AnimatedOpacity(
                opacity: _leisteSichtbar ? 1 : 0,
                duration: dauer,
                child: _Leiste(
                  oben: true,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: l.anhangSchliessen,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _anhaenge.isEmpty ? '' : _aktuell.name,
                                style: context.text.titleSmall?.copyWith(
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_anhaenge.length > 1)
                                Text(
                                  l.anhangVonAnzahl(
                                    _index + 1,
                                    _anhaenge.length,
                                  ),
                                  style: context.text.labelSmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: TdSpace.sm),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Untere Leiste
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: _leisteSichtbar ? Offset.zero : const Offset(0, 1),
              duration: dauer,
              curve: TdMotion.standard,
              child: AnimatedOpacity(
                opacity: _leisteSichtbar ? 1 : 0,
                duration: dauer,
                child: _Leiste(
                  oben: false,
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Aktion(
                          icon: Icons.ios_share_rounded,
                          label: l.anhangTeilen,
                          onTap: _beschaeftigt || _anhaenge.isEmpty
                              ? null
                              : () => _aktion(widget.service.teilen),
                        ),
                        _Aktion(
                          icon: Icons.open_in_new_rounded,
                          label: l.anhangOeffnen,
                          onTap: _beschaeftigt || _anhaenge.isEmpty
                              ? null
                              : () => _aktion(widget.service.oeffnen),
                        ),
                        if (_anhaenge.isNotEmpty && _darfLoeschen)
                          _Aktion(
                            icon: Icons.delete_outline_rounded,
                            label: l.anhangLoeschen,
                            farbe: context.td.danger,
                            onTap: _beschaeftigt ? null : _loeschen,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Leiste extends StatelessWidget {
  const _Leiste({required this.child, required this.oben});

  final Widget child;
  final bool oben;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TdSpace.sm,
          vertical: TdSpace.sm,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: oben ? Alignment.topCenter : Alignment.bottomCenter,
            end: oben ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.72),
              Colors.black.withValues(alpha: 0),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _Aktion extends StatelessWidget {
  const _Aktion({
    required this.icon,
    required this.label,
    required this.onTap,
    this.farbe,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? farbe;

  @override
  Widget build(BuildContext context) {
    final c = farbe ?? Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: TdRadius.control,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TdSpace.lg,
              vertical: TdSpace.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: c),
                const SizedBox(height: TdSpace.xxs),
                Text(label, style: context.text.labelSmall?.copyWith(color: c)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BildSeite extends StatefulWidget {
  const _BildSeite({
    required this.anhang,
    required this.service,
    required this.onZoom,
    required this.onTap,
  });

  final Anhang anhang;
  final AttachmentService service;
  final ValueChanged<bool> onZoom;
  final VoidCallback onTap;

  @override
  State<_BildSeite> createState() => _BildSeiteState();
}

class _BildSeiteState extends State<_BildSeite> {
  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _doppeltipp() {
    final gezoomt = _transform.value.getMaxScaleOnAxis() > 1.01;
    _transform.value = gezoomt
        ? Matrix4.identity()
        : (Matrix4.identity()..scaleByDouble(2.5, 2.5, 1, 1));
    widget.onZoom(!gezoomt);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _doppeltipp,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        clipBehavior: Clip.none,
        onInteractionEnd: (_) =>
            widget.onZoom(_transform.value.getMaxScaleOnAxis() > 1.01),
        child: Center(
          child: TdAnhangBild(
            service: widget.service,
            pfad: widget.anhang.pfad,
            fit: BoxFit.contain,
            mitWiederholen: true,
            dunkel: true,
          ),
        ),
      ),
    );
  }
}

class _DokumentSeite extends StatelessWidget {
  const _DokumentSeite({
    required this.anhang,
    required this.onOeffnen,
    this.heroTag,
  });

  final Anhang anhang;
  final VoidCallback onOeffnen;
  final String? heroTag;

  Widget _mitHero(Widget kind) =>
      heroTag == null ? kind : Hero(tag: heroTag!, child: kind);

  @override
  Widget build(BuildContext context) {
    final l = anhangL10n(context);
    final td = context.td;
    final scheme = context.colors;
    final akzent = anhang.istPdf ? td.danger : scheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TdSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(TdSpace.xl),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: TdRadius.card,
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mitHero(
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: akzent.withValues(alpha: 0.2),
                      borderRadius: TdRadius.card,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      anhangSymbol(anhang.typ),
                      size: 44,
                      color: akzent,
                    ),
                  ),
                ),
                const SizedBox(height: TdSpace.lg),
                Text(
                  anhang.name,
                  style: context.text.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: TdSpace.xs),
                Text(
                  '${l.anhangTyp(anhang)} · ${l.anhangGroesse(anhang.groesse)}',
                  style: context.text.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: TdSpace.sm),
                Text(
                  l.anhangVorschauNichtMoeglich,
                  style: context.text.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: TdSpace.xl),
                TdButton.primary(
                  label: l.anhangOeffnen,
                  icon: Icons.open_in_new_rounded,
                  onPressed: onOeffnen,
                  expanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
