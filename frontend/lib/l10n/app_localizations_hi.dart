// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get communityTitle => 'समुदाय';

  @override
  String get communityIntro => 'अन्य किसानों के साथ साझा करें और सीखें।';

  @override
  String get communityNotConfigured =>
      'समुदाय के लिए साइन-इन आवश्यक है, जो अभी सेट नहीं है।';

  @override
  String get communityLoadFailed => 'समुदाय फ़ीड लोड नहीं हो सकी।';

  @override
  String get createPost => 'नई पोस्ट';

  @override
  String get postHint => 'आपके खेत में क्या हो रहा है?';

  @override
  String get postAddPhoto => 'फ़ोटो जोड़ें';

  @override
  String get postPublish => 'प्रकाशित करें';

  @override
  String get postContentRequired => 'पोस्ट करने के लिए कुछ लिखें।';

  @override
  String get postFailed => 'पोस्ट नहीं हो सकी। कृपया पुनः प्रयास करें।';

  @override
  String get noPosts => 'अभी कोई पोस्ट नहीं। सबसे पहले साझा करें!';

  @override
  String get commentsTitle => 'टिप्पणियाँ';

  @override
  String get commentHint => 'टिप्पणी जोड़ें';

  @override
  String get commentSend => 'भेजें';

  @override
  String get commentFailed => 'आपकी टिप्पणी जोड़ी नहीं जा सकी।';

  @override
  String get noComments => 'अभी कोई टिप्पणी नहीं।';

  @override
  String get likePost => 'पसंद';

  @override
  String get deletePost => 'पोस्ट हटाएँ';

  @override
  String get deleteConfirm => 'यह पोस्ट हटाएँ?';

  @override
  String get postDeleted => 'पोस्ट हटा दी गई।';

  @override
  String get appTitle => 'AgriSmart AI';

  @override
  String get appTagline => 'स्वस्थ फसलों के लिए आपका AI सहायक।';

  @override
  String get onboardingTitle => 'अपनी भाषा चुनें';

  @override
  String get onboardingSubtitle => 'आप इसे बाद में सेटिंग्स में बदल सकते हैं।';

  @override
  String get chooseLanguage => 'भाषा';

  @override
  String get continueLabel => 'जारी रखें';

  @override
  String get skip => 'छोड़ें';

  @override
  String get welcomeFarmer => 'स्वागत है, किसान';

  @override
  String get homeTagline => 'स्वस्थ फसलों के लिए आपका AI सहायक।';

  @override
  String get comingSoon => 'जल्द आ रहा है';

  @override
  String get featureCropDisease => 'फसल रोग पहचान';

  @override
  String get featureWeather => 'मौसम डैशबोर्ड';

  @override
  String get featureAssistant => 'AI किसान सहायक';

  @override
  String get featureCommunity => 'किसान समुदाय';

  @override
  String get backend => 'बैकएंड';

  @override
  String get version => 'संस्करण';

  @override
  String get environment => 'वातावरण';

  @override
  String get database => 'डेटाबेस';

  @override
  String get databaseNotConfigured =>
      'डेटाबेस अभी कॉन्फ़िगर नहीं है। पहचान इतिहास, चैट और समुदाय सुविधाओं के लिए डेटाबेस कनेक्शन आवश्यक है।';

  @override
  String get contactingBackend => 'बैकएंड से संपर्क हो रहा है...';

  @override
  String get backendUnavailable => 'बैकएंड उपलब्ध नहीं है';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get refresh => 'रीफ़्रेश करें';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get language => 'भाषा';

  @override
  String get languageSystem => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get account => 'खाता';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get login => 'लॉग इन करें';

  @override
  String get register => 'रजिस्टर करें';

  @override
  String get logout => 'लॉग आउट करें';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get confirmPassword => 'पासवर्ड की पुष्टि करें';

  @override
  String get fullName => 'पूरा नाम';

  @override
  String get forgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get signInWithGoogle => 'Google से जारी रखें';

  @override
  String get noAccountRegister => 'खाता नहीं है? रजिस्टर करें';

  @override
  String get haveAccountLogin => 'पहले से खाता है? लॉग इन करें';

  @override
  String get createAccount => 'खाता बनाएं';

  @override
  String get signIn => 'साइन इन करें';

  @override
  String get resetPassword => 'पासवर्ड रीसेट करें';

  @override
  String get sendResetLink => 'रीसेट लिंक भेजें';

  @override
  String get emailVerificationTitle => 'अपना ईमेल सत्यापित करें';

  @override
  String get emailVerificationBody =>
      'हमने आपके ईमेल पर एक सत्यापन लिंक भेजा है। कृपया इसे सत्यापित करें, फिर लॉग इन करें।';

  @override
  String get resendEmail => 'ईमेल फिर से भेजें';

  @override
  String get authNotConfigured => 'साइन-इन कॉन्फ़िगर नहीं है';

  @override
  String get authNotConfiguredBody =>
      'ऐप बिना प्रमाणीकरण क्रेडेंशियल के चल रहा है। लॉगिन सक्षम करने के लिए अपनी Supabase URL और anon key जोड़ें।';

  @override
  String get fieldRequired => 'यह फ़ील्ड आवश्यक है।';

  @override
  String get invalidEmail => 'मान्य ईमेल पता दर्ज करें।';

  @override
  String get passwordTooShort => 'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए।';

  @override
  String get passwordsDoNotMatch => 'पासवर्ड मेल नहीं खाते।';

  @override
  String get loginFailed => 'लॉगिन विफल। अपना ईमेल और पासवर्ड जांचें।';

  @override
  String get registerSuccess => 'खाता बन गया।';

  @override
  String get checkYourEmail =>
      'अपने खाते को सत्यापित करने के लिए अपना ईमेल देखें।';

  @override
  String get saveProfile => 'प्रोफ़ाइल सहेजें';

  @override
  String get profileSaved => 'प्रोफ़ाइल सहेजी गई।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सहेजें';

  @override
  String get delete => 'हटाएं';

  @override
  String get error => 'कुछ गलत हो गया।';

  @override
  String get tryAgain => 'पुनः प्रयास करें';

  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get weatherTitle => 'मौसम';

  @override
  String get weatherLocation => 'स्थान';

  @override
  String get useMyLocation => 'मेरा स्थान उपयोग करें';

  @override
  String get enterLocation => 'स्थान दर्ज करें';

  @override
  String get searchLocation => 'खोजें';

  @override
  String get temperature => 'तापमान';

  @override
  String get humidity => 'आर्द्रता';

  @override
  String get wind => 'हवा';

  @override
  String get rainChance => 'बारिश की संभावना';

  @override
  String get forecast => 'पूर्वानुमान';

  @override
  String get lastUpdated => 'अंतिम अपडेट';

  @override
  String get weatherUnavailable => 'मौसम उपलब्ध नहीं है';

  @override
  String get locationPermissionDenied =>
      'स्थान अनुमति अस्वीकृत। मैन्युअल रूप से स्थान दर्ज करें।';

  @override
  String get locationServicesDisabled =>
      'स्थान सेवाएं बंद हैं। मैन्युअल रूप से स्थान दर्ज करें।';

  @override
  String get invalidLocation => 'स्थान नहीं मिला। दूसरा आज़माएं।';

  @override
  String get noWeatherData => 'कोई मौसम डेटा उपलब्ध नहीं।';

  @override
  String get feelsLike => 'महसूस होता है';

  @override
  String get condition => 'स्थिति';

  @override
  String get diagnosisTitle => 'फसल निदान';

  @override
  String get diagnoseTakePhoto => 'फ़ोटो लें';

  @override
  String get diagnoseChooseGallery => 'गैलरी से चुनें';

  @override
  String get diagnoseAnalyze => 'विश्लेषण करें';

  @override
  String get diagnoseNoImage => 'शुरू करने के लिए पत्ती की फ़ोटो जोड़ें।';

  @override
  String get analyzeAgain => 'दूसरा विश्लेषण करें';

  @override
  String get analyzing => 'विश्लेषण हो रहा है...';

  @override
  String get resultCrop => 'फ़सल';

  @override
  String get resultDisease => 'स्थिति';

  @override
  String get resultConfidence => 'विश्वास';

  @override
  String get resultHealthy => 'स्वस्थ';

  @override
  String get resultDiseased => 'रोग का पता चला';

  @override
  String get adviceTitle => 'देखभाल सलाह';

  @override
  String get otherPossibilities => 'अन्य संभावनाएँ';

  @override
  String get diagnosisNotConfigured => 'सर्वर पर रोग पहचान अभी सेट नहीं है।';

  @override
  String get invalidImage => 'यह फ़ाइल मान्य छवि नहीं है।';

  @override
  String get imageTooLarge => 'छवि बहुत बड़ी है। छोटी फ़ोटो आज़माएँ।';

  @override
  String get diagnosisFailed =>
      'छवि का विश्लेषण नहीं हो सका। कृपया पुनः प्रयास करें।';

  @override
  String get assistantTitle => 'कृषि AI सहायक';

  @override
  String get assistantIntro =>
      'अपनी फसल, मिट्टी, कीट या मौसम के बारे में कुछ भी पूछें।';

  @override
  String get assistantHint => 'अपना प्रश्न लिखें';

  @override
  String get assistantSend => 'भेजें';

  @override
  String get assistantClear => 'चैट साफ़ करें';

  @override
  String get assistantError =>
      'सहायक अभी उपलब्ध नहीं है। कृपया पुनः प्रयास करें।';

  @override
  String get assistantNotConfigured => 'सर्वर पर AI सहायक अभी सेट नहीं है।';

  @override
  String get assistantDisclaimer =>
      'AI सलाह अपूर्ण हो सकती है। महत्वपूर्ण निर्णयों की पुष्टि स्थानीय विशेषज्ञ से करें।';

  @override
  String get assistantThinking => 'सोच रहा है...';

  @override
  String get suggestion1 => 'टमाटर में कीटों को कैसे नियंत्रित करें?';

  @override
  String get suggestion2 => 'गेहूँ में सिंचाई कब करें?';

  @override
  String get suggestion3 => 'मिट्टी की उर्वरता कैसे बढ़ाएँ?';
}
