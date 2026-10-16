/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../../design/td_design.dart';

/// Produktbild eines Einkaufsartikels. Ohne Bild (oder wenn es nicht
/// geladen werden kann) ein weicher Farbfleck mit Korb-Symbol.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.radius = TdRadius.sm,
    this.dimmed = false,
  });

  final String? imageUrl;
  final double size;
  final double radius;

  /// Gedämpft (gekaufter Artikel).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final td = context.td;
    final url = imageUrl;

    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: td.isDark ? 0.3 : 0.12),
            scheme.secondary.withValues(alpha: td.isDark ? 0.25 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_basket_outlined,
        size: size * 0.46,
        color: scheme.primary.withValues(alpha: 0.85),
      ),
    );

    Widget child = placeholder;
    if (url != null && url.isNotEmpty) {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => placeholder,
          frameBuilder: (context, img, frame, wasSync) {
            if (wasSync || frame != null) return img;
            return placeholder;
          },
        ),
      );
    }

    return AnimatedOpacity(
      duration: TdMotion.of(context, TdMotion.base),
      opacity: dimmed ? 0.55 : 1,
      child: child,
    );
  }
}
