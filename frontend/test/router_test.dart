import 'dart:convert';

import 'package:agrismart_app/app.dart';
import 'package:agrismart_app/core/network/api_client.dart';
import 'package:agrismart_app/core/providers/shared_preferences_provider.dart';
import 'package:agrismart_app/features/auth/data/app_user.dart';
import 'package:agrismart_app/features/auth/data/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Client _healthyBackend() {
  return MockClient((http.Request request) async {
    return http.Response(
      jsonEncode(<String, dynamic>{
        'status': 'ok',
        'app': 'AgriSmart AI',
        'version': '0.1.0',
        'environment': 'test',
        'database': 'unavailable',
        'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
      }),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });
}

Future<SharedPreferences> _onboardedPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'onboarding_completed': true,
    'selected_language_code': 'en',
  });
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets(
      'Signed-out users are redirected to the login screen when auth is configured',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await _onboardedPrefs();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(ApiClient(client: _healthyBackend())),
          authConfiguredProvider.overrideWithValue(true),
          authStateProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(null),
          ),
        ],
        child: const AgriSmartApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Welcome, farmer'), findsNothing);
  });

  testWidgets(
      'Signed-in users stay on the home screen when auth is configured',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await _onboardedPrefs();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(ApiClient(client: _healthyBackend())),
          authConfiguredProvider.overrideWithValue(true),
          authStateProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(
              const AppUser(id: 'me', fullName: 'Me'),
            ),
          ),
        ],
        child: const AgriSmartApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });
}
