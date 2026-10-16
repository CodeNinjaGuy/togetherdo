/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/notification/notification_bloc.dart';
import '../../blocs/notification/notification_event.dart';
import '../../blocs/notification/notification_state.dart';
import '../../design/td_design.dart';
import '../../calendar/widgets/mail_einstellungen.dart';
import '../../models/notification_settings_model.dart';

/// Push-Einstellungen in Gruppen; oben die E-Mail-Erinnerungen des
/// Kalenders (Erinnerungen, Wochen- und Monatsüberblick).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(const NotificationLoadRequested());
  }

  String? get _uid {
    final a = context.read<AuthBloc>().state;
    return a is AuthAuthenticated ? a.user.id : null;
  }

  void _update(NotificationSettings s) =>
      context.read<NotificationBloc>().add(NotificationSettingsChanged(s));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications)),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoadFailure) {
            return Center(
              child: TdEmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.loadError,
                message: state.error,
                action: TdButton.secondary(
                  label: l10n.retry,
                  icon: Icons.refresh_rounded,
                  onPressed: () => context.read<NotificationBloc>().add(
                    const NotificationLoadRequested(),
                  ),
                ),
              ),
            );
          }
          if (state is! NotificationLoadSuccess) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = state.settings;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TdSpace.page,
                  TdSpace.md,
                  TdSpace.page,
                  TdSpace.xxxl,
                ),
                children: [
                  Text(
                    l10n.pushNotificationsDescription,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.td.muted,
                    ),
                  ),
                  const SizedBox(height: TdSpace.lg),
                  if (_uid case final uid?) ...[
                    MailEinstellungen(userId: uid),
                    const SizedBox(height: TdSpace.lg),
                  ],
                  _Group(
                    title: l10n.todoNotifications,
                    icon: Icons.task_alt_rounded,
                    items: [
                      _Item(
                        l10n.newTodoCreated,
                        l10n.newTodoCreatedSubtitle,
                        Icons.add_task_rounded,
                        s.todoCreated,
                        (v) => _update(s.copyWith(todoCreated: v)),
                      ),
                      _Item(
                        l10n.todoCompleted,
                        l10n.todoCompletedSubtitle,
                        Icons.check_circle_outline_rounded,
                        s.todoCompleted,
                        (v) => _update(s.copyWith(todoCompleted: v)),
                      ),
                      _Item(
                        l10n.todoDeleted,
                        l10n.todoDeletedSubtitle,
                        Icons.delete_outline_rounded,
                        s.todoDeleted,
                        (v) => _update(s.copyWith(todoDeleted: v)),
                      ),
                    ],
                  ),
                  _Group(
                    title: l10n.memberNotifications,
                    icon: Icons.people_outline_rounded,
                    items: [
                      _Item(
                        l10n.newMember,
                        l10n.newMemberSubtitle,
                        Icons.person_add_alt_1_rounded,
                        s.memberAdded,
                        (v) => _update(s.copyWith(memberAdded: v)),
                      ),
                      _Item(
                        l10n.memberLeft,
                        l10n.memberLeftSubtitle,
                        Icons.person_remove_alt_1_rounded,
                        s.memberRemoved,
                        (v) => _update(s.copyWith(memberRemoved: v)),
                      ),
                    ],
                  ),
                  _Group(
                    title: l10n.chatNotifications,
                    icon: Icons.chat_bubble_outline_rounded,
                    items: [
                      _Item(
                        l10n.newChatMessage,
                        l10n.newChatMessageSubtitle,
                        Icons.chat_rounded,
                        s.chatMessage,
                        (v) => _update(s.copyWith(chatMessage: v)),
                      ),
                    ],
                  ),
                  _Group(
                    title: l10n.shoppingNotifications,
                    icon: Icons.shopping_basket_outlined,
                    items: [
                      _Item(
                        l10n.newShoppingItem,
                        l10n.newShoppingItemSubtitle,
                        Icons.add_shopping_cart_rounded,
                        s.shoppingItemCreated,
                        (v) => _update(s.copyWith(shoppingItemCreated: v)),
                      ),
                      _Item(
                        l10n.shoppingItemCompleted,
                        l10n.shoppingItemCompletedSubtitle,
                        Icons.check_circle_outline_rounded,
                        s.shoppingItemPurchased,
                        (v) => _update(s.copyWith(shoppingItemPurchased: v)),
                      ),
                      _Item(
                        l10n.shoppingItemDeleted,
                        l10n.shoppingItemDeletedSubtitle,
                        Icons.remove_shopping_cart_outlined,
                        s.shoppingItemDeleted,
                        (v) => _update(s.copyWith(shoppingItemDeleted: v)),
                      ),
                      _Item(
                        l10n.newShoppingMember,
                        l10n.newShoppingMemberSubtitle,
                        Icons.person_add_alt_1_rounded,
                        s.shoppingMemberAdded,
                        (v) => _update(s.copyWith(shoppingMemberAdded: v)),
                      ),
                      _Item(
                        l10n.shoppingMemberLeft,
                        l10n.shoppingMemberLeftSubtitle,
                        Icons.person_remove_alt_1_rounded,
                        s.shoppingMemberRemoved,
                        (v) => _update(s.copyWith(shoppingMemberRemoved: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: TdSpace.lg),
                  Text(l10n.notificationNote, style: context.text.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Item {
  const _Item(this.title, this.subtitle, this.icon, this.value, this.onChanged);

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TdSectionHeader(title: title),
        TdCard(
          padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
          child: Column(
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0) const Divider(indent: TdSpace.lg, endIndent: TdSpace.lg),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile.adaptive(
                    value: item.value,
                    onChanged: item.onChanged,
                    secondary: Icon(item.icon, color: context.colors.primary),
                    title: Text(item.title, style: context.text.bodyLarge),
                    subtitle: Text(item.subtitle, style: context.text.bodySmall),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: TdSpace.lg,
                      vertical: TdSpace.xs,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
