/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../tokens/td_tokens.dart';

/// Liste, die Einfügen und Entfernen von Einträgen animiert, ohne dass
/// der Aufrufer `AnimatedListState` verwalten muss. Einträge werden über
/// `keyOf` wiedererkannt; neue gleiten ein, entfernte klappen zu.
/// Reihenfolgeänderungen werden ohne Animation übernommen.
class TdAnimatedList<T> extends StatefulWidget {
  const TdAnimatedList({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.spacing = TdSpace.sm,
    this.primary,
  });

  final List<T> items;
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final double spacing;
  final bool? primary;

  @override
  State<TdAnimatedList<T>> createState() => _TdAnimatedListState<T>();
}

class _TdAnimatedListState<T> extends State<TdAnimatedList<T>> {
  final _listKey = GlobalKey<AnimatedListState>();
  late List<T> _shown = List.of(widget.items);

  @override
  void didUpdateWidget(TdAnimatedList<T> old) {
    super.didUpdateWidget(old);
    _sync(widget.items);
  }

  void _sync(List<T> next) {
    final nextKeys = next.map(widget.keyOf).toSet();
    final state = _listKey.currentState;
    final d = TdMotion.of(context, TdMotion.slow);

    // Entfernte Einträge: von hinten nach vorne herausnehmen.
    for (var i = _shown.length - 1; i >= 0; i--) {
      final item = _shown[i];
      if (nextKeys.contains(widget.keyOf(item))) continue;
      _shown.removeAt(i);
      state?.removeItem(
        i,
        (context, animation) => _transition(animation, _build(item, i)),
        duration: d,
      );
    }

    // Neue Einträge an ihrer Zielposition einfügen.
    final shownKeys = _shown.map(widget.keyOf).toSet();
    for (var i = 0; i < next.length; i++) {
      final item = next[i];
      if (shownKeys.contains(widget.keyOf(item))) continue;
      final at = i.clamp(0, _shown.length);
      _shown.insert(at, item);
      state?.insertItem(at, duration: d);
    }

    // Aktualisierte Daten und Reihenfolge übernehmen.
    _shown = List.of(next);
  }

  Widget _build(T item, int index) => widget.itemBuilder(context, item, index);

  Widget _transition(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: TdMotion.standard,
      reverseCurve: TdMotion.exit,
    );
    final reduced = TdMotion.reduced(context);
    Widget w = FadeTransition(opacity: curved, child: child);
    if (!reduced) {
      w = SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: w,
      );
    }
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.spacing),
        child: w,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      initialItemCount: _shown.length,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      primary: widget.primary,
      itemBuilder: (context, index, animation) {
        if (index >= _shown.length) return const SizedBox.shrink();
        return _transition(animation, _build(_shown[index], index));
      },
    );
  }
}
