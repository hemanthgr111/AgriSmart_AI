import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException, StorageException, SupabaseClient;

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

  static const String _bucket = 'community';

  static const String _postColumns =
      'id, content, image_path, created_at, author_id, '
      'author:profiles(id, full_name, avatar_url), '
      'post_likes(user_id)';

  final SupabaseClient? _injectedClient;

  // Resolved lazily so subclasses (e.g. test fakes) can construct without a
  // live Supabase instance.
  SupabaseClient get _client => _injectedClient ?? sb.Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  bool get isSignedIn => currentUserId != null;

  String? _imageUrl(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<List<CommunityPost>> fetchPosts({int limit = 30}) async {
    return _guard(() async {
      final List<dynamic> rows = await _client
          .from('posts')
          .select(_postColumns)
          .order('created_at', ascending: false)
          .limit(limit);
      final String? userId = currentUserId;
      return rows
          .map((dynamic row) => CommunityPost.fromJson(
                row as Map<String, dynamic>,
                imageUrl: _imageUrl(row['image_path'] as String?),
                currentUserId: userId,
              ))
          .toList();
    });
  }

  Future<CommunityPost> fetchPost(String postId) async {
    return _guard(() async {
      final Map<String, dynamic> row = await _client
          .from('posts')
          .select(_postColumns)
          .eq('id', postId)
          .single();
      return CommunityPost.fromJson(
        row,
        imageUrl: _imageUrl(row['image_path'] as String?),
        currentUserId: currentUserId,
      );
    });
  }

  Future<void> createPost({
    required String content,
    List<int>? imageBytes,
  }) async {
    return _guard(() async {
      final String userId = _requireUser();
      String? imagePath;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        imagePath = '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
        await _client.storage.from(_bucket).uploadBinary(
              imagePath,
              Uint8List.fromList(imageBytes),
              fileOptions: const sb.FileOptions(contentType: 'image/jpeg'),
            );
      }
      await _client.from('posts').insert(<String, dynamic>{
        'author_id': userId,
        'content': content.trim(),
        'image_path': imagePath,
      });
    });
  }

  Future<void> deletePost(CommunityPost post) async {
    return _guard(() async {
      await _client.from('posts').delete().eq('id', post.id);
      final String? imageUrl = post.imageUrl;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final String path = _pathFromUrl(imageUrl);
        if (path.isNotEmpty) {
          await _client.storage.from(_bucket).remove(<String>[path]);
        }
      }
    });
  }

  Future<void> setLiked(String postId, bool liked) async {
    return _guard(() async {
      final String userId = _requireUser();
      if (liked) {
        await _client.from('post_likes').upsert(<String, dynamic>{
          'post_id': postId,
          'user_id': userId,
        });
      } else {
        await _client
            .from('post_likes')
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
          .select('id, content, created_at, author:profiles(id, full_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return rows
          .map((dynamic row) =>
              CommunityComment.fromJson(row as Map<String, dynamic>))
          .toList();
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
        'author_id': userId,
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

  /// Extracts the object path from a public storage URL.
  String _pathFromUrl(String url) {
    final int marker = url.indexOf('/$_bucket/');
    if (marker < 0) {
      return '';
    }
    return Uri.decodeComponent(url.substring(marker + _bucket.length + 2));
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
