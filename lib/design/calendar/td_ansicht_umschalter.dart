/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

class TdUmschalterEintrag {
  const TdUmschalterEintrag({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Segment-Umschalter in Pillenform mit gleitender Markierung
/// (Spuren / Agenda / Monat). Auf schmalen Flächen nur Symbole.
class TdAnsichtUmschalter extends StatelessWidget {
  const TdAnsichtUmschalter({
    super.key,
    required this.eintraege,
    required this.index,
    required this.onChanged,
    this.nurSymbole = false,
  });

  final List<TdUmschalterEintrag> eintraege;
  final int index;
  final ValueChanged<int> onChanged;
  final bool nurSymbole;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final td = context.td;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: td.isDark ? 0.6 : 1),
        borderRadius: BorderRadius.circular(TdRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final breite = c.maxWidth / eintraege.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: TdMotion.of(context, TdMotion.base),
                curve: TdMotion.emphasized,
                left: breite * index,
                top: 0,
                bottom: 0,
                width: breite,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: td.primaryGradient,
                    borderRadius: BorderRadius.circular(TdRadius.pill),
                    boxShadow: TdShadows.glow(td.palette.primary),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < eintraege.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        label: eintraege[i].label,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == index) return;
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: TdMotion.of(context, TdMotion.fast),
                              style: ctx.text.labelMedium!.copyWith(
                                color: i == index
                                    ? td.palette.onPrimary
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    eintraege[i].icon,
                                    size: 16,
                                    color: i == index
                                        ? td.palette.onPrimary
                                        : scheme.onSurfaceVariant,
                                  ),
                                  if (!nurSymbole) ...[
                                    const SizedBox(width: 6),
                                    Text(eintraege[i].label, maxLines: 1),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
