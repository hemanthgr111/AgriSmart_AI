import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('mr'),
    Locale('ta'),
    Locale('te'),
    Locale('ur'),
  ];

  /// No description provided for @communityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get communityTitle;

  /// No description provided for @communityIntro.
  ///
  /// In en, this message translates to:
  /// **'Share and learn from other farmers.'**
  String get communityIntro;

  /// No description provided for @communityNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The community needs sign-in, which is not configured yet.'**
  String get communityNotConfigured;

  /// No description provided for @communityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the community feed.'**
  String get communityLoadFailed;

  /// No description provided for @createPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get createPost;

  /// No description provided for @postHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening on your farm?'**
  String get postHint;

  /// No description provided for @postAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get postAddPhoto;

  /// No description provided for @postPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get postPublish;

  /// No description provided for @postContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Write something to post.'**
  String get postContentRequired;

  /// No description provided for @postFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not post. Please try again.'**
  String get postFailed;

  /// No description provided for @noPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet. Be the first to share!'**
  String get noPosts;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get commentHint;

  /// No description provided for @commentSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commentSend;

  /// No description provided for @commentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add your comment.'**
  String get commentFailed;

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get noComments;

  /// No description provided for @likePost.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get likePost;

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get deletePost;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get deleteConfirm;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted.'**
  String get postDeleted;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AgriSmart AI'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your AI assistant for healthier crops.'**
  String get appTagline;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get onboardingSubtitle;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get chooseLanguage;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @welcomeFarmer.
  ///
  /// In en, this message translates to:
  /// **'Welcome, farmer'**
  String get welcomeFarmer;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Your AI assistant for healthier crops.'**
  String get homeTagline;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @featureCropDisease.
  ///
  /// In en, this message translates to:
  /// **'Crop disease detection'**
  String get featureCropDisease;

  /// No description provided for @featureWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather dashboard'**
  String get featureWeather;

  /// No description provided for @featureAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI farmer assistant'**
  String get featureAssistant;

  /// No description provided for @featureCommunity.
  ///
  /// In en, this message translates to:
  /// **'Farmer community'**
  String get featureCommunity;

  /// No description provided for @backend.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get backend;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @environment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environment;

  /// No description provided for @database.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get database;

  /// No description provided for @databaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Database is not configured yet. Detection history, chat, and community features need a database connection.'**
  String get databaseNotConfigured;

  /// No description provided for @contactingBackend.
  ///
  /// In en, this message translates to:
  /// **'Contacting backend...'**
  String get contactingBackend;

  /// No description provided for @backendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Backend unavailable'**
  String get backendUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// No description provided for @noAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get noAccountRegister;

  /// No description provided for @haveAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get haveAccountLogin;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @emailVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get emailVerificationTitle;

  /// No description provided for @emailVerificationBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to your email. Please verify it, then log in.'**
  String get emailVerificationBody;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @authNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is not configured'**
  String get authNotConfigured;

  /// No description provided for @authNotConfiguredBody.
  ///
  /// In en, this message translates to:
  /// **'The app is running without authentication credentials. Add your Supabase URL and anon key to enable login.'**
  String get authNotConfiguredBody;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get fieldRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Check your email and password.'**
  String get loginFailed;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created.'**
  String get registerSuccess;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email to verify your account.'**
  String get checkYourEmail;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get error;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @weatherTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weatherTitle;

  /// No description provided for @weatherLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get weatherLocation;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @enterLocation.
  ///
  /// In en, this message translates to:
  /// **'Enter a location'**
  String get enterLocation;

  /// No description provided for @searchLocation.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLocation;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// No description provided for @wind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// No description provided for @rainChance.
  ///
  /// In en, this message translates to:
  /// **'Rain chance'**
  String get rainChance;

  /// No description provided for @forecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get forecast;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @weatherUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weather is unavailable'**
  String get weatherUnavailable;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Enter a location manually.'**
  String get locationPermissionDenied;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Enter a location manually.'**
  String get locationServicesDisabled;

  /// No description provided for @invalidLocation.
  ///
  /// In en, this message translates to:
  /// **'Location not found. Try another.'**
  String get invalidLocation;

  /// No description provided for @noWeatherData.
  ///
  /// In en, this message translates to:
  /// **'No weather data available.'**
  String get noWeatherData;

  /// No description provided for @feelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like'**
  String get feelsLike;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @diagnosisTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop diagnosis'**
  String get diagnosisTitle;

  /// No description provided for @diagnoseTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get diagnoseTakePhoto;

  /// No description provided for @diagnoseChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get diagnoseChooseGallery;

  /// No description provided for @diagnoseAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get diagnoseAnalyze;

  /// No description provided for @diagnoseNoImage.
  ///
  /// In en, this message translates to:
  /// **'Add a leaf photo to begin.'**
  String get diagnoseNoImage;

  /// No description provided for @analyzeAgain.
  ///
  /// In en, this message translates to:
  /// **'Analyze another'**
  String get analyzeAgain;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// No description provided for @resultCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get resultCrop;

  /// No description provided for @resultDisease.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get resultDisease;

  /// No description provided for @resultConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get resultConfidence;

  /// No description provided for @resultHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get resultHealthy;

  /// No description provided for @resultDiseased.
  ///
  /// In en, this message translates to:
  /// **'Disease detected'**
  String get resultDiseased;

  /// No description provided for @adviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Care advice'**
  String get adviceTitle;

  /// No description provided for @otherPossibilities.
  ///
  /// In en, this message translates to:
  /// **'Other possibilities'**
  String get otherPossibilities;

  /// No description provided for @diagnosisNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Disease detection is not set up on the server yet.'**
  String get diagnosisNotConfigured;

  /// No description provided for @invalidImage.
  ///
  /// In en, this message translates to:
  /// **'That file is not a valid image.'**
  String get invalidImage;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The image is too large. Try a smaller photo.'**
  String get imageTooLarge;

  /// No description provided for @diagnosisFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not analyze the image. Please try again.'**
  String get diagnosisFailed;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'AI farmer assistant'**
  String get assistantTitle;

  /// No description provided for @assistantIntro.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your crops, soil, pests, or weather.'**
  String get assistantIntro;

  /// No description provided for @assistantHint.
  ///
  /// In en, this message translates to:
  /// **'Type your question'**
  String get assistantHint;

  /// No description provided for @assistantSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get assistantSend;

  /// No description provided for @assistantClear.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get assistantClear;

  /// No description provided for @assistantError.
  ///
  /// In en, this message translates to:
  /// **'The assistant is unavailable right now. Please try again.'**
  String get assistantError;

  /// No description provided for @assistantNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The AI assistant is not set up on the server yet.'**
  String get assistantNotConfigured;

  /// No description provided for @assistantDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI advice can be imperfect. Confirm important decisions with a local expert.'**
  String get assistantDisclaimer;

  /// No description provided for @assistantThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get assistantThinking;

  /// No description provided for @suggestion1.
  ///
  /// In en, this message translates to:
  /// **'How do I control pests in tomatoes?'**
  String get suggestion1;

  /// No description provided for @suggestion2.
  ///
  /// In en, this message translates to:
  /// **'When should I water wheat?'**
  String get suggestion2;

  /// No description provided for @suggestion3.
  ///
  /// In en, this message translates to:
  /// **'How can I improve soil fertility?'**
  String get suggestion3;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'en',
    'gu',
    'hi',
    'kn',
    'mr',
    'ta',
    'te',
    'ur',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
