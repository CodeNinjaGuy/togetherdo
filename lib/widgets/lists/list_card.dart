/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/list/list_bloc.dart';
import '../../blocs/list/list_event.dart';
import '../../design/td_design.dart';
import '../../models/list_model.dart';
import 'list_visuals.dart';

/// Karte einer Liste in der Übersicht: Symbol (Hero), Name, Rolle,
/// Mitglieder und Menü (Code teilen, verlassen, löschen).
class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.list,
    required this.currentUserId,
    required this.onTap,
    this.selected = false,
    this.dense = false,
  });

  final ListModel list;
  final String currentUserId;
  final VoidCallback onTap;
  final bool selected;
  final bool dense;

  bool get isOwner => list.ownerId == currentUserId;
  bool get isMember => list.memberIds.contains(currentUserId);
  bool get canEdit => isOwner || (isMember && list.allowEdit);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = context.colors;
    final color = listColor(list);

    final roleTag = isOwner
        ? TdTag(label: l10n.ownList, icon: Icons.star_rounded, color: color)
        : TdTag(label: l10n.member, icon: Icons.groups_rounded);

    return Container(
      decoration: selected
          ? BoxDecoration(
              borderRadius: TdRadius.card,
              border: Border.all(color: scheme.primary, width: 2),
            )
          : null,
      child: TdCard(
        onTap: onTap,
        padding: EdgeInsets.all(dense ? TdSpace.md : TdSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ListIconBadge(list: list, size: dense ? 40 : 48),
                const SizedBox(width: TdSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.name,
                        style: dense
                            ? context.text.titleMedium
                            : context.text.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: TdSpace.xs),
                      Wrap(
                        spacing: TdSpace.xs + 2,
                        runSpacing: TdSpace.xs,
                        children: [
                          roleTag,
                          if (!canEdit)
                            TdTag(
                              label: l10n.readOnly,
                              icon: Icons.lock_outline_rounded,
                              filled: false,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _ListMenu(list: list, currentUserId: currentUserId),
              ],
            ),
            SizedBox(height: dense ? TdSpace.sm : TdSpace.md),
            Row(
              children: [
                ListMembersStack(list: list, size: dense ? 22 : 26),
                const SizedBox(width: TdSpace.sm),
                Expanded(
                  child: Text(
                    l10n.memberCount(list.memberCount),
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (list.shareCode != null && !dense)
                  TdPressable(
                    onTap: () => showShareCodeSheet(context, list),
                    scale: 0.95,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: TdSpace.sm),
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 16,
                          color: context.td.muted,
                        ),
                        const SizedBox(width: TdSpace.xs),
                        Text(
                          list.shareCode!,
                          style: context.text.labelMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            letterSpacing: 1.5,
                            color: context.td.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListMenu extends StatelessWidget {
  const _ListMenu({required this.list, required this.currentUserId});

  final ListModel list;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOwner = list.ownerId == currentUserId;
    final isMember = list.memberIds.contains(currentUserId);
    return PopupMenuButton<String>(
      tooltip: l10n.more,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: Icon(Icons.more_horiz_rounded, color: context.td.muted),
      onSelected: (value) {
        switch (value) {
          case 'share':
            showShareCodeSheet(context, list);
          case 'delete':
            _confirmDelete(context, l10n);
          case 'leave':
            _confirmLeave(context, l10n);
        }
      },
      itemBuilder: (context) => [
        if (list.shareCode != null)
          PopupMenuItem(
            value: 'share',
            child: _MenuRow(Icons.qr_code_2_rounded, l10n.shareCodeTitle),
          ),
        if (isOwner)
          PopupMenuItem(
            value: 'delete',
            child: _MenuRow(
              Icons.delete_outline_rounded,
              l10n.listDeleteTitle,
              danger: true,
            ),
          ),
        if (isMember && !isOwner)
          PopupMenuItem(
            value: 'leave',
            child: _MenuRow(Icons.logout_rounded, l10n.listLeaveTitle),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
    final bloc = context.read<ListBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.listDeleteTitle),
        content: Text(l10n.listDeleteContent(list.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: ctx.td.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      bloc.add(ListDeleteRequested(listId: list.id, ownerId: currentUserId));
    }
  }

  Future<void> _confirmLeave(BuildContext context, AppLocalizations l10n) async {
    final bloc = context.read<ListBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.listLeaveTitle),
        content: Text(l10n.listLeaveContent(list.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (ok == true) {
      bloc.add(ListLeaveRequested(listId: list.id, userId: currentUserId));
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.danger = false});

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.td.danger : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: TdSpace.md),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

/// Sheet „Code teilen“: großer Code zum Abschreiben, Kopieren mit Toast.
Future<void> showShareCodeSheet(BuildContext context, ListModel list) {
  final l10n = AppLocalizations.of(context)!;
  final code = list.shareCode ?? '';
  return showTdSheet<void>(
    context,
    title: l10n.shareCodeTitle,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.shareCodeDescription, style: ctx.text.bodyMedium),
        const SizedBox(height: TdSpace.xl),
        TdCard(
          variant: TdCardVariant.gradient,
          padding: const EdgeInsets.symmetric(
            vertical: TdSpace.xl,
            horizontal: TdSpace.lg,
          ),
          child: Column(
            children: [
              Text(
                list.name,
                style: ctx.text.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: TdSpace.sm),
              Text(
                code.split('').join(' '),
                style: ctx.text.displayMedium?.copyWith(
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TdSpace.xl),
        TdButton.primary(
          label: l10n.copy,
          icon: Icons.copy_rounded,
          expanded: true,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Navigator.of(ctx).maybePop();
            TdToast.show(
              context,
              l10n.codeCopied,
              variant: TdToastVariant.success,
            );
          },
        ),
      ],
    ),
  );
}
