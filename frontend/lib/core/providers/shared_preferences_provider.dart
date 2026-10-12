import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` after loading SharedPreferences.
///
/// Kept as a provider so it can be swapped in tests.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});
