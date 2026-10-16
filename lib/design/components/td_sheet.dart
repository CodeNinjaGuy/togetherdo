/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

/// Zeigt Inhalt als Bottom-Sheet (Handy) oder als zentrierten Dialog
/// (iPad/Mac ab mittlerer Breite). Der Inhalt bleibt derselbe.
Future<T?> showTdSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
  double maxWidth = 560,
}) {
  final compact = context.tdIsCompact;
  final td = context.td;
  final scheme = context.colors;

  Widget body(BuildContext ctx) =>
      _SheetBody(title: title, child: builder(ctx));

  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Über der unteren Navigation (Shell) und mit nur einem Griff –
      // den zeichnet _SheetBody selbst.
      useRootNavigator: true,
      showDragHandle: false,
      isDismissible: isDismissible,
      backgroundColor: scheme.surfaceContainerHigh,
      barrierColor: Colors.black.withValues(alpha: td.isDark ? 0.6 : 0.35),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: body(ctx),
      ),
    );
  }

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: isDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: td.isDark ? 0.6 : 0.35),
    transitionDuration: TdMotion.of(context, TdMotion.page),
    pageBuilder: (ctx, a, s) => SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 720),
          child: Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(TdRadius.xl),
            clipBehavior: Clip.antiAlias,
            child: body(ctx),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, a, s, child) {
      final curved = CurvedAnimation(parent: a, curve: TdMotion.emphasized);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final compact = context.tdIsCompact;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: TdSpace.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(TdRadius.pill),
              ),
            ),
          ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TdSpace.xl,
              TdSpace.xl,
              TdSpace.lg,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title!, style: context.text.headlineSmall),
                ),
                if (!compact)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              TdSpace.xl,
              TdSpace.lg,
              TdSpace.xl,
              TdSpace.xl,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
