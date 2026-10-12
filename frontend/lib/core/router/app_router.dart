import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/community/presentation/create_post_screen.dart';
import '../../features/community/presentation/post_detail_screen.dart';
import '../../features/diagnosis/presentation/diagnosis_screen.dart';
import '../../features/assistant/presentation/assistant_screen.dart';
import '../../features/onboarding/data/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/weather/presentation/weather_screen.dart';

/// Route path constants, usable with `context.go(...)`.
class AppRoutes {
  const AppRoutes._();
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String verifyEmail = '/verify-email';
  static const String home = '/';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String weather = '/weather';
  static const String diagnosis = '/diagnosis';
  static const String assistant = '/assistant';
  static const String community = '/community';
  static const String communityNew = '/community/new';

  /// Path for a single community post.
  static String communityPostPath(String id) => '/community/post/$id';
}

const Set<String> _authRoutes = <String>{
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
  AppRoutes.verifyEmail,
};

/// Notifies GoRouter to re-evaluate redirects when auth/onboarding change.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AsyncValue<Object?>>(authStateProvider, (_, _) {
      notifyListeners();
    });
    ref.listen<bool>(onboardingCompletedProvider, (_, _) {
      notifyListeners();
    });
  }
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final _RouterNotifier notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: notifier,
    redirect: (context, state) {
      final bool onboarded = ref.read(onboardingCompletedProvider);
      final bool configured = ref.read(authConfiguredProvider);
      final AsyncValue<Object?> auth = ref.read(authStateProvider);
      final String location = state.matchedLocation;
      final bool onOnboarding = location == AppRoutes.onboarding;
      final bool onAuthRoute = _authRoutes.contains(location);

      if (!onboarded) {
        return onOnboarding ? null : AppRoutes.onboarding;
      }
      if (onOnboarding) {
        return AppRoutes.home;
      }
      // Guest mode: auth not configured, never force login.
      if (!configured) {
        return null;
      }
      // Wait for the first auth result before deciding.
      if (auth.isLoading) {
        return null;
      }
      final Object? user = auth.value;
      final bool signedIn = user != null;
      if (!signedIn && !onAuthRoute) {
        return AppRoutes.login;
      }
      if (signedIn && onAuthRoute) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => VerifyEmailScreen(
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.weather,
        builder: (context, state) => const WeatherScreen(),
      ),
      GoRoute(
        path: AppRoutes.diagnosis,
        builder: (context, state) => const DiagnosisScreen(),
      ),
      GoRoute(
        path: AppRoutes.assistant,
        builder: (context, state) => const AssistantScreen(),
      ),
      GoRoute(
        path: AppRoutes.community,
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityNew,
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/community/post/:id',
        builder: (context, state) => PostDetailScreen(
          postId: state.pathParameters['id'] ?? '',
        ),
      ),
    ],
  );
});
