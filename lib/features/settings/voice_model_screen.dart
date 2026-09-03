import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import '../../core/engine/voice_model_settings.dart';

/// Choosing which voice speaks, and downloading it.
///
/// Every row states its size and its licence before anything is fetched. The
/// weights are somebody else's work under somebody else's terms, so the
/// decision to accept them is put in front of the person making it rather
/// than buried in a README.
class VoiceModelScreen extends ConsumerWidget {
  const VoiceModelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(voiceCatalogueProvider);
    final selected = ref.watch(voiceModelProvider);
    final download = ref.watch(voiceDownloadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voice model')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final voice in catalogue.voices)
            _VoiceTile(
              voice: voice,
              installed: catalogue.has(voice),
              selected: voice.id == selected.id,
              download: download?.modelId == voice.id ? download : null,
            ),
          const _StoreFooter(),
        ],
      ),
    );
  }
}

class _VoiceTile extends ConsumerWidget {
  const _VoiceTile({
    required this.voice,
    required this.installed,
    required this.selected,
    this.download,
  });

  final VoiceModel voice;
  final bool installed;
  final bool selected;
  final VoiceDownload? download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final busy = download != null && download!.error == null;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : () => _use(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? PiconsFill.checkCircle
                        : PiconsRegular.speakerHigh,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(voice.name, style: theme.textTheme.titleMedium),
                  ),
                  Text(voice.sizeLabel, style: theme.textTheme.labelMedium),
                ],
              ),
              if (voice.notes case final notes?) ...[
                const SizedBox(height: 8),
                Text(notes, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Chip(voice.licence.summary, icon: PiconsRegular.scales),
                  if (voice.canDesignVoice)
                    const _Chip('Describe a voice', icon: PiconsRegular.pen),
                  if (voice.canCloneVoice)
                    const _Chip('Clone a voice', icon: PiconsRegular.microphone),
                  _Chip(
                    voice.languages.contains('*')
                        ? 'Any language'
                        : '${voice.languages.length} languages',
                    icon: PiconsRegular.globe,
                  ),
                ],
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: download!.fraction),
                const SizedBox(height: 6),
                Text(
                  'Downloading — ${download!.percent}%',
                  style: theme.textTheme.labelSmall,
                ),
              ] else if (download?.error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      installed ? 'Downloaded' : 'Not downloaded',
                      style: theme.textTheme.labelSmall,
                    ),
                    const Spacer(),
                    if (selected)
                      const Text('In use')
                    else
                      FilledButton.tonal(
                        onPressed: () => _use(context, ref),
                        child: Text(installed ? 'Use' : 'Download and use'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _use(BuildContext context, WidgetRef ref) async {
    if (installed) {
      ref.read(voiceModelProvider.notifier).select(voice);
      return;
    }

    final ok = await ref.read(voiceDownloadProvider.notifier).download(
          voice,
          confirmLicence: (model) => _askLicence(context, model),
        );
    if (ok && context.mounted) {
      ref.read(voiceModelProvider.notifier).select(voice);
    }
  }

  /// Shows the terms and waits for an answer, before a byte is fetched.
  Future<bool> _askLicence(BuildContext context, VoiceModel model) async {
    if (!context.mounted) return false;
    final theme = Theme.of(context);

    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download ${model.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${model.sizeLabel} from ${Uri.parse(model.source).host}.'),
            const SizedBox(height: 16),
            Text('Licence', style: theme.textTheme.labelLarge),
            Text(model.licence.name),
            const SizedBox(height: 4),
            Text(model.licence.url, style: theme.textTheme.bodySmall),
            if (model.licence.notes case final notes?) ...[
              const SizedBox(height: 12),
              Text(notes, style: theme.textTheme.bodySmall),
            ],
            if (model.licence.attribution case final credit?) ...[
              const SizedBox(height: 12),
              Text(
                'Credit required: $credit',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Agree and download'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Where the weights are, and that they are shared.
class _StoreFooter extends ConsumerWidget {
  const _StoreFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(voiceCatalogueProvider).store;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Text(
        'Models are kept in ${store.root.path}, shared with the other PopupBits '
        'apps, so a voice is downloaded once for the machine rather than once '
        'per app. Nothing here is bundled with the app: each model is fetched '
        'from its publisher under the licence shown.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
