import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../data/assistant_models.dart';
import '../data/chat_controller.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final String text = _input.text;
    if (text.trim().isEmpty) {
      return;
    }
    _input.clear();
    ref
        .read(chatControllerProvider.notifier)
        .send(text, locale: Localizations.localeOf(context).languageCode);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ChatState chat = ref.watch(chatControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistantTitle),
        actions: <Widget>[
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: l10n.assistantClear,
              onPressed: () => ref.read(chatControllerProvider.notifier).clear(),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: chat.messages.isEmpty
                  ? _Intro(
                      intro: l10n.assistantIntro,
                      disclaimer: l10n.assistantDisclaimer,
                      suggestions: <String>[
                        l10n.suggestion1,
                        l10n.suggestion2,
                        l10n.suggestion3,
                      ],
                      onSuggestion: (String value) {
                        ref
                            .read(chatControllerProvider.notifier)
                            .send(
                              value,
                              locale: Localizations.localeOf(context)
                                  .languageCode,
                            );
                        _scrollToEnd();
                      },
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: chat.messages.length +
                          (chat.isSending ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index >= chat.messages.length) {
                          return _ThinkingBubble(label: l10n.assistantThinking);
                        }
                        return _MessageBubble(message: chat.messages[index]);
                      },
                    ),
            ),
            if (chat.error != null)
              _ErrorBanner(
                message: chat.error == ChatError.notConfigured
                    ? l10n.assistantNotConfigured
                    : l10n.assistantError,
              ),
            _Composer(
              controller: _input,
              hint: l10n.assistantHint,
              sendLabel: l10n.assistantSend,
              enabled: !chat.isSending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.intro,
    required this.disclaimer,
    required this.suggestions,
    required this.onSuggestion,
  });

  final String intro;
  final String disclaimer;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Icon(
          Icons.support_agent,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          intro,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        for (final String suggestion in suggestions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ActionChip(
              avatar: const Icon(Icons.help_outline, size: 18),
              label: Text(suggestion),
              onPressed: () => onSuggestion(suggestion),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          disclaimer,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == ChatRole.user;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isUser
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.sendLabel,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final String sendLabel;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: sendLabel,
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
