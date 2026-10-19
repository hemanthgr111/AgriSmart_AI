import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Error type for failed API calls, safe to show to users.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Supplies the current access token, or `null` when unauthenticated.
///
/// Kept as a plain callback so [ApiClient] stays decoupled from Supabase and is
/// trivial to fake in tests.
typedef AccessTokenProvider = Future<String?> Function();

/// Thin HTTP client for the FastAPI backend.
class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    this.accessTokenProvider,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Supplies the token attached as `Authorization: Bearer <token>`; when null
  /// (default) or when it yields no token, requests are sent anonymously.
  final AccessTokenProvider? accessTokenProvider;

  /// Builds request headers, attaching `Authorization: Bearer <token>` only
  /// when a token is available. A missing or expired session simply omits the
  /// header so the request falls back to anonymous (guest) access.
  Future<Map<String, String>> _headers({bool json = false}) async {
    final Map<String, String> headers = <String, String>{};
    if (json) {
      headers['content-type'] = 'application/json';
    }
    final String? token = await _currentAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Reads the access token defensively: any provider failure (expired or
  /// unavailable session) yields `null` rather than breaking the request.
  Future<String?> _currentAccessToken() async {
    final AccessTokenProvider? provider = accessTokenProvider;
    if (provider == null) {
      return null;
    }
    try {
      return await provider();
    } on Exception {
      return null;
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final Uri uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParameters);
    try {
      final http.Response response =
          await _client.get(uri, headers: await _headers()).timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(
        _errorMessage(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } on Exception {
      throw ApiException('Could not reach the server. Check your connection.');
    }
  }

  void dispose() => _client.close();

  /// Sends a JSON body and decodes a JSON response.
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final Uri uri = Uri.parse('$_baseUrl$path');
    try {
      final http.Response response = await _client
          .post(
            uri,
            headers: await _headers(json: true),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(
        _errorMessage(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } on Exception {
      throw ApiException('Could not reach the server. Check your connection.');
    }
  }

  /// Uploads a single file as multipart/form-data and decodes a JSON result.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String field,
    required List<int> fileBytes,
    required String filename,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final Uri uri = Uri.parse('$_baseUrl$path');
    try {
      final http.MultipartRequest request = http.MultipartRequest('POST', uri)
        ..headers.addAll(await _headers())
        ..files.add(
          http.MultipartFile.fromBytes(field, fileBytes, filename: filename),
        );
      final http.StreamedResponse streamed =
          await _client.send(request).timeout(timeout);
      final http.Response response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(
        _errorMessage(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } on Exception {
      throw ApiException('Could not reach the server. Check your connection.');
    }
  }

  String _errorMessage(int statusCode, String body) {
    return _detailFromBody(body) ?? 'Request failed with status $statusCode.';
  }

  String? _detailFromBody(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

/// Supplies the access token for authenticated backend calls.
///
/// Defaults to `null` (guest/offline). `main.dart` overrides it with the
/// Supabase session token when auth is configured at build time.
final Provider<AccessTokenProvider?> apiAccessTokenProvider =
    Provider<AccessTokenProvider?>((ref) => null);

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final ApiClient client = ApiClient(
    accessTokenProvider: ref.watch(apiAccessTokenProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});
