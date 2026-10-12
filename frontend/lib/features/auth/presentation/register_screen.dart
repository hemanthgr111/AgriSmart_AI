import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_providers.dart';
import '../data/auth_service.dart';
import 'validators.dart';
import 'widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool configured = ref.watch(authConfiguredProvider);

    return AuthScaffold(
      title: l10n.createAccount,
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
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.fullName),
                validator: (String? value) => validateRequired(l10n, value),
                enabled: configured && !_busy,
              ),
              const SizedBox(height: 12),
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
                autofillHints: const <String>[AutofillHints.newPassword],
                decoration: InputDecoration(labelText: l10n.password),
                validator: (String? value) => validatePassword(l10n, value),
                enabled: configured && !_busy,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.confirmPassword),
                validator: (String? value) =>
                    validateConfirmPassword(l10n, value, _password.text),
                enabled: configured && !_busy,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: configured && !_busy ? _submit : null,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.createAccount),
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
          onPressed: configured && !_busy ? () => context.go(AppRoutes.login) : null,
          child: Text(l10n.haveAccountLogin),
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
      await ref.read(authServiceProvider).signUpWithPassword(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text.trim(),
          );
      if (mounted) {
        context.go(
          '${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(_email.text.trim())}',
        );
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
