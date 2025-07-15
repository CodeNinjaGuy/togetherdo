import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/notification/notification_bloc.dart';
import '../../blocs/notification/notification_event.dart';
import '../../blocs/notification/notification_state.dart';
import '../../models/notification_settings_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications)),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotificationLoadFailure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('${l10n.error}: ${state.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<NotificationBloc>().add(
                        const NotificationLoadRequested(),
                      );
                    },
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          if (state is NotificationLoadSuccess) {
            return _buildSettingsForm(state.settings);
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildSettingsForm(NotificationSettings settings) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pushNotifications,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pushNotificationsDescription,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Todo-Benachrichtigungen
          Text(
            l10n.todoNotifications,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          _buildSwitchTile(
            title: l10n.newTodoCreated,
            subtitle: l10n.newTodoCreatedSubtitle,
            value: settings.todoCreated,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(todoCreated: value)),
          ),

          _buildSwitchTile(
            title: l10n.todoCompleted,
            subtitle: l10n.todoCompletedSubtitle,
            value: settings.todoCompleted,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(todoCompleted: value)),
          ),

          _buildSwitchTile(
            title: l10n.todoDeleted,
            subtitle: l10n.todoDeletedSubtitle,
            value: settings.todoDeleted,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(todoDeleted: value)),
          ),

          const SizedBox(height: 24),

          // Member-Benachrichtigungen
          Text(
            l10n.memberNotifications,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          _buildSwitchTile(
            title: l10n.newMember,
            subtitle: l10n.newMemberSubtitle,
            value: settings.memberAdded,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(memberAdded: value)),
          ),

          _buildSwitchTile(
            title: l10n.memberLeft,
            subtitle: l10n.memberLeftSubtitle,
            value: settings.memberRemoved,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(memberRemoved: value)),
          ),

          const SizedBox(height: 24),

          // Chat-Benachrichtigungen
          Text(
            l10n.chatNotifications,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          _buildSwitchTile(
            title: l10n.newChatMessage,
            subtitle: l10n.newChatMessageSubtitle,
            value: settings.chatMessage,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(chatMessage: value)),
          ),

          const SizedBox(height: 24),

          // Einkaufslisten-Benachrichtigungen
          Text(
            l10n.shoppingNotifications,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          _buildSwitchTile(
            title: l10n.newShoppingItem,
            subtitle: l10n.newShoppingItemSubtitle,
            value: settings.shoppingItemCreated,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(shoppingItemCreated: value)),
          ),

          _buildSwitchTile(
            title: l10n.shoppingItemCompleted,
            subtitle: l10n.shoppingItemCompletedSubtitle,
            value: settings.shoppingItemPurchased,
            onChanged: (value) => _updateSettings(
              settings.copyWith(shoppingItemPurchased: value),
            ),
          ),

          _buildSwitchTile(
            title: l10n.shoppingItemDeleted,
            subtitle: l10n.shoppingItemDeletedSubtitle,
            value: settings.shoppingItemDeleted,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(shoppingItemDeleted: value)),
          ),

          _buildSwitchTile(
            title: l10n.newShoppingMember,
            subtitle: l10n.newShoppingMemberSubtitle,
            value: settings.shoppingMemberAdded,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(shoppingMemberAdded: value)),
          ),

          _buildSwitchTile(
            title: l10n.shoppingMemberLeft,
            subtitle: l10n.shoppingMemberLeftSubtitle,
            value: settings.shoppingMemberRemoved,
            onChanged: (value) => _updateSettings(
              settings.copyWith(shoppingMemberRemoved: value),
            ),
          ),

          const SizedBox(height: 32),

          // Info Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.note,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.notificationNote,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          _getIconForSetting(title),
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  IconData _getIconForSetting(String title) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return Icons.notifications;
    }

    switch (title) {
      case String s when s == l10n.newTodoCreated:
        return Icons.add_task;
      case String s when s == l10n.todoCompleted:
        return Icons.check_circle;
      case String s when s == l10n.todoDeleted:
        return Icons.delete;
      case String s when s == l10n.newMember:
        return Icons.person_add;
      case String s when s == l10n.memberLeft:
        return Icons.person_remove;
      case String s when s == l10n.newChatMessage:
        return Icons.chat;
      case String s when s == l10n.newShoppingItem:
        return Icons.shopping_cart;
      case String s when s == l10n.shoppingItemCompleted:
        return Icons.check_circle;
      case String s when s == l10n.shoppingItemDeleted:
        return Icons.delete;
      case String s when s == l10n.newShoppingMember:
        return Icons.person_add;
      case String s when s == l10n.shoppingMemberLeft:
        return Icons.person_remove;
      default:
        return Icons.notifications;
    }
  }

  void _updateSettings(NotificationSettings newSettings) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return;
    }
    context.read<NotificationBloc>().add(
      NotificationSettingsChanged(newSettings),
    );
  }
}
