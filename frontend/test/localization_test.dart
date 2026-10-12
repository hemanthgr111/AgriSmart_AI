import 'package:agrismart_app/core/localization/locale_controller.dart';
import 'package:agrismart_app/core/providers/shared_preferences_provider.dart';
import 'package:agrismart_app/features/onboarding/data/onboarding_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('LocaleController restores the persisted language', () async {
    final SharedPreferences prefs =
        await _prefsWith(<String, Object>{'selected_language_code': 'ta'});
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(localeControllerProvider), const Locale('ta'));
  });

  test('LocaleController persists and clears the language', () async {
    final SharedPreferences prefs = await _prefsWith(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(localeControllerProvider), isNull);

    await container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('hi'));
    expect(container.read(localeControllerProvider), const Locale('hi'));
    expect(prefs.getString('selected_language_code'), 'hi');

    await container.read(localeControllerProvider.notifier).setLocale(null);
    expect(container.read(localeControllerProvider), isNull);
    expect(prefs.getString('selected_language_code'), isNull);
  });

  test('OnboardingController completes and persists the flag', () async {
    final SharedPreferences prefs = await _prefsWith(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(onboardingCompletedProvider), isFalse);

    await container.read(onboardingCompletedProvider.notifier).complete();
    expect(container.read(onboardingCompletedProvider), isTrue);
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });
}
