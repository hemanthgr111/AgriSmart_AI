import 'dart:convert';

import 'package:agrismart_app/app.dart';
import 'package:agrismart_app/core/network/api_client.dart';
import 'package:agrismart_app/core/providers/shared_preferences_provider.dart';
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

Future<SharedPreferences> _prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets('Home renders in English and shows backend health',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await _prefsWith(<String, Object>{
      'onboarding_completed': true,
      'selected_language_code': 'en',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(ApiClient(client: _healthyBackend())),
        ],
        child: const AgriSmartApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome, farmer'), findsOneWidget);
    expect(find.textContaining('Backend: ok'), findsOneWidget);
  });

  testWidgets('Interface localizes to Hindi', (WidgetTester tester) async {
    final SharedPreferences prefs = await _prefsWith(<String, Object>{
      'onboarding_completed': true,
      'selected_language_code': 'hi',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(ApiClient(client: _healthyBackend())),
        ],
        child: const AgriSmartApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('स्वागत है, किसान'), findsOneWidget);
  });

  testWidgets('Onboarding is shown when not completed',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await _prefsWith(<String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(ApiClient(client: _healthyBackend())),
        ],
        child: const AgriSmartApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
  });
}
