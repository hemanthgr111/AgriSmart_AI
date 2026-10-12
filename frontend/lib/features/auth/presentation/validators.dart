import '../../../l10n/app_localizations.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateRequired(AppLocalizations l10n, String? value) {
  if (value == null || value.trim().isEmpty) {
    return l10n.fieldRequired;
  }
  return null;
}

String? validateEmail(AppLocalizations l10n, String? value) {
  final String email = (value ?? '').trim();
  if (email.isEmpty) {
    return l10n.fieldRequired;
  }
  if (!_emailPattern.hasMatch(email)) {
    return l10n.invalidEmail;
  }
  return null;
}

String? validatePassword(AppLocalizations l10n, String? value) {
  final String password = value ?? '';
  if (password.isEmpty) {
    return l10n.fieldRequired;
  }
  if (password.length < 8) {
    return l10n.passwordTooShort;
  }
  return null;
}

String? validateConfirmPassword(
  AppLocalizations l10n,
  String? value,
  String password,
) {
  if (value == null || value.isEmpty) {
    return l10n.fieldRequired;
  }
  if (value != password) {
    return l10n.passwordsDoNotMatch;
  }
  return null;
}
