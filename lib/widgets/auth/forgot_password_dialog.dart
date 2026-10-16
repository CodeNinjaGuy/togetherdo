/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../repositories/auth_repository.dart';

/// Dialog „Passwort vergessen“: schickt den Firebase-Link zum Zurücksetzen.
///
/// Die Rückmeldung verrät bewusst nicht, ob es zur Adresse ein Konto gibt.
class ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordDialog({super.key, this.initialEmail = ''});

  static Future<void> show(BuildContext context, {String initialEmail = ''}) {
    return showDialog<void>(
      context: context,
      builder: (_) => ForgotPasswordDialog(initialEmail: initialEmail),
    );
  }

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
    return AlertDialog(
      title: Text(l10n.resetPasswordTitle),
      content: _sent
          ? Text(l10n.resetPasswordSent)
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.resetPasswordDescription),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      hintText: l10n.emailHint,
                      errorText: _error,
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return l10n.emailRequired;
                      if (!v.contains('@')) return l10n.invalidEmail;
                      return null;
                    },
                    onFieldSubmitted: (_) => _send(),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(_sent ? l10n.close : l10n.cancel),
        ),
        if (!_sent)
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.resetPasswordSend),
          ),
      ],
    );
  }
}
