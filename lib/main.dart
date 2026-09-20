// `kDebugMode` is not in the `show` list that widgets.dart re-exports from
// foundation, and `material_ui` does not re-export foundation at all, so it
// has to be imported explicitly.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'core/app.dart';
import 'core/bootstrap.dart';
import 'core/settings/settings_controller.dart';

Future<void> main() async {
  // Marionette lets a coding agent drive the running app: read the widget
  // tree, tap, type, screenshot. It replaces the binding, so it has to be
  // the only one initialized — and only in debug, where a release build
  // pays nothing for it.
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  final BootstrapResult bootstrap;
  try {
    bootstrap = await runBootstrap();
  } catch (error) {
    // Nothing to show the user but the reason. This beats a white screen: it
    // is nearly always a device-storage problem they can act on.
    runApp(StartupFailureApp(error: error));
    return;
  }

  runApp(
    ProviderScope(
      // Built here rather than returned from bootstrap because Riverpod 3
      // does not export the `Override` type, so a List<Override> cannot be
      // named in a signature. Inference handles it fine at this call site.
      overrides: [
        sharedPreferencesProvider.overrideWithValue(bootstrap.preferences),
        settingsControllerProvider.overrideWith(
          () => SettingsController(initial: bootstrap.settings),
        ),
      ],
      child: const VoicelabApp(),
    ),
  );
}
