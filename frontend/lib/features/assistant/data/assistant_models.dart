// Chat models for the AI farmer assistant.

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final ChatRole role;
  final String content;

  /// Wire format for `POST /api/chat`.
  Map<String, dynamic> toApiJson() => <String, dynamic>{
        'role': role == ChatRole.user ? 'user' : 'assistant',
        'content': content,
      };

  /// Local persistence format (kept richer than the wire format).
  Map<String, dynamic> toStorageJson() => <String, dynamic>{
        'role': role.name,
        'content': content,
      };

  factory ChatMessage.fromStorageJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] == 'assistant' ? ChatRole.assistant : ChatRole.user,
        content: json['content'] as String? ?? '',
      );
}
