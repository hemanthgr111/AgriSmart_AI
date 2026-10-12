import 'dart:convert';

import 'package:agrismart_app/core/network/api_client.dart';
import 'package:agrismart_app/features/weather/presentation/weather_screen.dart';
import 'package:agrismart_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Weather screen shows current conditions for a search',
      (WidgetTester tester) async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'location': <String, dynamic>{
            'name': 'Mumbai',
            'region': 'Maharashtra',
            'country': 'India',
          },
          'current': <String, dynamic>{
            'temp_c': 30.0,
            'feelslike_c': 33.0,
            'humidity': 60,
            'wind_kph': 12.0,
            'wind_dir': 'W',
            'condition': 'Sunny',
          },
          'forecast': <dynamic>[
            <String, dynamic>{
              'date': '2026-01-01',
              'max_temp_c': 32.0,
              'min_temp_c': 20.0,
              'chance_of_rain': 10,
              'condition': 'Sunny',
            },
          ],
          'updated_at': DateTime.utc(2026, 1, 1, 10).toIso8601String(),
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(client: client)),
        ],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: WeatherScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Mumbai');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('30°C'), findsOneWidget);
    expect(find.text('Sunny'), findsWidgets);
    expect(find.text('Mumbai, Maharashtra, India'), findsOneWidget);
  });
}
