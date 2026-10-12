import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A lightweight, app-facing representation of the authenticated user.
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.emailVerified = false,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final bool emailVerified;

  String get displayName {
    final String? name = fullName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final String? mail = email;
    if (mail != null && mail.contains('@')) {
      return mail.split('@').first;
    }
    return 'Farmer';
  }

  factory AppUser.fromSupabase(sb.User user) {
    final Map<String, dynamic> metadata = user.userMetadata ?? <String, dynamic>{};
    return AppUser(
      id: user.id,
      email: user.email,
      fullName: (metadata['full_name'] ?? metadata['name']) as String?,
      avatarUrl: metadata['avatar_url'] as String?,
      emailVerified: user.emailConfirmedAt != null,
    );
  }
}
