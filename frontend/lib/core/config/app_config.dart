/// Compile-time application configuration.
///
/// Values are provided with `--dart-define` so no secrets are ever committed.
/// The default points at a local backend. For the Android emulator use:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
class AppConfig {
  const AppConfig._();

  static const String appName = 'AgriSmart AI';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
