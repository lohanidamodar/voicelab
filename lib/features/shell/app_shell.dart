import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';

/// One navigation destination.
class ShellDestination {
  const ShellDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The app's navigation chrome.
///
/// Owns the [Scaffold], the [AppBar] and the navigation surfaces; destinations
/// supply body content only. That split is what lets the drawer be reachable
/// from every destination — a nested Scaffold would capture the hamburger and
/// find no drawer on it.
///
/// Adapts by width: a bottom bar on a phone, a rail once there is room.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Destinations, in branch order. Settings is always last — the router
  /// builds its branches in exactly this order.
  static List<ShellDestination> destinationsOf(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      ShellDestination(label: l10n.navClone, icon: PiconsRegular.microphone),
      ShellDestination(label: l10n.navSpeak, icon: PiconsRegular.chat),
      ShellDestination(label: l10n.navSettings, icon: PiconsRegular.gear),
    ];
  }

  void _go(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active destination returns to that branch's root, which
      // is what every platform's tab bar does.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsOf(context);
    final index = navigationShell.currentIndex;
    final useRail = context.useRail;

    return Scaffold(
      appBar: AppBar(title: Text(destinations[index].label)),
      body: Row(
        children: [
          if (useRail) ...[
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: _go,
              labelType: context.isExpanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              extended: context.isExpanded,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: _go,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }
}
