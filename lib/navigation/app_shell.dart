/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/list/list_bloc.dart';
import '../blocs/list/list_event.dart';
import '../blocs/list/list_state.dart';
import '../design/td_design.dart';
import '../screens/lists/lists_screen.dart';

/// Ziele der Hauptnavigation in fester Reihenfolge.
enum ShellTab { today, lists, calendar, profile }

/// Gerüst der angemeldeten App: Handy unten, iPad Schiene, Mac
/// ausgeklappte Schiene. Auf breiten Bildschirmen zeigt eine Listen-
/// Detailseite links die Listenübersicht als Spalte.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static ShellTab tabFor(String location) {
    if (location == '/' || location.startsWith('/heute')) return ShellTab.today;
    if (location.startsWith('/kalender')) return ShellTab.calendar;
    if (location.startsWith('/profile')) return ShellTab.profile;
    return ShellTab.lists;
  }

  static String pathFor(ShellTab tab) => switch (tab) {
    ShellTab.today => '/',
    ShellTab.lists => '/lists',
    ShellTab.calendar => '/kalender',
    ShellTab.profile => '/profile',
  };

  /// Detailseiten, die auf breiten Bildschirmen neben der Listenübersicht
  /// erscheinen.
  static bool isListDetail(String location) =>
      location.startsWith('/todo/') || location.startsWith('/shopping/');

  static String? listIdOf(String location) {
    final parts = Uri.parse(location).pathSegments;
    if (parts.length >= 2 && (parts[0] == 'todo' || parts[0] == 'shopping')) {
      return parts[1];
    }
    return null;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _loadedFor;

  void _ensureLists(AuthAuthenticated auth) {
    if (_loadedFor == auth.user.id) return;
    _loadedFor = auth.user.id;
    final bloc = context.read<ListBloc>();
    if (bloc.state is! ListLoadSuccess) {
      bloc.add(ListLoadRequested(userId: auth.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final location = GoRouterState.of(context).uri.path;
    final tab = AppShell.tabFor(location);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthUnauthenticated) {
          // Nach dem Abmelden (Profil, Kontolöschung) zur Anmeldung.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (authState is! AuthAuthenticated) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: TdSpace.lg),
                  Text(l10n.loading, style: context.text.bodyLarge),
                ],
              ),
            ),
          );
        }
        _ensureLists(authState);
        final user = authState.user;
        final layout = context.tdLayout;
        final split =
            layout != TdLayoutSize.compact && AppShell.isListDetail(location);

        final destinations = [
          TdDestination(
            icon: Icons.wb_sunny_outlined,
            selectedIcon: Icons.wb_sunny_rounded,
            label: l10n.navToday,
          ),
          TdDestination(
            icon: Icons.checklist_rounded,
            selectedIcon: Icons.checklist_rounded,
            label: l10n.navLists,
          ),
          TdDestination(
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month_rounded,
            label: l10n.navCalendar,
          ),
          TdDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: l10n.navProfile,
          ),
        ];

        Widget body = widget.child;
        if (split) {
          body = Row(
            children: [
              SizedBox(
                width: layout == TdLayoutSize.expanded ? 380 : 320,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: context.colors.outlineVariant),
                    ),
                  ),
                  child: ListsScreen(
                    panel: true,
                    selectedListId: AppShell.listIdOf(location),
                  ),
                ),
              ),
              Expanded(child: widget.child),
            ],
          );
        }

        return TdAdaptiveScaffold(
          destinations: destinations,
          selectedIndex: tab.index,
          maxContentWidth: split ? double.infinity : 1100,
          onSelected: (i) {
            final target = ShellTab.values[i];
            if (target == tab && !AppShell.isListDetail(location)) return;
            context.go(AppShell.pathFor(target));
          },
          railHeader: _RailHeader(
            name: user.displayName,
            imageUrl: user.avatarUrl,
            extended: layout == TdLayoutSize.expanded,
            onTap: () => context.go('/profile'),
          ),
          body: body,
        );
      },
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.name,
    required this.imageUrl,
    required this.extended,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = TdAvatar(
      data: TdAvatarData(name: name, imageUrl: imageUrl),
      size: 40,
    );
    return TdPressable(
      onTap: onTap,
      scale: 0.95,
      child: extended
          ? Container(
              // Die Schiene gibt ihrem Kopf keine Breite vor.
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: TdSpace.md),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: TdSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ToGetherDo',
                          style: context.text.labelSmall,
                        ),
                        Text(
                          name,
                          style: context.text.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : avatar,
    );
  }
}
