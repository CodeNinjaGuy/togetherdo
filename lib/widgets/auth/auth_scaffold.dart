/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../common/legal_links_row.dart';

/// Markenzeichen: Haken-Ring im Verlauf, der sich beim Erscheinen abhakt,
/// daneben der Name. Hell auf dunklem Verlauf.
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.size = 72, this.light = true, this.showName = true});

  final double size;
  final bool light;
  final bool showName;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _checked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.light ? Colors.white : context.colors.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: widget.light ? 0.16 : 0.0),
            borderRadius: BorderRadius.circular(widget.size * 0.3),
            border: Border.all(
              color: fg.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: TdCheck(
            value: _checked,
            size: widget.size * 0.56,
            enabled: false,
            accent: context.colors.secondary,
          ),
        ),
        if (widget.showName) ...[
          const SizedBox(height: TdSpace.lg),
          Text(
            'ToGetherDo',
            style: context.text.displaySmall?.copyWith(color: fg),
          ),
        ],
      ],
    );
  }
}

/// Rahmen der Anmelde-Bildschirme: Handy – Verlauf oben mit Marke, Karte
/// darunter; breit – linke Markentafel mit drei Versprechen, rechts die
/// Karte in der Mitte.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final td = context.td;
    final wide = context.tdLayout != TdLayoutSize.compact;

    final card = TdFadeSlideIn(
      index: 2,
      child: TdCard(
        variant: TdCardVariant.elevated,
        padding: const EdgeInsets.all(TdSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: context.text.headlineMedium),
            const SizedBox(height: TdSpace.xs),
            Text(
              subtitle,
              style: context.text.bodyMedium?.copyWith(color: td.muted),
            ),
            const SizedBox(height: TdSpace.xl),
            child,
          ],
        ),
      ),
    );

    final legal = Column(
      children: [
        if (footer != null) footer!,
        const SizedBox(height: TdSpace.sm),
        const LegalLinksRow(),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(gradient: td.heroGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(TdSpace.xxxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TdFadeSlideIn(index: 0, child: BrandMark(size: 84)),
                        const SizedBox(height: TdSpace.lg),
                        TdFadeSlideIn(
                          index: 1,
                          child: Text(
                            l10n.tagline,
                            style: context.text.titleLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: TdSpace.xxl),
                        for (final (i, f) in [
                          (Icons.checklist_rounded, l10n.promiseLists),
                          (Icons.balance_rounded, l10n.promiseFair),
                          (Icons.qr_code_scanner_rounded, l10n.promiseScan),
                        ].indexed)
                          TdFadeSlideIn(
                            index: 2 + i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: TdSpace.md),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: TdRadius.control,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(f.$1, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: TdSpace.md),
                                  Expanded(
                                    child: Text(
                                      f.$2,
                                      style: context.text.bodyLarge?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(TdSpace.xxl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        children: [card, const SizedBox(height: TdSpace.lg), legal],
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

    return Scaffold(
      body: Stack(
        children: [
          // Verlauf im oberen Drittel, darunter der normale Hintergrund.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: td.heroGradient),
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                TdSpace.page,
                TdSpace.xl,
                TdSpace.page,
                TdSpace.xl,
              ),
              child: Column(
                children: [
                  const TdFadeSlideIn(index: 0, child: BrandMark()),
                  const SizedBox(height: TdSpace.sm),
                  TdFadeSlideIn(
                    index: 1,
                    child: Text(
                      l10n.tagline,
                      style: context.text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: TdSpace.xl),
                  card,
                  const SizedBox(height: TdSpace.lg),
                  legal,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prüft eine E-Mail-Adresse grob.
bool looksLikeEmail(String value) =>
    RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(value.trim());
