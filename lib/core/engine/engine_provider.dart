import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import 'voice_model_settings.dart';

/// Where the native library and models live.
///
/// Desktop reads them from disk next to the build; on Android the .so ships in
/// the APK and the loader finds it by name, so no directory is given.
class EnginePaths {
  const EnginePaths({
    required this.modelPath,
    this.libraryPath,
    this.sttModelsDir,
    this.sherpaLibraryPath,
    this.family = 'omnivoice',
    this.backend = AcBackend.best,
  });

  final String modelPath;
  final String? libraryPath;
  final String? sttModelsDir;
  final String? sherpaLibraryPath;
  final String family;
  final AcBackend backend;

  /// Development defaults. A shipped build would resolve these from bundled
  /// assets or a download, not hardcoded paths.
  static EnginePaths? fromEnvironment() {
    const model = String.fromEnvironment('VOICELAB_MODEL');
    if (model.isEmpty || !File(model).existsSync()) return null;
    return EnginePaths(
      modelPath: model,
      libraryPath: _orNull(const String.fromEnvironment('VOICELAB_LIB')),
      sttModelsDir: _orNull(const String.fromEnvironment('VOICELAB_MODELS')),
      sherpaLibraryPath: _orNull(
        const String.fromEnvironment('VOICELAB_SHERPA'),
      ),
      backend: AcBackend.values.byName(
        const String.fromEnvironment('VOICELAB_BACKEND', defaultValue: 'best'),
      ),
    );
  }

  static String? _orNull(String v) => v.isEmpty ? null : v;
}

final enginePathsProvider = Provider<EnginePaths?>(
  (ref) => EnginePaths.fromEnvironment(),
);

/// The engine, started once and shared.
///
/// Loading weights and compiling GPU pipelines costs seconds, so this is kept
/// alive for the life of the app rather than per screen.
final cloneServiceProvider = FutureProvider<CloneService>((ref) async {
  final paths = ref.watch(enginePathsProvider);

  // The chosen voice wins: it is downloaded, its licence was accepted, and it
  // knows its own family. The dart-defines stay as the escape hatch for a
  // model that is not in the catalogue yet.
  final chosen = ref.watch(voiceModelProvider);
  final catalogue = ref.watch(voiceCatalogueProvider);

  String modelPath;
  String family;
  if (catalogue.has(chosen)) {
    final setup = await catalogue.prepare(chosen);
    modelPath = setup.modelPath;
    family = setup.family;
  } else if (paths != null) {
    modelPath = paths.modelPath;
    family = paths.family;
  } else {
    throw CloneException(
      'No voice downloaded yet. Settings › Voice model, or pass '
      '--dart-define=VOICELAB_MODEL=<path to gguf>.',
    );
  }

  final service = await CloneService.start(
    modelPath: modelPath,
    family: family,
    libraryPath: paths?.libraryPath,
    backend: paths?.backend ?? AcBackend.best,
    sttModelsDir: paths?.sttModelsDir,
    sherpaLibraryPath: paths?.sherpaLibraryPath,
  );
  ref.onDispose(service.dispose);
  return service;
});
