import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
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
                  Text('Fehler: ${state.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<NotificationBloc>().add(
                        const NotificationLoadRequested(),
                      );
                    },
                    child: const Text('Erneut versuchen'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Push-Benachrichtigungen',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wähle aus, welche Benachrichtigungen du erhalten möchtest:',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Todo-Benachrichtigungen
          const Text(
            'Todo-Benachrichtigungen',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          _buildSwitchTile(
            title: 'Neues Todo erstellt',
            subtitle:
                'Benachrichtigung wenn ein neues Todo zur Liste hinzugefügt wird',
            value: settings.todoCreated,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(todoCreated: value)),
          ),

          _buildSwitchTile(
            title: 'Todo erledigt',
            subtitle:
                'Benachrichtigung wenn ein Todo als erledigt markiert wird',
            value: settings.todoCompleted,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(todoCompleted: value)),
          ),

          _buildSwitchTile(
            title: 'Todo gelöscht',
            subtitle:
                'Benachrichtigung wenn ein Todo aus der Liste entfernt wird',
            value: settings.todoDeleted,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(todoDeleted: value)),
          ),

          const SizedBox(height: 24),

          // Member-Benachrichtigungen
          const Text(
            'Member-Benachrichtigungen',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          _buildSwitchTile(
            title: 'Neuer Member',
            subtitle:
                'Benachrichtigung wenn ein neuer Member der Liste beitritt',
            value: settings.memberAdded,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(memberAdded: value)),
          ),

          _buildSwitchTile(
            title: 'Member verlassen',
            subtitle: 'Benachrichtigung wenn ein Member die Liste verlässt',
            value: settings.memberRemoved,
            onChanged: (value) =>
                _updateSettings(settings.copyWith(memberRemoved: value)),
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
                    const Text(
                      'Hinweis',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Benachrichtigungen werden nur an andere Mitglieder der Liste gesendet. '
                  'Du erhältst keine Benachrichtigungen für deine eigenen Aktionen.',
                  style: TextStyle(fontSize: 14),
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
    switch (title) {
      case 'Neues Todo erstellt':
        return Icons.add_task;
      case 'Todo erledigt':
        return Icons.check_circle;
      case 'Todo gelöscht':
        return Icons.delete;
      case 'Neuer Member':
        return Icons.person_add;
      case 'Member verlassen':
        return Icons.person_remove;
      default:
        return Icons.notifications;
    }
  }

  void _updateSettings(NotificationSettings newSettings) {
    context.read<NotificationBloc>().add(
      NotificationSettingsChanged(newSettings),
    );
  }
}
