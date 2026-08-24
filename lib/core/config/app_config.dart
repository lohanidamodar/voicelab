/// Compile-time configuration.
///
/// Values can be overridden per build with `--dart-define`, which is how a
/// staging build points at a different backend without a code change:
///
/// ```sh
/// flutter build apk --dart-define=APPWRITE_ENDPOINT=https://staging/v1
/// ```
abstract final class AppConfig {
  static const String appName = 'VoiceLab';

  /// Android applicationId / iOS bundle id. Must match the Gradle config —
  /// the store deep link is built from it.
  static const String androidApplicationId = 'com.popupbits.voicelab';

  static const String storeListingUrl =
      'https://play.google.com/store/apps/details?id=com.popupbits.voicelab';

  static const String privacyPolicyUrl =
      'https://www.popupbits.com/contact/voicelab-privacy-policy';
  static const String moreAppsUrl = 'https://www.popupbits.com/products';
  static const String supportEmail = 'info@popupbits.com';
  static const String legalese = '© 2026 PopupBits';
}
