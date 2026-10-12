import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_providers.dart';
import '../data/auth_service.dart';
import 'validators.dart';
import 'widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool configured = ref.watch(authConfiguredProvider);

    return AuthScaffold(
      title: l10n.resetPassword,
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
                decoration: InputDecoration(labelText: l10n.email),
                validator: (String? value) => validateEmail(l10n, value),
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
                    : Text(l10n.sendResetLink),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => context.go(AppRoutes.login),
                child: Text(l10n.haveAccountLogin),
              ),
            ],
          ),
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
      await ref
          .read(authServiceProvider)
          .sendPasswordReset(_email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).checkYourEmail)));
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
}
