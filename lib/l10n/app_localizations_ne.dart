// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class AppLocalizationsNe extends AppLocalizations {
  AppLocalizationsNe([String locale = 'ne']) : super(locale);

  @override
  String get appTitle => 'VoiceLab';

  @override
  String get navClone => 'Clone';

  @override
  String get navSpeak => 'Speak';

  @override
  String get navSettings => 'सेटिङ';

  @override
  String get actionRetry => 'फेरि प्रयास गर्नुहोस्';

  @override
  String get actionCancel => 'रद्द गर्नुहोस्';

  @override
  String get actionConfirm => 'पुष्टि गर्नुहोस्';

  @override
  String get actionOk => 'ठिक छ';

  @override
  String get actionClose => 'बन्द गर्नुहोस्';

  @override
  String get comingSoon => 'यहाँ अहिलेसम्म केही छैन';

  @override
  String get comingSoonBody =>
      'यो स्क्रिन नमुना मात्र हो। यसलाई वास्तविक सामग्रीले बदल्नुहोस्।';

  @override
  String get settingsTitle => 'सेटिङ';

  @override
  String get settingsAppearance => 'रूपरङ';

  @override
  String get settingsGeneral => 'सामान्य';

  @override
  String get settingsAbout => 'बारेमा';

  @override
  String get settingsAccent => 'मुख्य रङ';

  @override
  String get settingsThemeMode => 'थिम';

  @override
  String get themeSystem => 'यन्त्रअनुसार';

  @override
  String get themeLight => 'उज्यालो';

  @override
  String get themeDark => 'अँध्यारो';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get languageSystem => 'यन्त्रअनुसार';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageNepali => 'नेपाली';

  @override
  String get settingsTextSize => 'अक्षरको आकार';

  @override
  String get textSizeSmall => 'सानो';

  @override
  String get textSizeDefault => 'सामान्य';

  @override
  String get textSizeLarge => 'ठूलो';

  @override
  String get textSizeLarger => 'अझ ठूलो';

  @override
  String get accentIndigo => 'नीलो';

  @override
  String get accentTeal => 'हरियो-नीलो';

  @override
  String get accentForest => 'वन हरियो';

  @override
  String get accentAmber => 'पहेँलो';

  @override
  String get accentCoral => 'सुन्तले';

  @override
  String get accentRose => 'गुलाबी';

  @override
  String get accentMauve => 'बैजनी';

  @override
  String get accentSlate => 'खरानी';

  @override
  String get aboutTitle => 'बारेमा';

  @override
  String aboutVersion(String version) {
    return 'संस्करण $version';
  }

  @override
  String get aboutPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get aboutPrivacyPolicySubtitle =>
      'हामी के सङ्कलन गर्छौं, र के गर्दैनौं';

  @override
  String get aboutLicenses => 'खुला स्रोत अनुमतिपत्र';

  @override
  String get aboutLicensesSubtitle => 'यो एपले प्रयोग गर्ने अन्य प्याकेजहरू';

  @override
  String get aboutShare => 'VoiceLab साझा गर्नुहोस्';

  @override
  String get aboutShareSubtitle => 'उपयोगी लाग्ने कसैलाई भन्नुहोस्';

  @override
  String get aboutShareMessage =>
      'म VoiceLab प्रयोग गर्दै छु — तपाईंलाई पनि मन पर्न सक्छ।';

  @override
  String get aboutRate => 'VoiceLab लाई मूल्याङ्कन गर्नुहोस्';

  @override
  String get aboutRateSubtitle => 'तपाईंको मूल्याङ्कनले साँच्चै मद्दत गर्छ';

  @override
  String get aboutMoreApps => 'PopupBits का अन्य एपहरू';

  @override
  String get aboutMoreAppsSubtitle => 'हामीले बनाएका अरू कुराहरू';

  @override
  String get aboutSupport => 'सहयोगका लागि सम्पर्क';

  @override
  String get aboutSupportSubtitle => 'info@popupbits.com';

  @override
  String get aboutSupportSubject => 'VoiceLab सहयोग';

  @override
  String errorCouldNotOpen(String target) {
    return '$target खोल्न सकिएन';
  }

  @override
  String get settingsDiagnostics => 'केही सुविधाहरू सुरु भएनन्';

  @override
  String settingsDiagnosticsBody(int count) {
    return '$count वटा पृष्ठभूमि सेवा सुरु हुन सकेन। एप चल्छ, तर केही भागहरूले काम नगर्न सक्छन्।';
  }
}
