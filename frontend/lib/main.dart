import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/network/api_client.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'features/auth/data/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // Initialise Supabase only when credentials were provided. Without them the
  // app runs in guest mode so every other feature keeps working.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Authenticated backend calls use the Supabase session token. Without
        // credentials the provider stays null and the app runs in guest mode.
        if (SupabaseConfig.isConfigured)
          apiAccessTokenProvider.overrideWithValue(currentSupabaseAccessToken),
      ],
      child: const AgriSmartApp(),
    ),
  );
}
