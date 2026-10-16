/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/list/list_bloc.dart';
import '../../blocs/list/list_event.dart';
import '../../blocs/list/list_state.dart';
import '../../design/td_design.dart';
import '../../models/list_model.dart';
import '../../widgets/lists/list_card.dart';
import '../../widgets/lists/list_sheets.dart';
import '../../widgets/lists/list_visuals.dart';

/// Übersicht aller Listen. Als [panel] ist sie die linke Spalte neben
/// einer geöffneten Liste (iPad/Mac).
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key, this.panel = false, this.selectedListId});

  final bool panel;
  final String? selectedListId;

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  List<ListModel>? _lists;

  @override
  void initState() {
    super.initState();
    final s = context.read<ListBloc>().state;
    if (s is ListLoadSuccess) _lists = s.lists;
    if (s is! ListLoadSuccess && s is! ListLoading) _load();
  }

  void _load() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<ListBloc>().add(ListLoadRequested(userId: auth.user.id));
    }
  }

  void _open(ListModel list) {
    context.go(
      list.type == ListType.todo ? '/todo/${list.id}' : '/shopping/${list.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.id : '';

    return BlocConsumer<ListBloc, ListState>(
      listener: (context, state) {
        if (state is ListLoadSuccess) _lists = state.lists;
        if (widget.panel) return;
        switch (state) {
          case ListLeaveSuccess():
            TdToast.show(context, l10n.listLeft, variant: TdToastVariant.info);
          case ListDeleteSuccess():
            TdToast.show(
              context,
              l10n.listDeleted,
              variant: TdToastVariant.info,
              icon: Icons.delete_outline_rounded,
            );
          case ListLeaveFailure(:final message):
          case ListDeleteFailure(:final message):
            TdToast.show(context, message, variant: TdToastVariant.error);
          default:
            break;
        }
      },
      builder: (context, state) {
        final lists = _lists;
        Widget body;
        if (state is ListLoadFailure && lists == null) {
          body = Center(
            child: TdEmptyState(
              icon: Icons.cloud_off_rounded,
              title: l10n.loadError,
              message: state.message,
              action: TdButton.secondary(
                label: l10n.tryAgain,
                icon: Icons.refresh_rounded,
                onPressed: _load,
              ),
            ),
          );
        } else if (lists == null) {
          body = const Center(child: CircularProgressIndicator());
        } else if (lists.isEmpty) {
          body = Center(
            child: SingleChildScrollView(
              child: TdEmptyState(
                icon: Icons.playlist_add_rounded,
                title: l10n.noLists,
                message: l10n.createOrJoinList,
                action: Wrap(
                  spacing: TdSpace.sm,
                  runSpacing: TdSpace.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    TdButton.primary(
                      label: l10n.createList,
                      icon: Icons.add_rounded,
                      onPressed: () => showCreateListSheet(context),
                    ),
                    TdButton.secondary(
                      label: l10n.joinList,
                      icon: Icons.group_add_rounded,
                      onPressed: () => showJoinListSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          body = _ListsBody(
            lists: lists,
            uid: uid,
            panel: widget.panel,
            selectedListId: widget.selectedListId,
            onOpen: _open,
          );
        }

        if (widget.panel) {
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TdSpace.lg,
                      TdSpace.md,
                      TdSpace.sm,
                      TdSpace.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.navLists,
                            style: context.text.headlineSmall,
                          ),
                        ),
                        TdIconButton(
                          icon: Icons.group_add_rounded,
                          tooltip: l10n.joinList,
                          size: 38,
                          onPressed: () => showJoinListSheet(context),
                        ),
                        const SizedBox(width: TdSpace.sm),
                        TdIconButton(
                          icon: Icons.add_rounded,
                          tooltip: l10n.createList,
                          filled: true,
                          size: 38,
                          onPressed: () => showCreateListSheet(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(bottom: false, child: body),
          floatingActionButton: lists == null || lists.isEmpty
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'fab-lists',
                  onPressed: () => showCreateListSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.newList),
                ),
        );
      },
    );
  }
}

class _ListsBody extends StatelessWidget {
  const _ListsBody({
    required this.lists,
    required this.uid,
    required this.panel,
    required this.selectedListId,
    required this.onOpen,
  });

  final List<ListModel> lists;
  final String uid;
  final bool panel;
  final String? selectedListId;
  final ValueChanged<ListModel> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final todo = lists.where((l) => l.type == ListType.todo).toList();
    final shopping = lists.where((l) => l.type == ListType.shopping).toList();
    final wide = !panel && context.tdLayout != TdLayoutSize.compact;

    Widget section(String title, List<ListModel> items, int offset) {
      if (items.isEmpty) return const SizedBox.shrink();
      final cards = [
        for (final (i, l) in items.indexed)
          TdFadeSlideIn(
            key: ValueKey(l.id),
            index: offset + i,
            child: ListCard(
              list: l,
              currentUserId: uid,
              selected: l.id == selectedListId,
              dense: panel,
              onTap: () => onOpen(l),
            ),
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              TdSpace.xs,
              panel ? TdSpace.md : TdSpace.xl,
              0,
              TdSpace.md,
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: panel
                      ? context.text.titleMedium
                      : context.text.titleLarge,
                ),
                const SizedBox(width: TdSpace.sm),
                CountPill(count: items.length),
              ],
            ),
          ),
          if (wide)
            LayoutBuilder(
              builder: (context, c) => GridView(
                shrinkWrap: true,
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  // Karten mindestens 300 Punkte breit.
                  crossAxisCount: (c.maxWidth / 300).floor().clamp(1, 4),
                  mainAxisSpacing: TdSpace.md,
                  crossAxisSpacing: TdSpace.md,
                  mainAxisExtent: 168,
                ),
                children: cards,
              ),
            )
          else
            for (final c in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: TdSpace.md),
                child: c,
              ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        panel ? TdSpace.md : TdSpace.page,
        panel ? 0 : TdSpace.lg,
        panel ? TdSpace.md : TdSpace.page,
        120,
      ),
      children: [
        if (!panel)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.myLists, style: context.text.headlineLarge),
                    const SizedBox(height: TdSpace.xs),
                    Text(
                      l10n.listCountSummary(lists.length),
                      style: context.text.bodyMedium?.copyWith(
                        color: context.td.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TdIconButton(
                icon: Icons.group_add_rounded,
                tooltip: l10n.joinList,
                onPressed: () => showJoinListSheet(context),
              ),
            ],
          ),
        section(l10n.todoLists, todo, 0),
        section(l10n.shoppingLists, shopping, todo.length),
      ],
    );
  }
}
