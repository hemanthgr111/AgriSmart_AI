import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import 'assistant_models.dart';
import 'assistant_repository.dart';

/// Why the last request failed, mapped to localized text in the UI.
enum ChatError { failed, notConfigured }

class ChatState {
  const ChatState({
    this.messages = const <ChatMessage>[],
    this.isSending = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final ChatError? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    ChatError? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Holds the assistant conversation and persists it locally so it survives
/// restarts. History is kept on-device only; nothing is written server-side.
class ChatController extends Notifier<ChatState> {
  static const String _key = 'assistant_chat_history';
  static const int _maxStored = 100;
  static const int _maxRequestMessages = 12;

  @override
  ChatState build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    final List<String> stored = prefs.getStringList(_key) ?? <String>[];
    final List<ChatMessage> messages = <ChatMessage>[];
    for (final String entry in stored) {
      try {
        messages.add(
          ChatMessage.fromStorageJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } on FormatException {
        // Skip corrupt entries rather than failing startup.
      }
    }
    return ChatState(messages: messages);
  }

  Future<void> send(String text, {String? locale}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) {
      return;
    }
    final ChatMessage userMessage =
        ChatMessage(role: ChatRole.user, content: trimmed);
    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, userMessage],
      isSending: true,
      clearError: true,
    );
    await _persist();

    try {
      final List<ChatMessage> request = _recent(state.messages);
      final String reply = await ref
          .read(assistantRepositoryProvider)
          .send(messages: request, locale: locale);
      if (reply.trim().isEmpty) {
        state = state.copyWith(isSending: false, error: ChatError.failed);
        return;
      }
      state = state.copyWith(
        messages: <ChatMessage>[
          ...state.messages,
          ChatMessage(role: ChatRole.assistant, content: reply),
        ],
        isSending: false,
      );
      await _persist();
    } on ApiException catch (error) {
      state = state.copyWith(
        isSending: false,
        error: error.statusCode == 503 ? ChatError.notConfigured : ChatError.failed,
      );
    } catch (_) {
      state = state.copyWith(isSending: false, error: ChatError.failed);
    }
  }

  Future<void> clear() async {
    state = const ChatState();
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_key);
  }

  List<ChatMessage> _recent(List<ChatMessage> messages) {
    if (messages.length <= _maxRequestMessages) {
      return messages;
    }
    return messages.sublist(messages.length - _maxRequestMessages);
  }

  Future<void> _persist() async {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    final List<ChatMessage> trimmed = state.messages.length > _maxStored
        ? state.messages.sublist(state.messages.length - _maxStored)
        : state.messages;
    await prefs.setStringList(
      _key,
      trimmed
          .map((ChatMessage m) => jsonEncode(m.toStorageJson()))
          .toList(growable: false),
    );
  }
}

final NotifierProvider<ChatController, ChatState> chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
