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
import '../../widgets/auth/forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    context.read<AuthBloc>().add(
      AuthLoginRequested(email: _email.text.trim(), password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/');
        } else if (state is AuthFailure) {
          setState(() => _loading = false);
        }
      },
      child: AuthScaffold(
        title: l10n.welcomeBack,
        subtitle: l10n.loginSubtitle,
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.noAccountYet, style: context.text.bodyMedium),
            TextButton(
              onPressed: _loading ? null : () => context.go('/register'),
              child: Text(l10n.register),
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
                  controller: _email,
                  label: l10n.email,
                  hint: l10n.emailHint,
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  enabled: !_loading,
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
                  hint: l10n.passwordHint,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  showPasswordLabel: l10n.showPassword,
                  hidePasswordLabel: l10n.hidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_loading,
                  onSubmitted: (_) => _login(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.passwordRequired;
                    if (v.length < 6) return l10n.passwordMinLength;
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => ForgotPasswordDialog.show(
                            context,
                            initialEmail: _email.text.trim(),
                          ),
                    child: Text(l10n.forgotPassword),
                  ),
                ),
                const SizedBox(height: TdSpace.sm),
                TdButton.primary(
                  label: l10n.login,
                  icon: Icons.arrow_forward_rounded,
                  size: TdButtonSize.large,
                  expanded: true,
                  loading: _loading,
                  onPressed: _loading ? null : _login,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
