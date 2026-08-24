import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/clone/clone_screen.dart';
import '../../features/speak/speak_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/llm_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import 'routes.dart';

/// Root navigator key. Routes that should cover the shell (full-screen forms,
/// detail pages) set `parentNavigatorKey: rootNavigatorKey`.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.initial,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.clone,
                builder: (_, _) => const CloneScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.speak,
                builder: (_, _) => const SpeakScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'about',
                    // Over the shell, not inside it: About is a leaf page, and
                    // keeping the nav bar under it invites tapping away
                    // mid-read.
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: 'llm',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const LlmScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
