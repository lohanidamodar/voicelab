// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VoiceLab';

  @override
  String get navClone => 'Clone';

  @override
  String get navSpeak => 'Speak';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionOk => 'OK';

  @override
  String get actionClose => 'Close';

  @override
  String get comingSoon => 'Nothing here yet';

  @override
  String get comingSoonBody =>
      'This screen is a placeholder. Replace it with the real thing.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get themeSystem => 'Match device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'Match device';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageNepali => 'Nepali';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeDefault => 'Default';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get textSizeLarger => 'Larger';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentForest => 'Forest';

  @override
  String get accentAmber => 'Amber';

  @override
  String get accentCoral => 'Coral';

  @override
  String get accentRose => 'Rose';

  @override
  String get accentMauve => 'Mauve';

  @override
  String get accentSlate => 'Slate';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutPrivacyPolicy => 'Privacy policy';

  @override
  String get aboutPrivacyPolicySubtitle =>
      'What we collect, and what we don\'t';

  @override
  String get aboutLicenses => 'Open-source licences';

  @override
  String get aboutLicensesSubtitle => 'Third-party packages this app uses';

  @override
  String get aboutShare => 'Share VoiceLab';

  @override
  String get aboutShareSubtitle => 'Tell someone who\'d find it useful';

  @override
  String get aboutShareMessage =>
      'I\'ve been using VoiceLab — you might like it too.';

  @override
  String get aboutRate => 'Rate VoiceLab';

  @override
  String get aboutRateSubtitle => 'A rating genuinely helps';

  @override
  String get aboutMoreApps => 'More from PopupBits';

  @override
  String get aboutMoreAppsSubtitle => 'Other things we build';

  @override
  String get aboutSupport => 'Contact support';

  @override
  String get aboutSupportSubtitle => 'info@popupbits.com';

  @override
  String get aboutSupportSubject => 'VoiceLab support';

  @override
  String errorCouldNotOpen(String target) {
    return 'Couldn\'t open $target';
  }

  @override
  String get settingsDiagnostics => 'Some features didn\'t start';

  @override
  String settingsDiagnosticsBody(int count) {
    return '$count background service failed to start. The app works, but parts of it may not.';
  }
}
