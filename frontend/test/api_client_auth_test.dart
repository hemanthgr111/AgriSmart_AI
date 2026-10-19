import 'dart:convert';

import 'package:agrismart_app/core/network/api_client.dart';
import 'package:agrismart_app/features/auth/data/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _baseUrl = 'http://test.local';

http.Response _ok(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  group('ApiClient authorization header', () {
    test('attaches a bearer token to POST when a session is available',
        () async {
      String? seen;
      final MockClient client = MockClient((http.Request request) async {
        seen = request.headers['authorization'];
        return _ok(<String, dynamic>{'reply': 'ok'});
      });
      final ApiClient api = ApiClient(
        client: client,
        baseUrl: _baseUrl,
        accessTokenProvider: () async => 'token-123',
      );

      await api.postJson('/api/chat', body: <String, dynamic>{'messages': []});

      expect(seen, 'Bearer token-123');
    });

    test('attaches a bearer token to GET when a session is available', () async {
      String? seen;
      final MockClient client = MockClient((http.Request request) async {
        seen = request.headers['authorization'];
        return _ok(<String, dynamic>{'current': <String, dynamic>{}});
      });
      final ApiClient api = ApiClient(
        client: client,
        baseUrl: _baseUrl,
        accessTokenProvider: () async => 'token-123',
      );

      await api.getJson('/api/weather');

      expect(seen, 'Bearer token-123');
    });

    test('attaches a bearer token to multipart uploads', () async {
      String? seen;
      final MockClient client = MockClient((http.Request request) async {
        seen = request.headers['authorization'];
        return _ok(<String, dynamic>{'crop': 'Tomato'});
      });
      final ApiClient api = ApiClient(
        client: client,
        baseUrl: _baseUrl,
        accessTokenProvider: () async => 'token-xyz',
      );

      await api.postMultipart(
        '/api/diagnose',
        field: 'file',
        fileBytes: <int>[1, 2, 3, 4],
        filename: 'leaf.png',
      );

      expect(seen, 'Bearer token-xyz');
    });

    test('omits the header when there is no session (guest mode)', () async {
      String? seen = 'sentinel';
      final MockClient client = MockClient((http.Request request) async {
        seen = request.headers['authorization'];
        return _ok(<String, dynamic>{'reply': 'ok'});
      });
      final ApiClient api = ApiClient(
        client: client,
        baseUrl: _baseUrl,
        accessTokenProvider: () async => null,
      );

      await api.postJson('/api/chat', body: <String, dynamic>{'messages': []});

      expect(seen, isNull);
    });

    test('omits the header when the provider throws (expired/unavailable)',
        () async {
      String? seen = 'sentinel';
      final MockClient client = MockClient((http.Request request) async {
        seen = request.headers['authorization'];
        return _ok(<String, dynamic>{'reply': 'ok'});
      });
      final ApiClient api = ApiClient(
        client: client,
        baseUrl: _baseUrl,
        accessTokenProvider: () async => throw Exception('session expired'),
      );

      await api.postJson('/api/chat', body: <String, dynamic>{'messages': []});

      expect(seen, isNull);
    });

    test('omits the header when no provider is configured (default)', () async {
      String? seen = 'sentinel';
      final MockClient client = MockClient((http.Request request) async {
        seen = request.headers['authorization'];
        return _ok(<String, dynamic>{'reply': 'ok'});
      });
      final ApiClient api = ApiClient(client: client, baseUrl: _baseUrl);

      await api.postJson('/api/chat', body: <String, dynamic>{'messages': []});

      expect(seen, isNull);
    });

    test('surfaces the server error detail on a 401 (expired session)',
        () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'detail': 'Session expired. Please sign in again.',
          }),
          401,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final ApiClient api = ApiClient(
        client: client,
        baseUrl: _baseUrl,
        accessTokenProvider: () async => 'stale-token',
      );

      expect(
        () => api.postJson('/api/chat', body: <String, dynamic>{'messages': []}),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 401)
              .having((ApiException e) => e.message, 'message',
                  'Session expired. Please sign in again.'),
        ),
      );
    });
  });

  group('currentSupabaseAccessToken', () {
    test('returns null when Supabase is not configured (guest mode)', () async {
      // Tests run without --dart-define Supabase credentials, so auth is off.
      expect(await currentSupabaseAccessToken(), isNull);
    });
  });
}
