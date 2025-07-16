import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_state.dart';
import '../../blocs/theme/theme_event.dart';
import '../../widgets/profile/language_selector.dart';
import 'notification_settings_screen.dart';

class ProfileScreenDesktop extends StatefulWidget {
  const ProfileScreenDesktop({Key? key}) : super(key: key);

  @override
  State<ProfileScreenDesktop> createState() => _ProfileScreenDesktopState();
}

class _ProfileScreenDesktopState extends State<ProfileScreenDesktop> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<_ProfileSection> sections = [
      _ProfileSection(
        icon: Icons.person,
        label: l10n.profile,
        builder: _buildProfileSection,
      ),
      _ProfileSection(
        icon: Icons.notifications,
        label: l10n.notifications,
        builder: _buildNotificationSection,
      ),
      _ProfileSection(
        icon: Icons.color_lens,
        label: l10n.theme,
        builder: _buildThemeSection,
      ),
      _ProfileSection(
        icon: Icons.language,
        label: l10n.language,
        builder: _buildLanguageSection,
      ),
      _ProfileSection(
        icon: Icons.info_outline,
        label: l10n.privacySecurity,
        builder: _buildPrivacySection,
      ),
      _ProfileSection(
        icon: Icons.delete_forever,
        label: l10n.deleteAccount,
        builder: _buildDeleteAccountSection,
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final section in sections)
                NavigationRailDestination(
                  icon: Icon(section.icon),
                  label: Text(section.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: sections[_selectedIndex].builder(context, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, AppLocalizations l10n) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = authState.user;
    final displayNameController = TextEditingController(text: user.displayName);
    bool isEditing = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        tooltip: l10n.avatarUpload,
                        onPressed: () {
                          // Avatar-Upload-Logik (optional)
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isEditing
                          ? TextFormField(
                              controller: displayNameController,
                              decoration: InputDecoration(
                                labelText: l10n.displayName,
                                border: const OutlineInputBorder(),
                              ),
                            )
                          : Text(
                              user.displayName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                      const SizedBox(height: 8),
                      Text(user.email),
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.memberSince} ${_formatDate(user.createdAt)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                isEditing
                    ? Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              // Speichern
                              context.read<AuthBloc>().add(
                                AuthUpdateProfileRequested(
                                  displayName: displayNameController.text
                                      .trim(),
                                ),
                              );
                              setState(() => isEditing = false);
                            },
                            child: Text(l10n.save),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              displayNameController.text = user.displayName;
                              setState(() => isEditing = false);
                            },
                            child: Text(l10n.cancel),
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: () => setState(() => isEditing = true),
                        icon: const Icon(Icons.edit),
                        label: Text(l10n.editProfile),
                      ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Widget _buildNotificationSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return const NotificationSettingsScreen();
  }

  Widget _buildThemeSection(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        String currentTheme = 'Light';
        if (themeState is ThemeLoadSuccess) {
          currentTheme = themeState.themeName;
        } else if (themeState is ThemeChangedSuccess) {
          currentTheme = themeState.themeName;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.theme, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: currentTheme,
              decoration: InputDecoration(
                labelText: l10n.theme,
                border: const OutlineInputBorder(),
              ),
              items:
                  [
                    'Light',
                    'Matrix',
                    'Neo',
                    'Summer',
                    'Aurora',
                    'Sunset',
                    'Ocean',
                    'Forest',
                    'Galaxy',
                    'Fiberoptics25',
                  ].map((theme) {
                    String localizedThemeName;
                    switch (theme) {
                      case 'Light':
                        localizedThemeName = l10n.theme_light;
                        break;
                      case 'Matrix':
                        localizedThemeName = l10n.theme_matrix;
                        break;
                      case 'Neo':
                        localizedThemeName = l10n.theme_neo;
                        break;
                      case 'Summer':
                        localizedThemeName = l10n.theme_summer;
                        break;
                      case 'Aurora':
                        localizedThemeName = l10n.theme_aurora;
                        break;
                      case 'Sunset':
                        localizedThemeName = l10n.theme_sunset;
                        break;
                      case 'Ocean':
                        localizedThemeName = l10n.theme_ocean;
                        break;
                      case 'Forest':
                        localizedThemeName = l10n.theme_forest;
                        break;
                      case 'Galaxy':
                        localizedThemeName = l10n.theme_galaxy;
                        break;
                      case 'Fiberoptics25':
                        localizedThemeName = l10n.theme_fiberoptics25;
                        break;
                      default:
                        localizedThemeName = theme;
                    }
                    return DropdownMenuItem(
                      value: theme,
                      child: Text(localizedThemeName),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  context.read<ThemeBloc>().add(ThemeChanged(value));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.language, style: Theme.of(context).textTheme.titleMedium),
        const LanguageSelector(),
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.privacySecurity,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Text(l10n.privacySecurityDescription),
        const SizedBox(height: 16),
        Text(
          l10n.privacySecuritySteps,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text('• ${l10n.privacySecurityStep1}'),
        Text('• ${l10n.privacySecurityStep2}'),
        Text('• ${l10n.privacySecurityStep3}'),
        const SizedBox(height: 16),
        Text(
          l10n.privacySecurityIrreversible,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDeleteAccountSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.deleteAccount,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.deleteAccountWarning,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.delete_forever),
          label: Text(l10n.deleteAccount),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () {
            // TODO: Dialog und Lösch-Logik wie auf Mobile
          },
        ),
      ],
    );
  }
}

class _ProfileSection {
  final IconData icon;
  final String label;
  final Widget Function(BuildContext, AppLocalizations) builder;
  _ProfileSection({
    required this.icon,
    required this.label,
    required this.builder,
  });
}
