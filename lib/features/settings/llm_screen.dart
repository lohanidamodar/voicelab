import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import 'dart:io';

import '../../core/engine/cli_agents.dart';
import '../../core/engine/llm_settings.dart';
import '../../core/ui/views.dart';
import 'widgets/local_server_card.dart';

/// Chooses which model answers, and holds its credentials.
///
/// The provider list, the defaults and the "what is still missing" message all
/// come from `llmProviders` in the shared package, so the app and the CLI
/// offer exactly the same choices.
class LlmScreen extends ConsumerStatefulWidget {
  const LlmScreen({super.key});

  @override
  ConsumerState<LlmScreen> createState() => _LlmScreenState();
}

class _LlmScreenState extends ConsumerState<LlmScreen> {
  final _model = TextEditingController();
  final _key = TextEditingController();
  final _baseUrl = TextEditingController();

  String? _testResult;
  bool _testing = false;

  List<DiscoveredServer>? _found;
  bool _scanning = false;

  /// Which provider the fields currently hold, so switching provider reloads
  /// them rather than writing one provider's key onto another.
  String? _loadedFor;

  @override
  void dispose() {
    _model.dispose();
    _key.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  void _loadFields(LlmSettings settings) {
    if (_loadedFor == settings.providerId) return;
    _loadedFor = settings.providerId;
    _model.text = settings.models[settings.providerId] ?? '';
    _key.text = settings.keys[settings.providerId] ?? '';
    _baseUrl.text = settings.baseUrls[settings.providerId] ?? '';
    _testResult = null;
  }

  Future<void> _test(LlmConfig config) async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final llm = buildLlm(config);
    try {
      final reply = StringBuffer();
      await for (final delta in llm.respond([
        const Message.system('Reply with exactly one short word.'),
        const Message.user('Say hello.'),
      ])) {
        reply.write(delta);
        if (reply.length > 60) break;
      }
      final text = reply.toString().trim();
      setState(
        () => _testResult = text.isEmpty
            // An empty reply is the reasoning-model failure: the whole token
            // budget went on thinking and no content was ever emitted.
            ? 'Connected, but the model returned nothing to say.'
            : 'Replied: $text',
      );
    } on LlmUnreachable catch (e) {
      setState(() => _testResult = '$e');
    } on LlmException catch (e) {
      setState(() => _testResult = 'HTTP ${e.statusCode}: ${_short(e.body)}');
    } catch (e) {
      setState(() => _testResult = '$e');
    } finally {
      await llm.dispose();
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Probes the ports the common local servers use.
  ///
  /// Getting the port wrong is the single most likely reason the assistant
  /// cannot reach a model, and the only symptom is a connection error. Asking
  /// the machine beats asking the user to remember.
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _found = null;
    });
    final found = await discoverLocalLlms();
    if (!mounted) return;
    setState(() {
      _found = found;
      _scanning = false;
    });
  }

  void _use(DiscoveredServer server) {
    final controller = ref.read(llmSettingsProvider.notifier)
      ..selectProvider(server.providerId);
    _loadedFor = server.providerId;
    _baseUrl.text = server.baseUrl;
    controller.setBaseUrl(server.baseUrl);
    if (server.models.isNotEmpty) {
      _model.text = server.models.first;
      controller.setModel(server.models.first);
    }
    setState(() {
      _found = null;
      _testResult = null;
    });
  }

  static String _short(String body) =>
      body.length > 160 ? '${body.substring(0, 160)}…' : body;

  /// Coding CLIs already installed and logged in.
  ///
  /// Offered first because it is the only option that needs no key at all —
  /// and the caveat is stated where it is chosen, not discovered later.
  List<Widget> _cliSection(LlmSettings settings) {
    final agents = ref.watch(cliAgentsProvider);
    final controller = ref.read(llmSettingsProvider.notifier);

    return [
      const SectionLabel('Use a CLI you already have'),
      Text(
        'No API key: the CLI is already signed in. Slower, though — every '
        'turn starts a fresh session, which measured about 5–7 seconds before '
        'the first word here, against a fraction of a second for a local '
        'server.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      agents.when(
        loading: () => const Text('Looking for installed CLIs…'),
        error: (e, _) => Text('Could not look for CLIs: $e'),
        data: (found) => found.isEmpty
            ? Text(
                'None found. Claude Code, Codex or Gemini CLI installed on '
                'this machine — or in a WSL distribution — will appear here.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            : Column(
                children: [
                  RadioGroup<String?>(
                    groupValue: settings.cliAgentId,
                    onChanged: controller.selectCliAgent,
                    child: Column(
                      children: [
                        for (final agent in found)
                          RadioListTile<String?>(
                            value: agent.id,
                            contentPadding: EdgeInsets.zero,
                            title: Text(agent.label),
                            subtitle: Text(
                              '${agent.path}'
                              '${agent.version == null ? '' : '  ·  ${agent.version}'}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (settings.usesCli)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => controller.selectCliAgent(null),
                        child: const Text('Use an API instead'),
                      ),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => ref.invalidate(cliAgentsProvider),
        icon: const Icon(PiconsRegular.arrowsClockwise),
        label: const Text('Look again'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(llmSettingsProvider);
    final controller = ref.read(llmSettingsProvider.notifier);
    final provider = settings.provider;
    _loadFields(settings);

    final config = settings.config;
    final problem = config.problem;

    return Scaffold(
      appBar: AppBar(title: const Text('Language model')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._cliSection(settings),
          const SizedBox(height: 24),
          const SectionLabel('Or use an API'),
          DropdownButtonFormField<String>(
            initialValue: provider.id,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: [
              for (final p in llmProviders)
                DropdownMenuItem(value: p.id, child: Text(p.label)),
            ],
            onChanged: (id) {
              if (id != null) controller.selectProvider(id);
            },
          ),
          const SizedBox(height: 8),
          Text(switch (provider.locality) {
            LlmLocality.onDevice => 'Runs on this device. Nothing leaves it.',
            LlmLocality.selfHosted =>
              'A server you run. Private, but not offline.',
            LlmLocality.cloud =>
              'A third-party API. Audio never leaves the device — the '
                  'transcript does.',
          }, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _model,
            decoration: InputDecoration(
              labelText: 'Model',
              hintText: provider.defaultModel.isEmpty
                  ? 'Required'
                  : provider.defaultModel,
            ),
            onChanged: controller.setModel,
          ),
          if (provider.needsBaseUrl ||
              provider.locality != LlmLocality.cloud) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrl,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: provider.baseUrl.isEmpty
                    ? 'https://host/v1'
                    : provider.baseUrl,
              ),
              onChanged: controller.setBaseUrl,
            ),
          ],
          if (provider.needsApiKey) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API key'),
              onChanged: controller.setApiKey,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton(
                onPressed: _testing || problem != null
                    ? null
                    : () => _test(config),
                child: Text(_testing ? 'Testing…' : 'Test connection'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  // The shared package already knows what is missing; showing
                  // it beside the field beats a failure mid-conversation.
                  problem ?? 'Ready — ${config.effectiveModel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (provider.locality != LlmLocality.cloud &&
              (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) ...[
            const SizedBox(height: 24),
            const LocalServerCard(),
          ],
          const SizedBox(height: 24),
          const SectionLabel('Find a running server'),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: const Icon(PiconsRegular.magnifyingGlass),
                label: Text(_scanning ? 'Scanning…' : 'Scan this machine'),
              ),
            ],
          ),
          if (_found case final found?) ...[
            const SizedBox(height: 8),
            if (found.isEmpty)
              Text(
                'Nothing answered on the usual ports. Start llama.cpp or '
                'Ollama, or enter an address above.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final server in found)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(PiconsRegular.check),
                  title: Text(server.baseUrl),
                  subtitle: Text(
                    server.models.isEmpty
                        ? server.label
                        : '${server.label} · ${server.models.join(', ')}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _use(server),
                    child: const Text('Use'),
                  ),
                ),
          ],
          if (_testResult case final result?) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(result),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
