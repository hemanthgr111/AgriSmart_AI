import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import 'community_models.dart';
import 'community_repository.dart';

/// Whether Supabase was configured at build time. The community feature is
/// unavailable otherwise (it needs an authenticated account).
final Provider<bool> communityConfiguredProvider =
    Provider<bool>((ref) => SupabaseConfig.isConfigured);

/// Available only when Supabase is configured. Reading it otherwise throws.
final Provider<CommunityRepository> communityRepositoryProvider =
    Provider<CommunityRepository>((ref) {
  if (!SupabaseConfig.isConfigured) {
    throw StateError('Supabase is not configured.');
  }
  return CommunityRepository();
});

/// The community feed, newest first.
final FutureProvider<List<CommunityPost>> feedProvider =
    FutureProvider<List<CommunityPost>>((ref) {
  return ref.watch(communityRepositoryProvider).fetchPosts();
});

/// A single post by id.
final postProvider = FutureProvider.family<CommunityPost, String>(
  (ref, String postId) {
    return ref.watch(communityRepositoryProvider).fetchPost(postId);
  },
);

/// Comments for a post, oldest first.
final commentsProvider = FutureProvider.family<List<CommunityComment>, String>(
  (ref, String postId) {
    return ref.watch(communityRepositoryProvider).fetchComments(postId);
  },
);
