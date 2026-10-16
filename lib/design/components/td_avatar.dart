/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';

/// Darstellungsdaten einer Person: Name (für Initialen), optional Bild
/// und feste Farbe. Ohne Farbe wird sie aus dem Namen abgeleitet, damit
/// dieselbe Person überall gleich aussieht.
@immutable
class TdAvatarData {
  const TdAvatarData({required this.name, this.imageUrl, this.color, this.id});

  final String name;
  final String? imageUrl;
  final Color? color;
  final String? id;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  /// Warme, gut unterscheidbare Farben; stabil je Name.
  static const palette = <Color>[
    Color(0xFF6A5AE0),
    Color(0xFFFF7A59),
    Color(0xFF1FB38F),
    Color(0xFFF2A500),
    Color(0xFFE05A8E),
    Color(0xFF2E9BE0),
    Color(0xFF8E5BD6),
    Color(0xFF3FB950),
  ];

  Color resolveColor() {
    if (color != null) return color!;
    final key = id ?? name;
    var hash = 0;
    for (final c in key.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }
}

/// Runder Avatar mit Bild oder Initialen auf farbigem Verlauf.
class TdAvatar extends StatelessWidget {
  const TdAvatar({
    super.key,
    required this.data,
    this.size = 36,
    this.borderColor,
    this.borderWidth = 0,
  });

  final TdAvatarData data;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final base = data.resolveColor();
    final url = data.imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [base, Color.lerp(base, Colors.white, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? context.colors.surface, width: borderWidth)
            : null,
        image: url != null && url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: url != null && url.isNotEmpty
          ? null
          : Text(
              data.initials,
              style: context.text.labelMedium?.copyWith(
                color: Colors.white,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
    );
  }
}

/// Überlappende Avatare („wer ist dabei“), mit „+3“ wenn mehr als `max`.
class TdAvatarStack extends StatelessWidget {
  const TdAvatarStack({
    super.key,
    required this.people,
    this.size = 32,
    this.max = 4,
    this.overlap = 0.3,
  });

  final List<TdAvatarData> people;
  final double size;
  final int max;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    final rest = people.length - shown.length;
    final step = size * (1 - overlap);
    final count = shown.length + (rest > 0 ? 1 : 0);
    final scheme = context.colors;
    return SizedBox(
      width: count == 0 ? 0 : size + (count - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: TdAvatar(
                data: shown[i],
                size: size,
                borderWidth: 2,
                borderColor: scheme.surface,
              ),
            ),
          if (rest > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$rest',
                  style: context.text.labelSmall?.copyWith(
                    fontSize: size * 0.34,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
