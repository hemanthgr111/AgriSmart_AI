import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_providers.dart';
import '../data/community_models.dart';
import '../data/community_providers.dart';
import '../data/community_repository.dart';
import 'post_card.dart';

/// The farmer community feed.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (!ref.watch(communityConfiguredProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.communityTitle)),
        body: _InfoState(
          icon: Icons.groups_outlined,
          message: l10n.communityNotConfigured,
        ),
      );
    }

    final AsyncValue<List<CommunityPost>> feed = ref.watch(feedProvider);
    final String? userId = ref.watch(authStateProvider).value?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.communityTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(feedProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.communityNew),
        icon: const Icon(Icons.add),
        label: Text(l10n.createPost),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedProvider),
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => _ErrorState(
            message: l10n.communityLoadFailed,
            detail: error.toString(),
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(feedProvider),
          ),
          data: (List<CommunityPost> posts) {
            if (posts.isEmpty) {
              return _InfoState(
                icon: Icons.forum_outlined,
                message: l10n.noPosts,
                scrollable: true,
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 6, bottom: 96),
              itemCount: posts.length,
              itemBuilder: (BuildContext context, int index) {
                final CommunityPost post = posts[index];
                return CommunityPostCard(
                  post: post,
                  currentUserId: userId,
                  onOpen: () => context.go(
                    AppRoutes.communityPostPath(post.id),
                  ),
                  onLike: () => _toggleLike(context, ref, post),
                  onDelete: post.isMine(userId)
                      ? () => _confirmDelete(context, ref, post)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleLike(
    BuildContext context,
    WidgetRef ref,
    CommunityPost post,
  ) async {
    try {
      await ref
          .read(communityRepositoryProvider)
          .setLiked(post.id, !post.likedByMe);
      ref.invalidate(feedProvider);
    } on CommunityFailure catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CommunityPost post,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.deletePost),
        content: Text(l10n.deleteConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(communityRepositoryProvider).deletePost(post);
      ref.invalidate(feedProvider);
      if (context.mounted) {
        _showMessage(context, l10n.postDeleted);
      }
    } on CommunityFailure catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message);
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.icon,
    required this.message,
    this.scrollable = false,
  });

  final IconData icon;
  final String message;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
    if (!scrollable) {
      return Center(child: content);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[content],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 48),
        Icon(
          Icons.cloud_off,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryLabel),
          ),
        ),
      ],
    );
  }
}
