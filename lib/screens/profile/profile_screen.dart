import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';

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
    // TODO: Implement avatar upload
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar-Upload wird später implementiert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is AuthAuthenticated) {
                return IconButton(
                  icon: Icon(_isEditing ? Icons.save : Icons.edit),
                  onPressed: _isEditing ? _saveProfile : _toggleEdit,
                  tooltip: _isEditing ? 'Speichern' : 'Bearbeiten',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
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

                  // Profile Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: 'Anzeigename',
                            hintText: 'Dein Name',
                          ),
                          enabled: _isEditing,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Anzeigename ist erforderlich';
                            }
                            if (value.length < 2) {
                              return 'Anzeigename muss mindestens 2 Zeichen lang sein';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: authState.user.email,
                          decoration: const InputDecoration(
                            labelText: 'E-Mail',
                          ),
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue:
                              'Mitglied seit ${_formatDate(authState.user.createdAt)}',
                          decoration: const InputDecoration(
                            labelText: 'Mitglied seit',
                          ),
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue:
                              'Letzter Login: ${_formatDate(authState.user.lastLoginAt)}',
                          decoration: const InputDecoration(
                            labelText: 'Letzter Login',
                          ),
                          enabled: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

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
                          decoration: const InputDecoration(
                            labelText: 'Theme',
                            border: OutlineInputBorder(),
                          ),
                          items: ['Light', 'Matrix', 'Neo', 'Summer']
                              .map(
                                (theme) => DropdownMenuItem(
                                  value: theme,
                                  child: Text(theme),
                                ),
                              )
                              .toList(),
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

                  // Actions
                  if (_isEditing) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('Speichern'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _toggleEdit,
                        child: const Text('Abbrechen'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _toggleEdit,
                        child: const Text('Profil bearbeiten'),
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
                            title: const Text('Abmelden'),
                            content: const Text(
                              'Möchtest du dich wirklich abmelden?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Abbrechen'),
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
                                child: const Text('Abmelden'),
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
                      child: const Text('Abmelden'),
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
