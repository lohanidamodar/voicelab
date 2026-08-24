import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/config/app_config.dart';
import '../../core/engine/llm_settings.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/ui/feedback.dart';
import '../../core/util/launcher.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/accent_tile.dart';
import 'widgets/language_tile.dart';
import 'widgets/text_scale_tile.dart';
import 'widgets/theme_mode_tile.dart';

/// A titled group of rows on the Settings screen.
class SettingsSection {
  const SettingsSection({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;
}

/// The Settings screen's content, assembled here rather than inline in the
/// screen.
///
/// This is the seam a feature extends: a brick that adds a settings row adds a
/// section here instead of editing the screen's build method, so two features
/// can be added without touching the same lines.
List<SettingsSection> settingsSections(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);

  return [
    SettingsSection(
      title: l10n.settingsAppearance,
      tiles: const [AccentTile(), ThemeModeTile(), TextScaleTile()],
    ),
    SettingsSection(
      title: 'Assistant',
      tiles: [
        Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(llmSettingsProvider);
            return ListTile(
              leading: const Icon(PiconsRegular.sparkle),
              title: const Text('Language model'),
              // The shared package already knows what a provider is missing,
              // so the row says it rather than waiting for a failed turn.
              subtitle: Text(
                settings.config.problem ??
                    '${settings.provider.label} · '
                        '${settings.config.effectiveModel}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushTo(Routes.llm),
            );
          },
        ),
      ],
    ),
    SettingsSection(title: l10n.settingsGeneral, tiles: const [LanguageTile()]),
    SettingsSection(
      title: l10n.settingsAbout,
      tiles: [
        ListTile(
          leading: const Icon(PiconsRegular.info),
          title: Text(l10n.aboutTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushTo(Routes.about),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.shareNetwork),
          title: Text(l10n.aboutShare),
          subtitle: Text(l10n.aboutShareSubtitle),
          onTap: () => Launcher.shareApp(l10n.aboutShareMessage),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.star),
          title: Text(l10n.aboutRate),
          subtitle: Text(l10n.aboutRateSubtitle),
          onTap: () => Launcher.openStoreListing(),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.appWindow),
          title: Text(l10n.aboutMoreApps),
          subtitle: Text(l10n.aboutMoreAppsSubtitle),
          onTap: () => _open(context, AppConfig.moreAppsUrl),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.envelope),
          title: Text(l10n.aboutSupport),
          subtitle: Text(l10n.aboutSupportSubtitle),
          onTap: () => Launcher.emailSupport(subject: l10n.aboutSupportSubject),
        ),
      ],
    ),
  ];
}

Future<void> _open(BuildContext context, String url) async {
  final opened = await Launcher.openUrl(url);
  if (!opened && context.mounted) {
    context.toast(
      AppLocalizations.of(context).errorCouldNotOpen(url),
      isError: true,
    );
  }
}
