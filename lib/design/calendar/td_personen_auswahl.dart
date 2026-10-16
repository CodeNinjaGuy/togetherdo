/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/td_avatar.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

/// Person für die Auswahl: Name, Bild, stabile Farbe.
class TdPerson {
  const TdPerson({required this.id, required this.name, this.imageUrl});

  final String id;
  final String name;
  final String? imageUrl;

  TdAvatarData get avatar => TdAvatarData(id: id, name: name, imageUrl: imageUrl);
}

/// Avatar mit Auswahlring und Häkchen; antippen schaltet um. Darunter der
/// Vorname. Wird für Personenfilter und Teilnehmer benutzt.
class TdPersonChip extends StatelessWidget {
  const TdPersonChip({
    super.key,
    required this.person,
    required this.selected,
    required this.onTap,
    this.size = 44,
    this.zeigeName = true,
    this.gedaempft = false,
  });

  final TdPerson person;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final bool zeigeName;

  /// Nicht gewählt, aber andere schon: ausgegraut.
  final bool gedaempft;

  @override
  Widget build(BuildContext context) {
    final farbe = person.avatar.resolveColor();
    final dauer = TdMotion.of(context, TdMotion.base);
    return Semantics(
      button: true,
      selected: selected,
      label: person.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedOpacity(
          duration: dauer,
          opacity: gedaempft ? 0.45 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size + 8,
                height: size + 8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: dauer,
                      curve: TdMotion.standard,
                      width: selected ? size + 8 : size + 2,
                      height: selected ? size + 8 : size + 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? farbe : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    TdAvatar(
                      data: person.avatar,
                      size: size,
                      borderColor: context.colors.surface,
                      borderWidth: 2,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: AnimatedScale(
                        duration: dauer,
                        curve: TdMotion.spring,
                        scale: selected ? 1 : 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: farbe,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.colors.surface, width: 2),
                          ),
                          child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (zeigeName) ...[
                const SizedBox(height: 2),
                SizedBox(
                  width: size + 20,
                  child: Text(
                    person.name.split(' ').first,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: selected ? context.colors.onSurface : context.td.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Reihe aus Personen-Chips, waagrecht scrollbar, optional mit „Alle“.
class TdPersonenAuswahl extends StatelessWidget {
  const TdPersonenAuswahl({
    super.key,
    required this.personen,
    required this.gewaehlt,
    required this.onToggle,
    this.alleLabel,
    this.onAlle,
    this.size = 44,
    this.zeigeNamen = true,
  });

  final List<TdPerson> personen;

  /// Leer = alle.
  final Set<String> gewaehlt;
  final ValueChanged<String> onToggle;
  final String? alleLabel;
  final VoidCallback? onAlle;
  final double size;
  final bool zeigeNamen;

  @override
  Widget build(BuildContext context) {
    final alle = gewaehlt.isEmpty;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          if (alleLabel != null) ...[
            _AlleChip(
              label: alleLabel!,
              selected: alle,
              size: size,
              zeigeName: zeigeNamen,
              onTap: onAlle ?? () {},
            ),
            const SizedBox(width: TdSpace.sm),
          ],
          for (final p in personen) ...[
            TdPersonChip(
              person: p,
              selected: !alle && gewaehlt.contains(p.id),
              gedaempft: !alle && !gewaehlt.contains(p.id),
              size: size,
              zeigeName: zeigeNamen,
              onTap: () => onToggle(p.id),
            ),
            const SizedBox(width: TdSpace.sm),
          ],
        ],
      ),
    );
  }
}

class _AlleChip extends StatelessWidget {
  const _AlleChip({
    required this.label,
    required this.selected,
    required this.size,
    required this.zeigeName,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double size;
  final bool zeigeName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size + 8,
              height: size + 8,
              child: Center(
                child: AnimatedContainer(
                  duration: TdMotion.of(context, TdMotion.base),
                  curve: TdMotion.standard,
                  width: selected ? size + 6 : size,
                  height: selected ? size + 6 : size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? td.primaryGradient : null,
                    color: selected ? null : context.colors.surfaceContainerHighest,
                    boxShadow: selected ? TdShadows.glow(td.palette.primary) : null,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: size * 0.5,
                    color: selected ? td.palette.onPrimary : context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (zeigeName) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? context.colors.onSurface : td.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
