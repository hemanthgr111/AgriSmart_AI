/// Supabase configuration provided at build time via `--dart-define`.
///
/// Only the publishable/anonymous key belongs here. NEVER put a service-role
/// or secret key in the Flutter app.
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both values are supplied, enabling authentication features.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
