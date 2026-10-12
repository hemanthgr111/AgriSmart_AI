import 'package:flutter/widgets.dart';

/// The languages supported by AgriSmart AI.
///
/// `nativeName` is intentionally written in each language's own script so the
/// language picker is understandable regardless of the current locale.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });

  final String code;
  final String nativeName;
  final String englishName;

  Locale get locale => Locale(code);
}

const List<AppLanguage> kSupportedLanguages = <AppLanguage>[
  AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
  AppLanguage(code: 'hi', nativeName: 'हिन्दी', englishName: 'Hindi'),
  AppLanguage(code: 'bn', nativeName: 'বাংলা', englishName: 'Bengali'),
  AppLanguage(code: 'mr', nativeName: 'मराठी', englishName: 'Marathi'),
  AppLanguage(code: 'te', nativeName: 'తెలుగు', englishName: 'Telugu'),
  AppLanguage(code: 'ta', nativeName: 'தமிழ்', englishName: 'Tamil'),
  AppLanguage(code: 'gu', nativeName: 'ગુજરાતી', englishName: 'Gujarati'),
  AppLanguage(code: 'ur', nativeName: 'اُردُو', englishName: 'Urdu'),
  AppLanguage(code: 'kn', nativeName: 'ಕನ್ನಡ', englishName: 'Kannada'),
];
