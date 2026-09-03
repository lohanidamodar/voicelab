import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_pipeline/speech_pipeline.dart';
import 'package:voicelab/core/app.dart';
import 'package:voicelab/core/engine/voice_model_settings.dart';
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

    // Point the model store at an empty directory. Otherwise the test reads
    // whatever this machine happens to have downloaded and tries to load a
    // multi-gigabyte model, which never settles.
    final empty = Directory.systemTemp.createTempSync('voicelab-smoke');
    addTearDown(() => empty.deleteSync(recursive: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          voiceCatalogueProvider.overrideWith(
            (ref) => VoiceCatalogue(store: ModelStore(root: empty)),
          ),
        ],
        child: const VoicelabApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
