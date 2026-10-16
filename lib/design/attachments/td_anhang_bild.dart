/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/attachment_service.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'anhang_texte.dart';

/// Lädt ein Bild über den [AttachmentService] und blendet es sanft ein.
/// Zeigt bis dahin eine ruhige Fläche, bei Fehlern ein Symbol mit
/// „Erneut versuchen“ (wenn [mitWiederholen]).
class TdAnhangBild extends StatefulWidget {
  const TdAnhangBild({
    super.key,
    required this.service,
    required this.pfad,
    this.fit = BoxFit.cover,
    this.mitWiederholen = false,
    this.dunkel = false,
  });

  final AttachmentService service;
  final String pfad;
  final BoxFit fit;
  final bool mitWiederholen;

  /// Auf schwarzem Hintergrund (Vollbild) helle Platzhalter-Symbole.
  final bool dunkel;

  @override
  State<TdAnhangBild> createState() => _TdAnhangBildState();
}

class _TdAnhangBildState extends State<TdAnhangBild> {
  late Future<Uint8List> _daten;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  @override
  void didUpdateWidget(TdAnhangBild old) {
    super.didUpdateWidget(old);
    if (old.pfad != widget.pfad || old.service != widget.service) _laden();
  }

  void _laden() {
    _daten = widget.service.laden(widget.pfad);
  }

  void _nochmal() => setState(_laden);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fg = widget.dunkel ? Colors.white70 : scheme.onSurfaceVariant;
    return FutureBuilder<Uint8List>(
      future: _daten,
      builder: (context, snap) {
        if (snap.hasError) {
          return Container(
            color: widget.dunkel ? Colors.transparent : scheme.surfaceContainer,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(TdSpace.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_rounded, color: fg),
                if (widget.mitWiederholen) ...[
                  const SizedBox(height: TdSpace.sm),
                  Text(
                    anhangL10n(context).anhangLadeFehler,
                    style: context.text.bodySmall?.copyWith(color: fg),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _nochmal,
                    child: Text(anhangL10n(context).anhangErneut),
                  ),
                ],
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return Container(
            color: widget.dunkel
                ? Colors.transparent
                : scheme.surfaceContainerHigh,
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
          );
        }
        return TweenAnimationBuilder<double>(
          key: ValueKey(widget.pfad),
          tween: Tween(begin: 0, end: 1),
          duration: TdMotion.of(context, TdMotion.slow),
          curve: TdMotion.standard,
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: Image.memory(
            snap.data!,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                Center(child: Icon(Icons.broken_image_rounded, color: fg)),
          ),
        );
      },
    );
  }
}
