import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException, StorageException, SupabaseClient;

import '../../../../core/config/supabase_config.dart';
import 'community_models.dart';

/// Error surfaced to the UI. Never contains secrets.
class CommunityFailure implements Exception {
  CommunityFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Community data access backed by Supabase (Postgres + Storage).
///
/// Access control is enforced server-side by row level security policies; the
/// client only ever uses the anonymous key. Only instantiate this when
/// Supabase is configured.
class CommunityRepository {
  CommunityRepository({SupabaseClient? client})
      : _injectedClient = client;

  static const String _bucket = 'community-media';

  static const String _postColumns =
      'id, user_id, content, media_url, media_type, created_at, '
      'likes(user_id)';

  final SupabaseClient? _injectedClient;

  // Resolved lazily so subclasses (e.g. test fakes) can construct without a
  // live Supabase instance.
  SupabaseClient get _client => _injectedClient ?? sb.Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  bool get isSignedIn => currentUserId != null;

  String? _mediaUrl(String? mediaUrl) {
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return null;
    }
    final String value = mediaUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      // Only use clearly identified HTTP(S) URLs as-is for display
      final Uri? uri = Uri.tryParse(value);
      if (uri == null) {
        return null;
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }
      if (uri.host.isEmpty) {
        return null;
      }
      return uri.toString();
    }
    // Do not automatically treat non-URL strings as Storage object paths
    // Only accept if it matches a strict, documented path format (handled elsewhere)
    return null;
  }

  Future<Map<String, CommunityAuthor>> _fetchAuthorsByIds(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return const <String, CommunityAuthor>{};
    }
    try {
      final List<dynamic> rows = await _client
          .from('profiles')
          .select('id, full_name, avatar_url, username')
          .inFilter('id', userIds.toList());
      final Map<String, CommunityAuthor> authors =
          <String, CommunityAuthor>{};
      for (final dynamic row in rows) {
        if (row is Map<String, dynamic>) {
          final String id = row['id'] as String? ?? '';
          if (id.isEmpty) {
            continue;
          }
          authors[id] = CommunityAuthor(
            id: id,
            fullName: row['full_name'] as String?,
            avatarUrl: row['avatar_url'] as String?,
          );
        }
      }
      return authors;
    } on PostgrestException {
      // Profile lookup failed; do not crash. Return empty map.
      return const <String, CommunityAuthor>{};
    }
  }

  Future<List<CommunityPost>> fetchPosts({int limit = 30}) async {
    return _guard(() async {
      final List<dynamic> rows = await _client
          .from('posts')
          .select(_postColumns)
          .order('created_at', ascending: false)
          .limit(limit);
      final String? userId = currentUserId;
      final Set<String> userIds = <String>{};
      for (final dynamic row in rows) {
        if (row is Map<String, dynamic>) {
          final String? uid = row['user_id'] as String?;
          if (uid != null && uid.isNotEmpty) {
            userIds.add(uid);
          }
        }
      }
      final Map<String, CommunityAuthor> authors =
          await _fetchAuthorsByIds(userIds);
      return rows.map((dynamic row) {
        final Map<String, dynamic> r = row as Map<String, dynamic>;
        final String? postUserId = r['user_id'] as String?;
        final CommunityAuthor author = authors[postUserId ?? ''] ??
            CommunityAuthor(id: postUserId ?? '');
        return CommunityPost.fromJson(
          r,
          imageUrl: _mediaUrl(r['media_url'] as String?),
          currentUserId: userId,
          author: author,
        );
      }).toList();
    });
  }

  Future<CommunityPost> fetchPost(String postId) async {
    return _guard(() async {
      final Map<String, dynamic> row = await _client
          .from('posts')
          .select(_postColumns)
          .eq('id', postId)
          .single();
      final String? postUserId = row['user_id'] as String?;
      final Map<String, CommunityAuthor> authors =
          await _fetchAuthorsByIds(<String>{if (postUserId != null && postUserId.isNotEmpty) postUserId});
      final CommunityAuthor author =
          authors[postUserId ?? ''] ?? CommunityAuthor(id: postUserId ?? '');
      return CommunityPost.fromJson(
        row,
        imageUrl: _mediaUrl(row['media_url'] as String?),
        currentUserId: currentUserId,
        author: author,
      );
    });
  }

  Future<void> createPost({
    required String content,
    List<int>? imageBytes,
    String? mediaType,
  }) async {
    return _guard(() async {
      final String userId = _requireUser();
      String? mediaUrl;
      String? storedMediaType = mediaType;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final String fileName =
            '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
        // Attempt upload to community-media; authorization unverified
        try {
          await _client.storage.from(_bucket).uploadBinary(
                fileName,
                Uint8List.fromList(imageBytes),
                fileOptions: const sb.FileOptions(contentType: 'image/jpeg'),
              );
          mediaUrl = fileName;
          storedMediaType ??= 'image/jpeg';
        } on StorageException {
          // Upload may not be authorized; do not assume success.
          rethrow;
        }
      }
      await _client.from('posts').insert(<String, dynamic>{
        'user_id': userId,
        'content': content.trim(),
        'media_url': mediaUrl,
        'media_type': storedMediaType,
      });
    });
  }

  bool _isExpectedSupabaseStorageUrl(Uri uri) {
    if (uri.scheme != 'https') {
      return false;
    }
    if (uri.host.isEmpty) {
      return false;
    }
    final String configuredUrl = SupabaseConfig.url;
    if (configuredUrl.isEmpty) {
      return false;
    }
    final Uri? configuredUri = Uri.tryParse(configuredUrl);
    if (configuredUri == null || configuredUri.host.isEmpty) {
      return false;
    }
    // Require matching host to configured Supabase endpoint
    if (uri.host.toLowerCase() != configuredUri.host.toLowerCase()) {
      return false;
    }
    // Require documented public storage path structure for community-media bucket
    final String path = uri.path;
    // Standard Supabase public storage: /storage/v1/object/public/<bucket>/
    final String expectedPrefix = '/storage/v1/object/public/$_bucket/';
    if (!path.startsWith(expectedPrefix)) {
      return false;
    }
    return true;
  }

  String? _extractSafeStoragePathForDelete(
    String? mediaUrl,
    String ownerUserId,
  ) {
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return null;
    }
    final String value = mediaUrl.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final Uri? uri = Uri.tryParse(value);
      if (uri == null) {
        return null;
      }
      if (!_isExpectedSupabaseStorageUrl(uri)) {
        return null;
      }
      // Must contain bucket in path for public storage URL pattern
      final String path = _pathFromUrlForBucket(uri.toString(), _bucket);
      if (path.isEmpty) {
        return null;
      }
      if (!_isValidStorageObjectPath(path, ownerUserId)) {
        return null;
      }
      return path;
    }
    // Non-URL: must be a strict storage object path
    if (!_isValidStorageObjectPath(value, ownerUserId)) {
      return null;
    }
    return value;
  }

  bool _isValidStorageObjectPath(String path, String ownerUserId) {
    final String value = path.trim();
    if (value.isEmpty) {
      return false;
    }
    if (value.contains('://')) {
      return false;
    }
    if (value.startsWith('/')) {
      return false;
    }
    if (value.contains('..')) {
      return false;
    }
    if (value.contains('?') || value.contains('#')) {
      return false;
    }
    // Require user-scoped path: first segment must match owner
    final List<String> segments =
        value.split('/').where((String s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return false;
    }
    if (segments.first != ownerUserId) {
      return false;
    }
    // Basic filename sanity
    final String fileName = segments.last;
    if (fileName.isEmpty || fileName.contains('\\')) {
      return false;
    }
    return true;
  }

  Future<void> deletePost(CommunityPost post) async {
    return _guard(() async {
      final String? currentUserId = this.currentUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        throw CommunityFailure('You must be signed in to do that.');
      }
      final String ownerUserId = post.userId ?? post.author.id;
      if (ownerUserId.isEmpty) {
        throw CommunityFailure('Unable to verify post ownership.');
      }
      if (ownerUserId != currentUserId) {
        throw CommunityFailure('You can only delete your own posts.');
      }
      // Do not delete DB first if doing so would prevent safe cleanup verification
      final String? storagePath =
          _extractSafeStoragePathForDelete(post.imageUrl, ownerUserId);
      if (storagePath != null) {
        try {
          await _client.storage.from(_bucket).remove(<String>[storagePath]);
        } on StorageException {
          // Skip if deletion not authorized/possible; do not block DB delete
          // but ownership already verified
        }
      }
      // If storage path could not be safely established, skip storage deletion
      await _client.from('posts').delete().eq('id', post.id);
    });
  }

  Future<void> setLiked(String postId, bool liked) async {
    return _guard(() async {
      final String userId = _requireUser();
      if (liked) {
        await _client.from('likes').upsert(<String, dynamic>{
          'post_id': postId,
          'user_id': userId,
        });
      } else {
        await _client
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      }
    });
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    return _guard(() async {
      final List<dynamic> rows = await _client
          .from('comments')
          .select('id, post_id, user_id, content, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      final Set<String> userIds = <String>{};
      for (final dynamic row in rows) {
        if (row is Map<String, dynamic>) {
          final String? uid = row['user_id'] as String?;
          if (uid != null && uid.isNotEmpty) {
            userIds.add(uid);
          }
        }
      }
      final Map<String, CommunityAuthor> authors =
          await _fetchAuthorsByIds(userIds);
      return rows.map((dynamic row) {
        final Map<String, dynamic> r = row as Map<String, dynamic>;
        final String? commentUserId = r['user_id'] as String?;
        final CommunityAuthor author =
            authors[commentUserId ?? ''] ?? CommunityAuthor(id: commentUserId ?? '');
        return CommunityComment.fromJson(r, author: author);
      }).toList();
    });
  }

  Future<void> addComment({
    required String postId,
    required String content,
  }) async {
    return _guard(() async {
      final String userId = _requireUser();
      await _client.from('comments').insert(<String, dynamic>{
        'post_id': postId,
        'user_id': userId,
        'content': content.trim(),
      });
    });
  }

  String _requireUser() {
    final String? userId = currentUserId;
    if (userId == null) {
      throw CommunityFailure('You must be signed in to do that.');
    }
    return userId;
  }

  /// Extracts the object path from a public storage URL for a given bucket.
  String _pathFromUrlForBucket(String url, String bucket) {
    final String marker = '/$bucket/';
    final int markerIndex = url.indexOf(marker);
    if (markerIndex < 0) {
      return '';
    }
    final String pathPart =
        url.substring(markerIndex + marker.length);
    // Strip query/fragment if present
    final int queryIndex = pathPart.indexOf('?');
    final int fragmentIndex = pathPart.indexOf('#');
    int end = pathPart.length;
    if (queryIndex >= 0 && queryIndex < end) {
      end = queryIndex;
    }
    if (fragmentIndex >= 0 && fragmentIndex < end) {
      end = fragmentIndex;
    }
    if (end <= 0) {
      return '';
    }
    return Uri.decodeComponent(pathPart.substring(0, end));
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw CommunityFailure(error.message);
    } on StorageException catch (error) {
      throw CommunityFailure(error.message);
    } on AuthException catch (error) {
      throw CommunityFailure(error.message);
    }
  }
}
