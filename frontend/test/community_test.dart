import 'package:agrismart_app/features/auth/data/app_user.dart';
import 'package:agrismart_app/features/auth/data/auth_providers.dart';
import 'package:agrismart_app/features/community/data/community_models.dart';
import 'package:agrismart_app/features/community/data/community_providers.dart';
import 'package:agrismart_app/features/community/data/community_repository.dart';
import 'package:agrismart_app/features/community/presentation/community_screen.dart';
import 'package:agrismart_app/features/community/presentation/post_detail_screen.dart';
import 'package:agrismart_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const CommunityAuthor _me = CommunityAuthor(id: 'me', fullName: 'Me');
const CommunityAuthor _ravi = CommunityAuthor(id: 'u1', fullName: 'Ravi');
const CommunityAuthor _sita = CommunityAuthor(id: 'u2', fullName: 'Sita');

CommunityPost _post({
  int likeCount = 0,
  bool likedByMe = false,
}) {
  return CommunityPost(
    id: 'p1',
    content: 'My tomatoes are flowering!',
    createdAt: DateTime(2026, 3, 1, 9, 30),
    author: _ravi,
    likeCount: likeCount,
    likedByMe: likedByMe,
  );
}

class _FakeCommunityRepository extends CommunityRepository {
  _FakeCommunityRepository(this.posts, this.comments);

  final List<CommunityPost> posts;
  final List<CommunityComment> comments;

  @override
  Future<List<CommunityPost>> fetchPosts({int limit = 30}) async =>
      List<CommunityPost>.of(posts);

  @override
  Future<CommunityPost> fetchPost(String postId) async =>
      posts.firstWhere((CommunityPost p) => p.id == postId);

  @override
  Future<void> setLiked(String postId, bool liked) async {
    final int index = posts.indexWhere((CommunityPost p) => p.id == postId);
    if (index < 0) {
      return;
    }
    final CommunityPost current = posts[index];
    posts[index] = CommunityPost(
      id: current.id,
      content: current.content,
      createdAt: current.createdAt,
      author: current.author,
      imageUrl: current.imageUrl,
      likeCount: liked ? current.likeCount + 1 : current.likeCount - 1,
      likedByMe: liked,
    );
  }

  @override
  Future<List<CommunityComment>> fetchComments(String postId) async =>
      List<CommunityComment>.of(comments);

  @override
  Future<void> addComment({
    required String postId,
    required String content,
  }) async {
    comments.add(CommunityComment(
      id: 'c${comments.length}',
      content: content,
      createdAt: DateTime(2026, 3, 2),
      author: _me,
    ));
  }
}

Widget _wrap(Widget child, _FakeCommunityRepository repository) {
  return ProviderScope(
    overrides: [
      communityConfiguredProvider.overrideWithValue(true),
      communityRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith(
        (Ref ref) => Stream<AppUser?>.value(
          const AppUser(id: 'me', fullName: 'Me'),
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('Community feed shows a post and likes toggle the count',
      (WidgetTester tester) async {
    final _FakeCommunityRepository repository = _FakeCommunityRepository(
      <CommunityPost>[_post()],
      <CommunityComment>[],
    );

    await tester.pumpWidget(_wrap(const CommunityScreen(), repository));
    await tester.pumpAndSettle();

    expect(find.text('My tomatoes are flowering!'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.text('0'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Post detail lists comments and adds a new one',
      (WidgetTester tester) async {
    final _FakeCommunityRepository repository = _FakeCommunityRepository(
      <CommunityPost>[_post()],
      <CommunityComment>[
        CommunityComment(
          id: 'c0',
          content: 'Looking healthy!',
          createdAt: DateTime(2026, 3, 1, 12),
          author: _sita,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(const PostDetailScreen(postId: 'p1'), repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Looking healthy!'), findsOneWidget);
    expect(find.text('Sita'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Nice work!');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Nice work!'), findsOneWidget);
  });
}
