import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicelab/core/app.dart';
import 'package:voicelab/core/settings/settings_controller.dart';

/// The app builds, routes to its first screen, and renders without throwing.
///
/// Deliberately shallow. Its job is to fail loudly when a change breaks
/// startup — a missing provider override, a bad route table, a theme that
/// throws — not to assert anything about a particular screen.
void main() {
  testWidgets('VoiceLab starts and renders its first screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const VoicelabApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
