import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

/// The saved voices, kept in application support rather than a cache
/// directory — the OS is free to empty the latter, and a voice that quietly
/// stops existing is worse than one that was never saved.
final voiceLibraryProvider = FutureProvider<VoiceLibrary>((ref) async {
  final base = await getApplicationSupportDirectory();
  final library = VoiceLibrary(Directory('${base.path}/voices'));
  await library.load();
  return library;
});

/// Which voice replies are spoken in. Defaults to the model's own speaker, so
/// the app is usable before anything has been recorded.
final selectedVoiceProvider = NotifierProvider<SelectedVoice, VoiceProfile>(
  SelectedVoice.new,
);

class SelectedVoice extends Notifier<VoiceProfile> {
  @override
  VoiceProfile build() => VoiceProfile.builtIn;

  void select(VoiceProfile profile) => state = profile;

  /// Falls back to the built-in voice when the current one is deleted.
  void forget(String id) {
    if (state.id == id) state = VoiceProfile.builtIn;
  }
}
