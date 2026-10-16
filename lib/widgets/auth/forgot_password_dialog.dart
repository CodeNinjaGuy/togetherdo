/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../../repositories/auth_repository.dart';

/// „Passwort vergessen“: schickt den Firebase-Link zum Zurücksetzen.
/// Als Sheet (Handy) bzw. Dialog (iPad/Mac) über [show].
///
/// Die Rückmeldung verrät bewusst nicht, ob es zur Adresse ein Konto gibt.
class ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordDialog({
    super.key,
    this.initialEmail = '',
    this.embedded = false,
  });

  static Future<void> show(BuildContext context, {String initialEmail = ''}) {
    final repo = context.read<AuthRepository>();
    return showTdSheet<void>(
      context,
      title: AppLocalizations.of(context)!.resetPasswordTitle,
      builder: (_) => RepositoryProvider.value(
        value: repo,
        child: ForgotPasswordDialog(initialEmail: initialEmail, embedded: true),
      ),
    );
  }

  /// Im Sheet trägt das Sheet den Titel.
  final bool embedded;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().sendPasswordResetEmail(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on InvalidEmailException {
      if (!mounted) return;
      setState(() => _error = l10n.invalidEmail);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.resetPasswordError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = AnimatedSwitcher(
      duration: TdMotion.of(context, TdMotion.base),
      child: _sent
          ? Column(
              key: const ValueKey('sent'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.mark_email_read_outlined, color: context.td.success),
                    const SizedBox(width: TdSpace.md),
                    Expanded(child: Text(l10n.resetPasswordSent)),
                  ],
                ),
                const SizedBox(height: TdSpace.xl),
                TdButton.secondary(
                  label: l10n.close,
                  expanded: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            )
          : KeyedSubtree(
              key: const ValueKey('form'),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.resetPasswordDescription),
                    const SizedBox(height: TdSpace.lg),
                    TdTextField(
                      controller: _emailController,
                      label: l10n.email,
                      hint: l10n.emailHint,
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autofocus: widget.initialEmail.isEmpty,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return l10n.emailRequired;
                        if (!v.contains('@')) return l10n.invalidEmail;
                        return null;
                      },
                      onSubmitted: (_) => _send(),
                    ),
                    TdReveal(
                      visible: _error != null,
                      child: Padding(
                        padding: const EdgeInsets.only(top: TdSpace.sm),
                        child: Text(
                          _error ?? '',
                          style: context.text.bodySmall?.copyWith(
                            color: context.td.danger,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: TdSpace.xl),
                    Row(
                      children: [
                        Expanded(
                          child: TdButton.secondary(
                            label: l10n.cancel,
                            onPressed: _sending
                                ? null
                                : () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        const SizedBox(width: TdSpace.md),
                        Expanded(
                          flex: 2,
                          child: TdButton.primary(
                            label: l10n.resetPasswordSend,
                            icon: Icons.send_rounded,
                            expanded: true,
                            loading: _sending,
                            onPressed: _sending ? null : _send,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
    if (widget.embedded) return body;
    return Padding(
      padding: const EdgeInsets.all(TdSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.resetPasswordTitle, style: context.text.headlineSmall),
          const SizedBox(height: TdSpace.lg),
          body,
        ],
      ),
    );
  }
}
