/// A post author, resolved from the `profiles` table.
class CommunityAuthor {
  const CommunityAuthor({
    required this.id,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String? fullName;
  final String? avatarUrl;

  String get displayName {
    final String? name = fullName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Farmer';
  }

  String get initials {
    final String name = displayName.trim();
    if (name.isEmpty) {
      return '?';
    }
    final List<String> parts =
        name.split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory CommunityAuthor.fromJson(Map<String, dynamic> json) {
    return CommunityAuthor(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

/// A community post.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.author,
    this.userId,
    this.imageUrl,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final CommunityAuthor author;
  final String? userId;
  final String? imageUrl;
  final int likeCount;
  final bool likedByMe;

  /// True when the signed-in user owns this post.
  bool isMine(String? currentUserId) =>
      currentUserId != null &&
      ((userId != null && userId == currentUserId) ||
          author.id == currentUserId);

  /// Builds a post from a PostgREST row with likes relation.
  factory CommunityPost.fromJson(
    Map<String, dynamic> json, {
    required String? imageUrl,
    String? currentUserId,
    CommunityAuthor? author,
  }) {
    final List<dynamic> likes =
        (json['likes'] as List<dynamic>?) ??
            (json['post_likes'] as List<dynamic>?) ??
            const <dynamic>[];
    final bool likedByMe = currentUserId != null &&
        likes.any((dynamic l) =>
            l is Map && (l['user_id'] as String?) == currentUserId);
    final String? postUserId = json['user_id'] as String? ??
        json['author_id'] as String?;
    final CommunityAuthor resolvedAuthor = author ??
        CommunityAuthor.fromJson(
          (json['author'] as Map<String, dynamic>?) ??
              const <String, dynamic>{},
        );
    return CommunityPost(
      id: json['id'] as String? ?? '',
      content: (json['content'] as String?) ?? '',
      createdAt: _parseDate(json['created_at']),
      author: resolvedAuthor,
      userId: postUserId,
      imageUrl: imageUrl,
      likeCount: likes.length,
      likedByMe: likedByMe,
    );
  }
}

/// A comment on a post.
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.author,
    this.userId,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final CommunityAuthor author;
  final String? userId;

  bool isMine(String? currentUserId) =>
      currentUserId != null &&
      ((userId != null && userId == currentUserId) ||
          author.id == currentUserId);

  factory CommunityComment.fromJson(
    Map<String, dynamic> json, {
    CommunityAuthor? author,
  }) {
    final String? commentUserId =
        json['user_id'] as String? ?? json['author_id'] as String?;
    final CommunityAuthor resolvedAuthor = author ??
        CommunityAuthor.fromJson(
          (json['author'] as Map<String, dynamic>?) ??
              const <String, dynamic>{},
        );
    return CommunityComment(
      id: json['id'] as String? ?? '',
      content: (json['content'] as String?) ?? '',
      createdAt: _parseDate(json['created_at']),
      author: resolvedAuthor,
      userId: commentUserId,
    );
  }
}

DateTime _parseDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}
