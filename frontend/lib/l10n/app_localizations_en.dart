// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get communityTitle => 'Community';

  @override
  String get communityIntro => 'Share and learn from other farmers.';

  @override
  String get communityNotConfigured =>
      'The community needs sign-in, which is not configured yet.';

  @override
  String get communityLoadFailed => 'Could not load the community feed.';

  @override
  String get createPost => 'New post';

  @override
  String get postHint => 'What\'s happening on your farm?';

  @override
  String get postAddPhoto => 'Add photo';

  @override
  String get postPublish => 'Publish';

  @override
  String get postContentRequired => 'Write something to post.';

  @override
  String get postFailed => 'Could not post. Please try again.';

  @override
  String get noPosts => 'No posts yet. Be the first to share!';

  @override
  String get commentsTitle => 'Comments';

  @override
  String get commentHint => 'Add a comment';

  @override
  String get commentSend => 'Send';

  @override
  String get commentFailed => 'Could not add your comment.';

  @override
  String get noComments => 'No comments yet.';

  @override
  String get likePost => 'Like';

  @override
  String get deletePost => 'Delete post';

  @override
  String get deleteConfirm => 'Delete this post?';

  @override
  String get postDeleted => 'Post deleted.';

  @override
  String get appTitle => 'AgriSmart AI';

  @override
  String get appTagline => 'Your AI assistant for healthier crops.';

  @override
  String get onboardingTitle => 'Choose your language';

  @override
  String get onboardingSubtitle => 'You can change this later in Settings.';

  @override
  String get chooseLanguage => 'Language';

  @override
  String get continueLabel => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get welcomeFarmer => 'Welcome, farmer';

  @override
  String get homeTagline => 'Your AI assistant for healthier crops.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get featureCropDisease => 'Crop disease detection';

  @override
  String get featureWeather => 'Weather dashboard';

  @override
  String get featureAssistant => 'AI farmer assistant';

  @override
  String get featureCommunity => 'Farmer community';

  @override
  String get backend => 'Backend';

  @override
  String get version => 'Version';

  @override
  String get environment => 'Environment';

  @override
  String get database => 'Database';

  @override
  String get databaseNotConfigured =>
      'Database is not configured yet. Detection history, chat, and community features need a database connection.';

  @override
  String get contactingBackend => 'Contacting backend...';

  @override
  String get backendUnavailable => 'Backend unavailable';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get account => 'Account';

  @override
  String get profile => 'Profile';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Register';

  @override
  String get logout => 'Log out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get fullName => 'Full name';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register';

  @override
  String get haveAccountLogin => 'Already have an account? Log in';

  @override
  String get createAccount => 'Create account';

  @override
  String get signIn => 'Sign in';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get emailVerificationTitle => 'Verify your email';

  @override
  String get emailVerificationBody =>
      'We sent a verification link to your email. Please verify it, then log in.';

  @override
  String get resendEmail => 'Resend email';

  @override
  String get authNotConfigured => 'Sign-in is not configured';

  @override
  String get authNotConfiguredBody =>
      'The app is running without authentication credentials. Add your Supabase URL and anon key to enable login.';

  @override
  String get fieldRequired => 'This field is required.';

  @override
  String get invalidEmail => 'Enter a valid email address.';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get loginFailed => 'Login failed. Check your email and password.';

  @override
  String get registerSuccess => 'Account created.';

  @override
  String get checkYourEmail => 'Check your email to verify your account.';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get error => 'Something went wrong.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get weatherTitle => 'Weather';

  @override
  String get weatherLocation => 'Location';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get enterLocation => 'Enter a location';

  @override
  String get searchLocation => 'Search';

  @override
  String get temperature => 'Temperature';

  @override
  String get humidity => 'Humidity';

  @override
  String get wind => 'Wind';

  @override
  String get rainChance => 'Rain chance';

  @override
  String get forecast => 'Forecast';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get weatherUnavailable => 'Weather is unavailable';

  @override
  String get locationPermissionDenied =>
      'Location permission denied. Enter a location manually.';

  @override
  String get locationServicesDisabled =>
      'Location services are disabled. Enter a location manually.';

  @override
  String get invalidLocation => 'Location not found. Try another.';

  @override
  String get noWeatherData => 'No weather data available.';

  @override
  String get feelsLike => 'Feels like';

  @override
  String get condition => 'Condition';

  @override
  String get diagnosisTitle => 'Crop diagnosis';

  @override
  String get diagnoseTakePhoto => 'Take a photo';

  @override
  String get diagnoseChooseGallery => 'Choose from gallery';

  @override
  String get diagnoseAnalyze => 'Analyze';

  @override
  String get diagnoseNoImage => 'Add a leaf photo to begin.';

  @override
  String get analyzeAgain => 'Analyze another';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get resultCrop => 'Crop';

  @override
  String get resultDisease => 'Condition';

  @override
  String get resultConfidence => 'Confidence';

  @override
  String get resultHealthy => 'Healthy';

  @override
  String get resultDiseased => 'Disease detected';

  @override
  String get adviceTitle => 'Care advice';

  @override
  String get otherPossibilities => 'Other possibilities';

  @override
  String get diagnosisNotConfigured =>
      'Disease detection is not set up on the server yet.';

  @override
  String get invalidImage => 'That file is not a valid image.';

  @override
  String get imageTooLarge => 'The image is too large. Try a smaller photo.';

  @override
  String get diagnosisFailed =>
      'Could not analyze the image. Please try again.';

  @override
  String get assistantTitle => 'AI farmer assistant';

  @override
  String get assistantIntro =>
      'Ask me anything about your crops, soil, pests, or weather.';

  @override
  String get assistantHint => 'Type your question';

  @override
  String get assistantSend => 'Send';

  @override
  String get assistantClear => 'Clear chat';

  @override
  String get assistantError =>
      'The assistant is unavailable right now. Please try again.';

  @override
  String get assistantNotConfigured =>
      'The AI assistant is not set up on the server yet.';

  @override
  String get assistantDisclaimer =>
      'AI advice can be imperfect. Confirm important decisions with a local expert.';

  @override
  String get assistantThinking => 'Thinking...';

  @override
  String get suggestion1 => 'How do I control pests in tomatoes?';

  @override
  String get suggestion2 => 'When should I water wheat?';

  @override
  String get suggestion3 => 'How can I improve soil fertility?';
}
