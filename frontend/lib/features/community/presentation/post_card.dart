import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../data/community_models.dart';

/// A single post in a feed. Actions are optional so the same card can be
/// reused in read-only contexts.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    this.currentUserId,
    this.onOpen,
    this.onLike,
    this.onDelete,
    this.showActions = true,
  });

  final CommunityPost post;
  final String? currentUserId;
  final VoidCallback? onOpen;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isMine = post.isMine(currentUserId);
    final String time =
        DateFormat.yMMMd().add_jm().format(post.createdAt.toLocal());

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              leading: _Avatar(author: post.author),
              title: Text(
                post.author.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(time),
              trailing: isMine && onDelete != null
                  ? IconButton(
                      tooltip: l10n.deletePost,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(post.content),
            ),
            if (post.imageUrl != null)
              Image.network(
                post.imageUrl!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (BuildContext context, Object error,
                    StackTrace? stackTrace) {
                  return Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  );
                },
              ),
            if (showActions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: onLike,
                      icon: Icon(
                        post.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.likedByMe
                            ? Theme.of(context).colorScheme.error
                            : null,
                        size: 20,
                      ),
                      label: Text('${post.likeCount}'),
                    ),
                    if (onOpen != null)
                      TextButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(
                          Icons.mode_comment_outlined,
                          size: 20,
                        ),
                        label: Text(l10n.commentsTitle),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.author});

  final CommunityAuthor author;

  @override
  Widget build(BuildContext context) {
    final String? url = author.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      child: Text(
        author.initials,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
