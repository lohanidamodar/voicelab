import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import '../settings/settings_controller.dart';

/// How to launch a local inference server.
///
/// [launcher] exists for the case where the binary is not native to the app's
/// platform — a llama.cpp built inside WSL, run from a Windows app as
/// `wsl.exe -e /home/you/.../llama-server`. When it is set, paths are not
/// checked before launching: they live in the launcher's filesystem, which
/// this process cannot see.
class LocalServerSettings {
  const LocalServerSettings({
    this.binaryPath = '',
    this.modelPath = '',
    this.port = 8080,
    this.launcher = '',
    this.launcherArgs = '',
    this.threads = 8,
  });

  final String binaryPath;
  final String modelPath;
  final int port;
  final String launcher;
  final String launcherArgs;
  final int threads;

  bool get usesLauncher => launcher.trim().isNotEmpty;

  /// What actually gets executed, and what goes in front of the server flags.
  (String executable, List<String> leadingArgs) get command => usesLauncher
      ? (
          launcher.trim(),
          [
            ...launcherArgs
                .trim()
                .split(RegExp(r'\s+'))
                .where((a) => a.isNotEmpty),
            binaryPath.trim(),
          ],
        )
      : (binaryPath.trim(), const <String>[]);

  String? get problem {
    if (binaryPath.trim().isEmpty) return 'Choose a server binary.';
    if (modelPath.trim().isEmpty) return 'Choose a model file.';
    if (port <= 0 || port > 65535) return 'Port must be 1–65535.';
    return null;
  }

  String get baseUrl => 'http://127.0.0.1:$port/v1';

  LocalServerSettings copyWith({
    String? binaryPath,
    String? modelPath,
    int? port,
    String? launcher,
    String? launcherArgs,
    int? threads,
  }) => LocalServerSettings(
    binaryPath: binaryPath ?? this.binaryPath,
    modelPath: modelPath ?? this.modelPath,
    port: port ?? this.port,
    launcher: launcher ?? this.launcher,
    launcherArgs: launcherArgs ?? this.launcherArgs,
    threads: threads ?? this.threads,
  );
}

const _keyBinary = 'server.binary';
const _keyModel = 'server.model';
const _keyPort = 'server.port';
const _keyLauncher = 'server.launcher';
const _keyLauncherArgs = 'server.launcherArgs';
const _keyThreads = 'server.threads';

final localServerSettingsProvider =
    NotifierProvider<LocalServerSettingsController, LocalServerSettings>(
      LocalServerSettingsController.new,
    );

class LocalServerSettingsController extends Notifier<LocalServerSettings> {
  @override
  LocalServerSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return LocalServerSettings(
      binaryPath: prefs.getString(_keyBinary) ?? '',
      modelPath: prefs.getString(_keyModel) ?? '',
      port: prefs.getInt(_keyPort) ?? 8080,
      launcher: prefs.getString(_keyLauncher) ?? '',
      launcherArgs: prefs.getString(_keyLauncherArgs) ?? '',
      threads: prefs.getInt(_keyThreads) ?? 8,
    );
  }

  void setBinary(String v) =>
      _string(_keyBinary, v, (s) => state.copyWith(binaryPath: s));
  void setModel(String v) =>
      _string(_keyModel, v, (s) => state.copyWith(modelPath: s));
  void setLauncher(String v) =>
      _string(_keyLauncher, v, (s) => state.copyWith(launcher: s));
  void setLauncherArgs(String v) =>
      _string(_keyLauncherArgs, v, (s) => state.copyWith(launcherArgs: s));

  void setPort(int v) {
    ref.read(sharedPreferencesProvider).setInt(_keyPort, v);
    state = state.copyWith(port: v);
  }

  void setThreads(int v) {
    ref.read(sharedPreferencesProvider).setInt(_keyThreads, v);
    state = state.copyWith(threads: v);
  }

  void _string(
    String key,
    String value,
    LocalServerSettings Function(String) apply,
  ) {
    ref.read(sharedPreferencesProvider).setString(key, value.trim());
    state = apply(value.trim());
  }
}

/// The server process, owned for the life of the app.
///
/// Disposed with the provider container, so quitting the app takes the server
/// with it — several gigabytes of weights left running is not something anyone
/// notices until the machine is out of memory.
final managedServerProvider = Provider<ManagedLlmServer>((ref) {
  final server = ManagedLlmServer();
  ref.onDispose(server.dispose);
  return server;
});

final serverStatusProvider = StreamProvider<ServerStatus>((ref) {
  final server = ref.watch(managedServerProvider);
  return server.status.map((s) => s);
});

/// GGUF files already on this machine.
///
/// Scanning the disk is slow enough to be worth caching, and the answer only
/// changes when the user downloads something — so it is refreshed on demand
/// rather than watched.
final localModelsProvider = FutureProvider<List<LocalModel>>(
  (ref) => findLocalModels(),
);
