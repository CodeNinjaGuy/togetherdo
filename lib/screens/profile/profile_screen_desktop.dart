import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../widgets/profile/language_selector.dart';
import 'notification_settings_screen.dart';

class ProfileScreenDesktop extends StatefulWidget {
  const ProfileScreenDesktop({super.key});

  @override
  State<ProfileScreenDesktop> createState() => _ProfileScreenDesktopState();
}

class _ProfileScreenDesktopState extends State<ProfileScreenDesktop> {
  int _selectedIndex = 0;
  StreamSubscription? _authSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final sections = [
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
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
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

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  Widget _buildNotificationSection(
    BuildContext context,
    AppLocalizations l10n,
  ) => const NotificationSettingsScreen();

  Widget _buildThemeSection(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        String currentTheme = 'Light';
        if (themeState is ThemeLoadSuccess) {
          currentTheme = themeState.themeName;
        }
        if (themeState is ThemeChangedSuccess) {
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
                    final localizedThemeName =
                        {
                          'Light': l10n.theme_light,
                          'Matrix': l10n.theme_matrix,
                          'Neo': l10n.theme_neo,
                          'Summer': l10n.theme_summer,
                          'Aurora': l10n.theme_aurora,
                          'Sunset': l10n.theme_sunset,
                          'Ocean': l10n.theme_ocean,
                          'Forest': l10n.theme_forest,
                          'Galaxy': l10n.theme_galaxy,
                          'Fiberoptics25': l10n.theme_fiberoptics25,
                        }[theme] ??
                        theme;

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

  Widget _buildLanguageSection(BuildContext context, AppLocalizations l10n) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.language, style: Theme.of(context).textTheme.titleMedium),
          const LanguageSelector(),
        ],
      );

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
          onPressed: () => _startAccountDeletion(),
        ),
      ],
    );
  }

  void _startAccountDeletion() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final authBloc = context.read<AuthBloc>();
    final deletionStepNotifier = ValueNotifier<int>(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n?.deletingAccount ?? 'Account wird gelöscht'),
          content: ValueListenableBuilder<int>(
            valueListenable: deletionStepNotifier,
            builder: (context, step, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepRow(
                    l10n?.deleteAccountStep1 ?? 'Aus allen Listen austreten',
                    step > 0,
                  ),
                  _buildStepRow(
                    l10n?.deleteAccountStep2 ?? 'Eigene Listen löschen',
                    step > 1,
                  ),
                  _buildStepRow(
                    l10n?.deleteAccountStep3 ?? 'Account löschen',
                    step > 2,
                  ),
                  const SizedBox(height: 16),
                  if (step < 3) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(l10n?.deletingAccountProgress ?? 'Bitte warten ...'),
                  ],
                ],
              );
            },
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    deletionStepNotifier.value = 1;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    deletionStepNotifier.value = 2;
    await Future.delayed(
      const Duration(seconds: 5),
    ); // <-- hier auf 5 Sekunden erhöht
    if (!mounted) return;
    deletionStepNotifier.value = 3;
    authBloc.add(const AuthDeleteAccountRequested());

    _authSubscription = authBloc.stream.listen((state) async {
      if (!mounted) return;
      if (state is AuthFailure) {
        navigator.pop();
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        final msg = (state.message).toLowerCase();
        if (msg.contains('reauth') ||
            msg.contains('re-auth') ||
            msg.contains('erneut') ||
            msg.contains('authentifizierung')) {
          await _showReAuthPasswordDialog(context);
          // Nach erfolgreicher Re-Auth Account-Löschung erneut starten
          if (mounted) _startAccountDeletion();
        } else {
          messenger.showSnackBar(SnackBar(content: Text(state.message)));
        }
      } else if (state is AuthUnauthenticated) {
        navigator.pop();
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n?.accountDeleted ?? 'Account deleted')),
        );
      }
    });
  }

  Widget _buildStepRow(String text, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            text + (done ? ' ... erledigt' : ' ...'),
            style: TextStyle(
              color: done ? Colors.green : null,
              fontWeight: done ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
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

Future<void> _showReAuthPasswordDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final TextEditingController passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final authBloc = context.read<AuthBloc>();
  bool loading = false;
  String? errorMessage;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.security,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(l10n?.reAuthRequired ?? 'Re-Authentifizierung'),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n?.reAuthRequiredMessage ??
                        'Bitte gib dein Passwort ein, um fortzufahren.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n?.password ?? 'Passwort',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n?.passwordRequired ??
                            'Passwort erforderlich';
                      }
                      return null;
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n?.cancel ?? 'Abbrechen'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => loading = true);
                        try {
                          await authBloc.stream.firstWhere(
                            (state) => state is! AuthLoading,
                          );
                          authBloc.add(
                            AuthReauthenticateRequested(
                              password: passwordController.text,
                            ),
                          );
                          final result = await authBloc.stream.firstWhere(
                            (state) => state is! AuthLoading,
                          );
                          if (result is AuthFailure) {
                            setState(() {
                              errorMessage = result.message;
                              loading = false;
                            });
                          } else {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        } catch (e) {
                          setState(() {
                            errorMessage = e.toString();
                            loading = false;
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n?.loginAgain ?? 'Erneut einloggen'),
              ),
            ],
          );
        },
      );
    },
  );
}
