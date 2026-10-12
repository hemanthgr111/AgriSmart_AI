import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'assistant_models.dart';

/// Sends a conversation to the backend assistant and returns the reply text.
class AssistantRepository {
  AssistantRepository(this._client);

  final ApiClient _client;

  Future<String> send({
    required List<ChatMessage> messages,
    String? locale,
  }) async {
    final Map<String, dynamic> json = await _client.postJson(
      '/api/chat',
      body: <String, dynamic>{
        'messages': messages.map((ChatMessage m) => m.toApiJson()).toList(),
        'locale': ?locale,
      },
    );
    return json['reply'] as String? ?? '';
  }
}

final Provider<AssistantRepository> assistantRepositoryProvider =
    Provider<AssistantRepository>(
  (ref) => AssistantRepository(ref.watch(apiClientProvider)),
);
