import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import '../settings/settings_controller.dart';

/// Which model answers, and the credentials for it.
///
/// Keys are per provider, not global: switching from OpenAI to a local server
/// and back should not lose the key that was already working.
class LlmSettings {
  const LlmSettings({
    this.providerId = 'llamacpp',
    this.models = const {},
    this.keys = const {},
    this.baseUrls = const {},
    this.cliAgentId,
  });

  final String providerId;

  /// A coding CLI to answer through instead of an API, by [CliAgent.id].
  ///
  /// Its appeal is that it needs no key: someone already using `claude` or
  /// `codex` has logged in. Its cost is several seconds before the first word,
  /// because every turn is a fresh session.
  final String? cliAgentId;

  bool get usesCli => cliAgentId != null;
  final Map<String, String> models;
  final Map<String, String> keys;
  final Map<String, String> baseUrls;

  LlmProvider get provider => llmProviderById(providerId) ?? llmProviders.first;

  LlmConfig get config => LlmConfig(
    provider: provider,
    model: models[providerId],
    apiKey: keys[providerId],
    baseUrl: baseUrls[providerId],
    // A voice reply is one or two sentences. A large budget only buys a
    // longer wait before the first word is spoken.
    maxTokens: 160,
  );

  LlmSettings copyWith({
    String? providerId,
    Map<String, String>? models,
    Map<String, String>? keys,
    Map<String, String>? baseUrls,
    String? cliAgentId,
    bool clearCliAgent = false,
  }) => LlmSettings(
    providerId: providerId ?? this.providerId,
    models: models ?? this.models,
    keys: keys ?? this.keys,
    baseUrls: baseUrls ?? this.baseUrls,
    cliAgentId: clearCliAgent ? null : (cliAgentId ?? this.cliAgentId),
  );
}

const _keyProvider = 'llm.provider';
const _keyCliAgent = 'llm.cliAgent';
const _prefixModel = 'llm.model.';
const _prefixKey = 'llm.key.';
const _prefixBaseUrl = 'llm.baseUrl.';

final llmSettingsProvider =
    NotifierProvider<LlmSettingsController, LlmSettings>(
      LlmSettingsController.new,
    );

class LlmSettingsController extends Notifier<LlmSettings> {
  @override
  LlmSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final models = <String, String>{};
    final keys = <String, String>{};
    final baseUrls = <String, String>{};
    for (final p in llmProviders) {
      final model = prefs.getString('$_prefixModel${p.id}');
      final key = prefs.getString('$_prefixKey${p.id}');
      final url = prefs.getString('$_prefixBaseUrl${p.id}');
      if (model != null) models[p.id] = model;
      if (key != null) keys[p.id] = key;
      if (url != null) baseUrls[p.id] = url;
    }
    return LlmSettings(
      providerId: prefs.getString(_keyProvider) ?? 'llamacpp',
      cliAgentId: prefs.getString(_keyCliAgent),
      models: models,
      keys: keys,
      baseUrls: baseUrls,
    );
  }

  void selectProvider(String id) {
    final prefs = ref.read(sharedPreferencesProvider)
      ..setString(_keyProvider, id)
      // Choosing an API provider means not going through a CLI; leaving both
      // set would make which one answers a matter of read order.
      ..remove(_keyCliAgent);
    state = state.copyWith(providerId: id, clearCliAgent: true);
    prefs;
  }

  void selectCliAgent(String? id) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (id == null) {
      prefs.remove(_keyCliAgent);
      state = state.copyWith(clearCliAgent: true);
    } else {
      prefs.setString(_keyCliAgent, id);
      state = state.copyWith(cliAgentId: id);
    }
  }

  void setModel(String value) =>
      _put(_prefixModel, value, (m) => state.copyWith(models: m), state.models);

  void setApiKey(String value) =>
      _put(_prefixKey, value, (m) => state.copyWith(keys: m), state.keys);

  void setBaseUrl(String value) => _put(
    _prefixBaseUrl,
    value,
    (m) => state.copyWith(baseUrls: m),
    state.baseUrls,
  );

  void _put(
    String prefix,
    String value,
    LlmSettings Function(Map<String, String>) apply,
    Map<String, String> current,
  ) {
    final prefs = ref.read(sharedPreferencesProvider);
    final key = '$prefix${state.providerId}';
    final next = Map.of(current);
    if (value.trim().isEmpty) {
      next.remove(state.providerId);
      prefs.remove(key);
    } else {
      next[state.providerId] = value.trim();
      prefs.setString(key, value.trim());
    }
    state = apply(next);
  }
}
