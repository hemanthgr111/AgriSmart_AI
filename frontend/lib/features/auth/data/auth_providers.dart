import 'package:flutter_riverpod/flutter_riverpod.dart';

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
