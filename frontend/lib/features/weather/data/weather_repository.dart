import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'weather_models.dart';

/// Fetches weather for a specific query. Results are cached per query until
/// invalidated, matching the backend's short cache window.
final weatherProvider =
    FutureProvider.family<WeatherData, WeatherQuery>((ref, query) async {
  final ApiClient client = ref.watch(apiClientProvider);
  final Map<String, dynamic> json = await client.getJson(
    '/api/weather',
    queryParameters: query.toQueryParameters(),
  );
  return WeatherData.fromJson(json);
});
