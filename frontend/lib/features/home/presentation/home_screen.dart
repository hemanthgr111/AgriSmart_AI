import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/app_user.dart';
import '../../auth/data/auth_providers.dart';
import '../data/health_repository.dart';
import '../data/health_status.dart';

/// Home dashboard. Verifies backend connectivity; feature tiles arrive in
/// later phases.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<HealthStatus> health = ref.watch(healthProvider);
    final AppUser? user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => context.go(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(healthProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(healthProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _WelcomeHeader(
              greeting: user == null ? l10n.welcomeFarmer : user.displayName,
              tagline: l10n.homeTagline,
            ),
            const SizedBox(height: 16),
            health.when(
              data: (HealthStatus status) => _BackendStatusCard(
                status: status,
                l10n: l10n,
              ),
              loading: () => _StatusCardLoading(label: l10n.contactingBackend),
              error: (Object error, StackTrace _) => _BackendErrorCard(
                title: l10n.backendUnavailable,
                message: error.toString(),
                retryLabel: l10n.retry,
                onRetry: () => ref.invalidate(healthProvider),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.comingSoon, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ComingSoonList(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.greeting, required this.tagline});

  final String greeting;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(tagline, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _BackendStatusCard extends StatelessWidget {
  const _BackendStatusCard({required this.status, required this.l10n});

  final HealthStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool ok = status.isDatabaseConnected;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = ok ? scheme.primary : scheme.tertiary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  ok ? Icons.check_circle_outline : Icons.info_outline,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.backend}: ${status.status}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _KeyValueRow(label: l10n.version, value: status.version),
            _KeyValueRow(label: l10n.environment, value: status.environment),
            _KeyValueRow(label: l10n.database, value: status.database),
            if (!ok)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.databaseNotConfigured,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatusCardLoading extends StatelessWidget {
  const _StatusCardLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _BackendErrorCard extends StatelessWidget {
  const _BackendErrorCard({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.cloud_off, color: scheme.error),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonList extends StatelessWidget {
  const _ComingSoonList({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String, String?)> items =
        <(IconData, String, String?)>[
      (Icons.eco, l10n.featureCropDisease, AppRoutes.diagnosis),
      (Icons.wb_sunny, l10n.featureWeather, AppRoutes.weather),
      (Icons.chat, l10n.featureAssistant, AppRoutes.assistant),
      (Icons.groups, l10n.featureCommunity, AppRoutes.community),
    ];
    return Column(
      children: <Widget>[
        for (final (IconData icon, String label, String? route) in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(label),
            trailing: Icon(
              route == null ? Icons.schedule : Icons.chevron_right,
            ),
            onTap: route == null ? null : () => context.go(route),
          ),
      ],
    );
  }
}
