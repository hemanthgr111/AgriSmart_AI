import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_providers.dart';
import '../data/auth_service.dart';
import 'widgets.dart';

/// Shown after registration when email confirmation is enabled in Supabase.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool configured = ref.watch(authConfiguredProvider);

    return AuthScaffold(
      title: l10n.emailVerificationTitle,
      subtitle: l10n.emailVerificationBody,
      children: <Widget>[
        if (widget.email != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.email!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        FilledButton(
          onPressed: configured && !_busy && widget.email != null
              ? _resend
              : null,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.resendEmail),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => context.go(AppRoutes.login),
          child: Text(l10n.haveAccountLogin),
        ),
      ],
    );
  }

  Future<void> _resend() async {
    final String? email = widget.email;
    if (email == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).resendVerificationEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).checkYourEmail)),
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
}
