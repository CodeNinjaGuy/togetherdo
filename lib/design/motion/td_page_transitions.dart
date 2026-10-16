/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../tokens/td_tokens.dart';

/// Sanfter Seitenwechsel: die neue Seite blendet ein und gleitet leicht
/// von unten nach oben, die alte tritt etwas zurück. Mit „Bewegung
/// reduzieren“ bleibt nur die Überblendung.
abstract final class TdTransitions {
  static Widget fadeSlide(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
      reverseCurve: TdMotion.exit,
    );
    if (TdMotion.reduced(context)) {
      return FadeTransition(opacity: fade, child: child);
    }

    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: TdMotion.emphasized));
    final scaleIn = Tween<double>(
      begin: 0.985,
      end: 1,
    ).animate(CurvedAnimation(parent: animation, curve: TdMotion.standard));
    final scaleOut = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: TdMotion.standard),
    );
    final fadeOut = Tween<double>(begin: 1, end: 0.6).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: TdMotion.standard),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: ScaleTransition(
        scale: scaleOut,
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(scale: scaleIn, child: child),
          ),
        ),
      ),
    );
  }
}

/// Für `ThemeData.pageTransitionsTheme`; gilt dann auch für go_router.
class TdPageTransitionsBuilder extends PageTransitionsBuilder {
  const TdPageTransitionsBuilder();

  @override
  Duration get transitionDuration => TdMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => TdTransitions.fadeSlide(context, animation, secondaryAnimation, child);
}

/// Route mit dem App-Übergang, für `Navigator.push` außerhalb von go_router.
class TdPageRoute<T> extends PageRouteBuilder<T> {
  TdPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionDuration: TdMotion.page,
        reverseTransitionDuration: TdMotion.page,
        transitionsBuilder: TdTransitions.fadeSlide,
      );
}
