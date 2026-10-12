import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
/// Tracks whether the user has completed the onboarding/language step.
class OnboardingController extends Notifier<bool> {
  static const String _key = 'onboarding_completed';

  @override
  bool build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, true);
    state = true;
  }
}

final NotifierProvider<OnboardingController, bool> onboardingCompletedProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
