import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, OAuthProvider, SupabaseClient;

import 'app_user.dart';

/// Error surfaced to the UI. Never contains secrets.
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin wrapper over Supabase Auth.
///
/// Only instantiate this when [SupabaseConfig.isConfigured] is true.
class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  final SupabaseClient _client;

  sb.GoTrueClient get _auth => _client.auth;

  AppUser? get currentUser {
    final sb.User? user = _auth.currentUser;
    return user == null ? null : AppUser.fromSupabase(user);
  }

  Stream<AppUser?> authStateChanges() {
    return _auth.onAuthStateChange.map((sb.AuthState event) {
      final sb.User? user = event.session?.user;
      return user == null ? null : AppUser.fromSupabase(user);
    });
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  Future<AppUser?> signUpWithPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final sb.AuthResponse response = await _auth.signUp(
        email: email,
        password: password,
        data: fullName == null ? null : <String, dynamic>{'full_name': fullName},
      );
      final sb.User? user = response.user;
      return user == null ? null : AppUser.fromSupabase(user);
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.agrismart://login-callback',
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    try {
      await _auth.resend(type: sb.OtpType.signup, email: email);
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  Future<void> updateFullName(String fullName) async {
    try {
      await _auth.updateUser(
        sb.UserAttributes(data: <String, dynamic>{'full_name': fullName}),
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }
}
