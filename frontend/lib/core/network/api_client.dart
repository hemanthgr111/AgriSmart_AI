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

/// Thin HTTP client for the FastAPI backend.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final Uri uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParameters);
    try {
      final http.Response response = await _client.get(uri).timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(
        'Request failed with status ${response.statusCode}.',
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
            headers: <String, String>{'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(
        _detailFromBody(response.body) ??
            'Request failed with status ${response.statusCode}.',
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
        ..files.add(
          http.MultipartFile.fromBytes(field, fileBytes, filename: filename),
        );
      final http.StreamedResponse streamed =
          await request.send().timeout(timeout);
      final http.Response response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(
        _detailFromBody(response.body) ??
            'Request failed with status ${response.statusCode}.',
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

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final ApiClient client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});
