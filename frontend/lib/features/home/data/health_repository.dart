import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'health_status.dart';

/// Fetches backend health. Refreshing this provider re-checks connectivity.
///
/// In Riverpod 3.x providers are auto-dispose by default, so a refresh
/// (`ref.invalidate`) simply re-runs the request.
final FutureProvider<HealthStatus> healthProvider = FutureProvider<HealthStatus>(
  (ref) async {
    final ApiClient client = ref.watch(apiClientProvider);
    final Map<String, dynamic> json = await client.getJson('/api/health');
    return HealthStatus.fromJson(json);
  },
);
