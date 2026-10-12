import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/data/app_user.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _name = TextEditingController();
  bool _initialised = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppUser? user = ref.watch(authStateProvider).value;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profile)),
        body: Center(child: Text(l10n.authNotConfigured)),
      );
    }

    if (!_initialised) {
      _name.text = user.fullName ?? '';
      _initialised = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ListTile(
            leading: CircleAvatar(
              child: Text(user.displayName.characters.first.toUpperCase()),
            ),
            title: Text(user.displayName),
            subtitle: Text(user.email ?? ''),
          ),
          if (user.emailVerified)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                avatar: const Icon(Icons.verified, size: 18),
                label: const Text('Verified'),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.fullName),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.saveProfile),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).updateFullName(_name.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
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
