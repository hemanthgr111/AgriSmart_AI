import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_providers.dart';
import '../data/auth_service.dart';
import 'validators.dart';
import 'widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool configured = ref.watch(authConfiguredProvider);

    return AuthScaffold(
      title: l10n.signIn,
      subtitle: l10n.appTagline,
      children: <Widget>[
        if (!configured) ...<Widget>[
          AuthNotConfiguredBanner(
            title: l10n.authNotConfigured,
            body: l10n.authNotConfiguredBody,
          ),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                decoration: InputDecoration(labelText: l10n.email),
                validator: (String? value) => validateEmail(l10n, value),
                enabled: configured && !_busy,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const <String>[AutofillHints.password],
                decoration: InputDecoration(labelText: l10n.password),
                validator: (String? value) => (value == null || value.isEmpty)
                    ? l10n.fieldRequired
                    : null,
                enabled: configured && !_busy,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: configured
                      ? () => context.go(AppRoutes.forgotPassword)
                      : null,
                  child: Text(l10n.forgotPassword),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: configured && !_busy ? _submit : null,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.signIn),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: configured && !_busy ? _googleSignIn : null,
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: Text(l10n.signInWithGoogle),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              configured && !_busy ? () => context.go(AppRoutes.register) : null,
          child: Text(l10n.noAccountRegister),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      // Router redirect handles navigation after the auth stream updates.
    } on AuthFailure catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } on AuthFailure catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
