import 'package:agrismart_app/core/network/api_client.dart';
import 'package:agrismart_app/core/providers/shared_preferences_provider.dart';
import 'package:agrismart_app/features/assistant/data/assistant_models.dart';
import 'package:agrismart_app/features/assistant/data/assistant_repository.dart';
import 'package:agrismart_app/features/assistant/presentation/assistant_screen.dart';
import 'package:agrismart_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository extends AssistantRepository {
  _FakeRepository() : super(ApiClient());

  @override
  Future<String> send({
    required List<ChatMessage> messages,
    String? locale,
  }) async {
    return 'Use neem oil spray twice a week.';
  }
}

void main() {
  testWidgets('Assistant sends a message and shows the reply',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          assistantRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AssistantScreen(),
        ),
      ),
    );

    expect(
      find.text('Ask me anything about your crops, soil, pests, or weather.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'How do I treat aphids?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('How do I treat aphids?'), findsOneWidget);
    expect(find.text('Use neem oil spray twice a week.'), findsOneWidget);
  });
}
