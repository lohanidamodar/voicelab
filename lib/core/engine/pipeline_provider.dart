import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import 'cli_agents.dart';
import 'engine_provider.dart';
import 'llm_settings.dart';
import 'voice_library_provider.dart';

/// How the assistant is configured. Changing any of it rebuilds the pipeline,
/// which is why it is a small value type rather than scattered providers.
class AssistantConfig {
  const AssistantConfig({
    this.language = PipelineLanguage.nepali,
    this.autoLanguage = true,
    this.useClonedVoice = false,
  });

  final PipelineLanguage language;
  final bool autoLanguage;

  /// Answer in the selected voice from the library rather than the built-in
  /// sherpa voices. Costs the clone engine's warm-up and is far slower without
  /// a GPU backend.
  final bool useClonedVoice;

  AssistantConfig copyWith({
    PipelineLanguage? language,
    bool? autoLanguage,
    bool? useClonedVoice,
  }) => AssistantConfig(
    language: language ?? this.language,
    autoLanguage: autoLanguage ?? this.autoLanguage,
    useClonedVoice: useClonedVoice ?? this.useClonedVoice,
  );
}

final assistantConfigProvider =
    NotifierProvider<AssistantConfigController, AssistantConfig>(
      AssistantConfigController.new,
    );

class AssistantConfigController extends Notifier<AssistantConfig> {
  @override
  AssistantConfig build() => const AssistantConfig();

  void setLanguage(PipelineLanguage l) => state = state.copyWith(language: l);
  void setAuto(bool v) => state = state.copyWith(autoLanguage: v);
  void setClonedVoice(bool v) => state = state.copyWith(useClonedVoice: v);
}

/// Whatever the pipeline last reported about routing, for the status line.
final pipelineNoticeProvider = NotifierProvider<PipelineNotice, String?>(
  PipelineNotice.new,
);

class PipelineNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;
  void clear() => state = null;
}

/// The assembled VAD → STT → LLM → TTS pipeline.
///
/// Built through the same [PipelineSetup] the CLI uses, so the app cannot
/// drift from it. Rebuilt whenever the model, the voice or the language mode
/// changes — loading recognisers takes seconds, so this is not watched from a
/// hot path.
final speechPipelineProvider = FutureProvider<SpeechPipeline>((ref) async {
  final paths = ref.watch(enginePathsProvider);
  if (paths == null) {
    throw const PipelineUnavailable(
      'No models configured. Pass --dart-define=VOICELAB_MODELS=<dir>.',
    );
  }
  if (paths.sttModelsDir == null) {
    throw const PipelineUnavailable(
      'The assistant needs the sherpa model directory. '
      'Pass --dart-define=VOICELAB_MODELS=<dir>.',
    );
  }

  final config = ref.watch(assistantConfigProvider);
  final settings = ref.watch(llmSettingsProvider);

  // A chosen CLI wins over the API settings. It is resolved here rather than
  // stored whole, because the CLI may have been uninstalled since it was
  // picked and a stale path fails mid-conversation.
  LlmEngine? cliEngine;
  if (settings.cliAgentId case final wanted?) {
    final agents = await ref.watch(cliAgentsProvider.future);
    final agent = agents.where((a) => a.id == wanted).firstOrNull;
    if (agent == null) {
      throw PipelineUnavailable(
        'The CLI "$wanted" is no longer installed. Pick another in settings.',
      );
    }
    cliEngine = CliLlmEngine(agent);
  }

  final llm = settings.config;
  if (cliEngine == null && llm.problem != null) {
    throw PipelineUnavailable(llm.problem!);
  }

  // Only pay for the clone engine when the user actually asked to be answered
  // in a cloned voice — it costs weight loading and, on a GPU, shader
  // compilation.
  CloneService? clone;
  VoiceProfile? voice;
  if (config.useClonedVoice) {
    final selected = ref.watch(selectedVoiceProvider);
    if (selected.isCloned) {
      voice = selected;
      clone = await ref.watch(cloneServiceProvider.future);
    }
  }

  final setup = PipelineSetup(
    language: config.language,
    autoLanguage: config.autoLanguage && clone == null,
    modelsDir: paths.sttModelsDir,
    nativeLibraryPath: paths.sherpaLibraryPath,
    llm: llm,
    llmEngine: cliEngine,
    cloneService: clone,
    voiceProfile: voice,
    onLanguageDetected: ref.read(pipelineNoticeProvider.notifier).show,
    onScriptRepair: (r) => ref
        .read(pipelineNoticeProvider.notifier)
        .show('repaired script: ${r.summary}'),
  );

  final pipeline = await setup.build();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

/// A configuration problem the user can fix, as opposed to a crash.
class PipelineUnavailable implements Exception {
  const PipelineUnavailable(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Where recorded and synthesised audio is written for playback.
Future<Directory> assistantScratch() async => Directory.systemTemp;
