/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

/// Ein Ziel der Hauptnavigation.
@immutable
class TdDestination {
  const TdDestination({
    required this.icon,
    required this.label,
    IconData? selectedIcon,
  }) : selectedIcon = selectedIcon ?? icon;

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Gerüst mit Navigation, das sich der Breite anpasst:
/// Handy → Leiste unten, iPad → Schiene links, Mac/breit → ausgeklappte
/// Schiene mit Beschriftungen. Der Inhalt bleibt derselbe.
class TdAdaptiveScaffold extends StatelessWidget {
  const TdAdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.floatingActionButton,
    this.railHeader,
    this.appBar,
    this.maxContentWidth = 1100,
  });

  final List<TdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget? floatingActionButton;

  /// Oben in der Schiene, z. B. Logo oder Avatar.
  final Widget? railHeader;
  final PreferredSizeWidget? appBar;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final layout = context.tdLayout;
    final scheme = context.colors;

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: body,
      ),
    );

    if (layout == TdLayoutSize.compact) {
      return Scaffold(
        appBar: appBar,
        body: content,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        ),
      );
    }

    final extended = layout == TdLayoutSize.expanded;
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(right: BorderSide(color: scheme.outlineVariant)),
            ),
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 220,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: railHeader == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: TdSpace.lg),
                      child: railHeader,
                    ),
              groupAlignment: -0.9,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                    padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
                  ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Überschrift eines Abschnitts mit optionaler Aktion rechts („Alle“).
class TdSectionHeader extends StatelessWidget {
  const TdSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(0, TdSpace.xl, 0, TdSpace.md),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: context.text.bodySmall,
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: TdSpace.sm),
                minimumSize: const Size(0, 36),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
