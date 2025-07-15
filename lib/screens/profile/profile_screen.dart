import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../widgets/profile/fiberoptics25_logo.dart';
import '../../widgets/profile/language_selector.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _displayNameController.text = authState.user.displayName;
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
    if (!_isEditing) {
      _loadUserData(); // Reset to original values
    }
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        AuthUpdateProfileRequested(
          displayName: _displayNameController.text.trim(),
        ),
      );
      setState(() {
        _isEditing = false;
      });
    }
  }

  void _uploadAvatar() {
    // Avatar-Upload wird in einer späteren Version implementiert
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.avatarUpload)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is AuthAuthenticated) {
                return IconButton(
                  icon: Icon(_isEditing ? Icons.save : Icons.edit),
                  onPressed: _isEditing ? _saveProfile : _toggleEdit,
                  tooltip: _isEditing ? l10n.save : l10n.edit,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          // Loading State während Profile-Update
          if (authState is AuthProfileUpdateLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.profileSaving),
                ],
              ),
            );
          }

          // Failure State nach Profile-Update
          if (authState is AuthProfileUpdateFailure) {
            // Nach Fehler zurück zu AuthAuthenticated
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<AuthBloc>().add(const AuthCheckRequested());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${l10n.saveError}: ${authState.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            });
          }

          // Authenticated State (normaler Zustand)
          if (authState is AuthAuthenticated) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar Section
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: authState.user.avatarUrl != null
                            ? NetworkImage(authState.user.avatarUrl!)
                            : null,
                        child: authState.user.avatarUrl == null
                            ? Text(
                                authState.user.displayName.isNotEmpty
                                    ? authState.user.displayName[0]
                                          .toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                              onPressed: _uploadAvatar,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Fiberoptics25 Logo (nur im Fiberoptics25 Theme sichtbar)
                  const Fiberoptics25Logo(),

                  // Profile Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: l10n.displayName,
                            hintText: l10n.yourName,
                          ),
                          enabled: _isEditing,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.displayNameRequired;
                            }
                            if (value.length < 2) {
                              return l10n.displayNameMinLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: authState.user.email,
                          decoration: InputDecoration(labelText: l10n.email),
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue:
                              '${l10n.memberSince} ${_formatDate(authState.user.createdAt)}',
                          decoration: InputDecoration(
                            labelText: l10n.memberSince,
                          ),
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue:
                              '${l10n.lastLogin}: ${_formatDate(authState.user.lastLoginAt)}',
                          decoration: InputDecoration(
                            labelText: l10n.lastLogin,
                          ),
                          enabled: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Benachrichtigungen Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotificationSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications),
                      label: Text(l10n.notifications),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Theme-Auswahl Dropdown
                  BlocBuilder<ThemeBloc, ThemeState>(
                    builder: (context, themeState) {
                      String currentTheme = 'Light';
                      if (themeState is ThemeLoadSuccess) {
                        currentTheme = themeState.themeName;
                      } else if (themeState is ThemeChangedSuccess) {
                        currentTheme = themeState.themeName;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: DropdownButtonFormField<String>(
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
                                    localizedThemeName =
                                        l10n.theme_fiberoptics25;
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
                              context.read<ThemeBloc>().add(
                                ThemeChanged(value),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),

                  // Language Selector
                  const LanguageSelector(),

                  // Actions
                  if (_isEditing) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: Text(l10n.save),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _toggleEdit,
                        child: Text(l10n.cancel),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _toggleEdit,
                        child: Text(l10n.editProfile),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l10n.logout),
                            content: Text(l10n.logoutConfirm),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(l10n.cancel),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<AuthBloc>().add(
                                    const AuthLogoutRequested(),
                                  );
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onError,
                                ),
                                child: Text(l10n.logout),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                      ),
                      child: Text(l10n.logout),
                    ),
                  ),
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
