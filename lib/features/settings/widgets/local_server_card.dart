import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import '../../../core/engine/llm_settings.dart';
import '../../../core/engine/local_server.dart';
import '../../../core/ui/views.dart';

/// Runs a llama.cpp server from inside the app, on a model already on disk.
///
/// Desktop only. A phone cannot spawn processes, and the answer there is
/// in-process inference rather than a server.
class LocalServerCard extends ConsumerStatefulWidget {
  const LocalServerCard({super.key});

  @override
  ConsumerState<LocalServerCard> createState() => _LocalServerCardState();
}

class _LocalServerCardState extends ConsumerState<LocalServerCard> {
  bool _busy = false;
  String? _error;
  bool _showAdvanced = false;

  Future<void> _pickBinary() async {
    final file = await openFile(
      acceptedTypeGroups: [
        if (Platform.isWindows)
          const XTypeGroup(label: 'Programs', extensions: ['exe'])
        else
          const XTypeGroup(label: 'Programs'),
      ],
    );
    if (file != null) {
      ref.read(localServerSettingsProvider.notifier).setBinary(file.path);
    }
  }

  Future<void> _pickModelFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'GGUF models', extensions: ['gguf']),
      ],
    );
    if (file != null) {
      ref.read(localServerSettingsProvider.notifier).setModel(file.path);
    }
  }

  Future<void> _start() async {
    final settings = ref.read(localServerSettingsProvider);
    final server = ref.read(managedServerProvider);
    final (executable, leadingArgs) = settings.command;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final baseUrl = await server.start(
        executable: executable,
        leadingArgs: leadingArgs,
        modelPath: settings.modelPath,
        port: settings.port,
        extraArgs: ['-t', '${settings.threads}'],
        // Paths inside a launcher's filesystem cannot be checked from here.
        verifyPaths: !settings.usesLauncher,
      );
      // Point the assistant at the server that was just started, so there is
      // no second step where the user has to retype the address.
      ref.read(llmSettingsProvider.notifier)
        ..selectProvider('llamacpp')
        ..setBaseUrl(baseUrl)
        ..setModel(settings.modelPath.split(Platform.pathSeparator).last);
    } on ManagedServerException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await ref.read(managedServerProvider).stop();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(localServerSettingsProvider);
    final controller = ref.read(localServerSettingsProvider.notifier);
    final status =
        ref.watch(serverStatusProvider).value ??
        ref.watch(managedServerProvider).current;
    final running = status.isRunning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Run a server here'),
        Text(
          'Starts llama.cpp on a model already on this machine, and points the '
          'assistant at it. The server stops when the app closes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _pathRow(
          label: 'Server binary',
          value: settings.binaryPath,
          hint: Platform.isWindows ? 'llama-server.exe' : 'llama-server',
          onBrowse: running ? null : _pickBinary,
          onCleared: running ? null : () => controller.setBinary(''),
        ),
        const SizedBox(height: 12),
        _modelRow(settings, controller, running),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: '${settings.port}',
                enabled: !running,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final port = int.tryParse(v);
                  if (port != null) controller.setPort(port);
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: '${settings.threads}',
                enabled: !running,
                decoration: const InputDecoration(labelText: 'Threads'),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final t = int.tryParse(v);
                  if (t != null && t > 0) controller.setThreads(t);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Text(_showAdvanced ? 'Hide launcher' : 'Binary is not native'),
        ),
        if (_showAdvanced) ...[
          Text(
            'For a server built for another platform — a llama.cpp inside WSL '
            'run from Windows. The binary and model paths are then the ones '
            'that launcher sees, and are not checked before starting.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: settings.launcher,
            enabled: !running,
            decoration: const InputDecoration(
              labelText: 'Launcher',
              hintText: r'C:\Windows\System32\wsl.exe',
            ),
            onChanged: controller.setLauncher,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: settings.launcherArgs,
            enabled: !running,
            decoration: const InputDecoration(
              labelText: 'Launcher arguments',
              hintText: '-e',
            ),
            onChanged: controller.setLauncherArgs,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (running)
              FilledButton.icon(
                onPressed: _busy ? null : _stop,
                icon: const Icon(PiconsRegular.stop),
                label: const Text('Stop server'),
              )
            else
              FilledButton.icon(
                onPressed: _busy || settings.problem != null ? null : _start,
                icon: const Icon(PiconsRegular.play),
                label: Text(_busy ? 'Starting…' : 'Start server'),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error ?? settings.problem ?? '$status',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          // The process printed why it died; that is the only useful thing to
          // show, so it is shown rather than summarised away.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                ref.read(managedServerProvider).recentOutput.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pathRow({
    required String label,
    required String value,
    required String hint,
    required VoidCallback? onBrowse,
    required VoidCallback? onCleared,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            value.isEmpty ? hint : value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value.isEmpty
                  ? Theme.of(context).hintColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      TextButton(onPressed: onBrowse, child: const Text('Browse')),
      if (value.isNotEmpty)
        IconButton(
          icon: const Icon(PiconsRegular.x, size: 18),
          onPressed: onCleared,
        ),
    ],
  );

  /// The model row offers what is already on the machine first, and a file
  /// picker second — nobody wants to navigate to a path they already have.
  Widget _modelRow(
    LocalServerSettings settings,
    LocalServerSettingsController controller,
    bool running,
  ) {
    final models = ref.watch(localModelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pathRow(
          label: 'Model',
          value: settings.modelPath,
          hint: 'a .gguf file',
          onBrowse: running ? null : _pickModelFile,
          onCleared: running ? null : () => controller.setModel(''),
        ),
        const SizedBox(height: 8),
        models.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Looking for models…'),
          ),
          error: (e, _) => Text('Could not search for models: $e'),
          data: (found) => found.isEmpty
              ? Text(
                  'No .gguf files found in the usual places.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final model in found)
                      ChoiceChip(
                        selected: settings.modelPath == model.path,
                        onSelected: running
                            ? null
                            : (_) => controller.setModel(model.path),
                        label: Text(
                          '${model.name} · ${model.sizeLabel}'
                          '${model.quantisation == null ? '' : ' · ${model.quantisation}'}',
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(
                        PiconsRegular.arrowsClockwise,
                        size: 16,
                      ),
                      label: const Text('Rescan'),
                      onPressed: () => ref.invalidate(localModelsProvider),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
