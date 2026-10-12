import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/shared_preferences_provider.dart';

/// Persists and exposes the user's language choice.
///
/// A `null` state means "follow the system language".
class LocaleController extends Notifier<Locale?> {
  static const String _key = 'selected_language_code';

  @override
  Locale? build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    final String? code = prefs.getString(_key);
    if (code == null || code.isEmpty) {
      return null;
    }
    return Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = locale;
  }
}

final NotifierProvider<LocaleController, Locale?> localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
