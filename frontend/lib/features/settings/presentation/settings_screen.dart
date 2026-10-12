import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/supported_languages.dart';
import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/app_user.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Locale? current = ref.watch(localeControllerProvider);
    final AsyncValue<AppUser?> auth = ref.watch(authStateProvider);
    final AppUser? user = auth.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: <Widget>[
          _SectionHeader(title: l10n.account),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.profile),
              subtitle: Text(user.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.profile),
            )
          else
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l10n.login),
              onTap: () => context.go(AppRoutes.login),
            ),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.logout),
              onTap: () => _confirmLogout(context, ref, l10n),
            ),
          const Divider(),
          _SectionHeader(title: l10n.language),
          RadioGroup<String?>(
            groupValue: current?.languageCode,
            onChanged: (String? value) => ref
                .read(localeControllerProvider.notifier)
                .setLocale(value == null ? null : Locale(value)),
            child: Column(
              children: <Widget>[
                RadioListTile<String?>(
                  value: null,
                  title: Text(l10n.languageSystem),
                ),
                for (final AppLanguage language in kSupportedLanguages)
                  RadioListTile<String?>(
                    value: language.code,
                    title: Text(language.nativeName),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: Text(l10n.logout),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    try {
      await ref.read(authServiceProvider).signOut();
    } on AuthFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
