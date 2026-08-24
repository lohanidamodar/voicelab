import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicelab/core/app.dart';
import 'package:voicelab/core/settings/settings_controller.dart';

import 'screenshot_helper.dart';

/// Captures the store screenshots.
///
/// Run against a real device or a correctly-sized emulator:
///
/// ```sh
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_test.dart \
///   -d <device>
/// ```
///
/// Files land in `build/screenshots/`, which is where the fastlane
/// `upload_screenshots` lane collects them from.
///
/// Extend the steps below as the app grows. Do not wrap them in try/catch —
/// see the note on [ScreenshotHelper].
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final screenshots = ScreenshotHelper(binding);

  testWidgets('store screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const VoicelabApp(),
      ),
    );
    await tester.pumpAndSettle();
    await screenshots.prepare(tester);

    await screenshots.take('clone');
    await screenshots.take('speak');

    // Settings is the last destination in the shell.
    await tester.tap(find.byIcon(PiconsRegular.gear).last);
    await tester.pumpAndSettle();
    await screenshots.take('settings');

    screenshots.assertCaptured(minimum: 2 + 1);
  });
}
