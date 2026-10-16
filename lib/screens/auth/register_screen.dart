/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../design/td_design.dart';
import '../../widgets/auth/auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) context.go('/');
      },
      builder: (context, state) {
        final loading = state is AuthLoading;
        return AuthScaffold(
          title: l10n.createAccount,
          subtitle: l10n.createAccountSubtitle,
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.alreadyHaveAccount, style: context.text.bodyMedium),
              TextButton(
                onPressed: loading ? null : () => context.go('/login'),
                child: Text(l10n.login),
              ),
            ],
          ),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TdTextField(
                    controller: _name,
                    label: l10n.displayName,
                    hint: l10n.nameHint,
                    prefixIcon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    enabled: !loading,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.displayNameRequired;
                      }
                      if (v.trim().length < 2) return l10n.displayNameMinLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: TdSpace.lg),
                  TdTextField(
                    controller: _email,
                    label: l10n.email,
                    hint: l10n.emailHint,
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    enabled: !loading,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.emailRequired;
                      if (!looksLikeEmail(v)) return l10n.invalidEmail;
                      return null;
                    },
                  ),
                  const SizedBox(height: TdSpace.lg),
                  TdTextField(
                    controller: _password,
                    label: l10n.password,
                    hint: l10n.passwordMinLength,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    showPasswordLabel: l10n.showPassword,
                    hidePasswordLabel: l10n.hidePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    enabled: !loading,
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.passwordRequired;
                      if (v.length < 6) return l10n.passwordMinLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: TdSpace.lg),
                  TdTextField(
                    controller: _confirm,
                    label: l10n.confirmPassword,
                    hint: l10n.passwordConfirmHint,
                    prefixIcon: Icons.lock_reset_rounded,
                    obscureText: true,
                    showPasswordLabel: l10n.showPassword,
                    hidePasswordLabel: l10n.hidePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !loading,
                    onSubmitted: (_) => _register(),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return l10n.confirmPasswordRequired;
                      }
                      if (v != _password.text) return l10n.passwordsDoNotMatch;
                      return null;
                    },
                  ),
                  const SizedBox(height: TdSpace.xl),
                  TdButton.primary(
                    label: l10n.register,
                    icon: Icons.person_add_alt_1_rounded,
                    size: TdButtonSize.large,
                    expanded: true,
                    loading: loading,
                    onPressed: loading ? null : _register,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
