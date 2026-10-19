import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/supabase_config.dart';
import 'app_user.dart';
import 'auth_service.dart';

/// Whether Supabase auth credentials were supplied at build time.
final Provider<bool> authConfiguredProvider = Provider<bool>((ref) {
  return SupabaseConfig.isConfigured;
});

/// Available only when auth is configured. Reading it otherwise throws.
final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) {
  if (!SupabaseConfig.isConfigured) {
    throw StateError('Supabase is not configured.');
  }
  return AuthService();
});

/// Emits the current user (or null) and updates on auth state changes.
///
/// When auth is not configured this emits a single `null`, so the rest of the
/// app can run in guest mode without crashing.
final StreamProvider<AppUser?> authStateProvider = StreamProvider<AppUser?>(
  (ref) {
    if (!SupabaseConfig.isConfigured) {
      return Stream<AppUser?>.value(null);
    }
    final AuthService service = ref.watch(authServiceProvider);
    return service.authStateChanges();
  },
);

/// Returns the current Supabase access token, or `null` when unavailable.
///
/// Uses `getSession()`, which refreshes an expired token on demand and returns
/// `null` when there is no session. Any auth/network failure is swallowed so a
/// stale session never breaks a request: the caller simply sends no token and
/// is treated as an anonymous (guest) caller. When Supabase is not configured
/// this returns `null`, preserving guest mode.
Future<String?> currentSupabaseAccessToken() async {
  if (!SupabaseConfig.isConfigured) {
    return null;
  }
  try {
    final sb.Session? session =
        await sb.Supabase.instance.client.auth.getSession();
    return session?.accessToken;
  } on Exception {
    return null;
  }
}
