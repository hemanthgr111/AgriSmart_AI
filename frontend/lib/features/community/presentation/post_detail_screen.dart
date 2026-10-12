import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_providers.dart';
import '../data/community_models.dart';
import '../data/community_providers.dart';
import '../data/community_repository.dart';
import 'post_card.dart';

/// A single post with its comments.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_comment.text.trim().isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(communityRepositoryProvider).addComment(
            postId: widget.postId,
            content: _comment.text,
          );
      if (!mounted) {
        return;
      }
      _comment.clear();
      FocusScope.of(context).unfocus();
      ref.invalidate(commentsProvider(widget.postId));
    } on CommunityFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(l10n.commentFailed);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _toggleLike(CommunityPost post) async {
    try {
      await ref
          .read(communityRepositoryProvider)
          .setLiked(post.id, !post.likedByMe);
      ref.invalidate(postProvider(widget.postId));
    } on CommunityFailure catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? userId = ref.watch(authStateProvider).value?.id;
    final AsyncValue<CommunityPost> post =
        ref.watch(postProvider(widget.postId));
    final AsyncValue<List<CommunityComment>> comments =
        ref.watch(commentsProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.commentsTitle)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: post.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace _) => _ErrorCenter(
                message: l10n.communityLoadFailed,
                retryLabel: l10n.retry,
                onRetry: () => ref.invalidate(postProvider(widget.postId)),
              ),
              data: (CommunityPost value) => ListView(
                children: <Widget>[
                  CommunityPostCard(
                    post: value,
                    currentUserId: userId,
                    onLike: () => _toggleLike(value),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      l10n.commentsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  comments.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (Object error, StackTrace _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.communityLoadFailed,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    data: (List<CommunityComment> list) {
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.noComments,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                      return Column(
                        children: <Widget>[
                          for (final CommunityComment comment in list)
                            _CommentTile(comment: comment),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          _CommentComposer(
            controller: _comment,
            hint: l10n.commentHint,
            sendLabel: l10n.commentSend,
            enabled: !_sending,
            onSend: _sendComment,
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CommunityComment comment;

  @override
  Widget build(BuildContext context) {
    final String time =
        DateFormat.yMMMd().add_jm().format(comment.createdAt.toLocal());
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          comment.author.initials,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(comment.author.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(comment.content),
          const SizedBox(height: 2),
          Text(time, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: true,
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
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
      ),
    );
  }
}

class _ErrorCenter extends StatelessWidget {
  const _ErrorCenter({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.cloud_off,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}
