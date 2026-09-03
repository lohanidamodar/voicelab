import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import '../settings/settings_controller.dart';

/// The shared model store, and what it knows about voices.
///
/// One per machine rather than one per app: these weights are over a gigabyte
/// and identical between our apps, so downloading a second copy would be a
/// gigabyte spent to arrive at the same file.
final voiceCatalogueProvider = Provider<VoiceCatalogue>((ref) {
  final catalogue = VoiceCatalogue();
  ref.onDispose(catalogue.dispose);
  return catalogue;
});

const _keyVoiceModel = 'engine.voiceModel';

/// Which voice the user picked, remembered between runs.
final voiceModelProvider =
    NotifierProvider<VoiceModelController, VoiceModel>(
      VoiceModelController.new,
    );

class VoiceModelController extends Notifier<VoiceModel> {
  @override
  VoiceModel build() {
    final catalogue = ref.watch(voiceCatalogueProvider);
    final saved = ref.watch(sharedPreferencesProvider).getString(_keyVoiceModel);
    // A saved id that is no longer in the catalogue falls back rather than
    // leaving the app with no voice at all — models get renamed and removed,
    // and a stale preference should not be fatal.
    return (saved == null ? null : modelById(saved)) ?? catalogue.defaultVoice;
  }

  void select(VoiceModel model) {
    ref.read(sharedPreferencesProvider).setString(_keyVoiceModel, model.id);
    state = model;
  }
}

/// How a download is going, for the row that started it.
class VoiceDownload {
  const VoiceDownload({required this.modelId, this.fraction = 0, this.error});

  final String modelId;
  final double fraction;
  final String? error;

  int get percent => (fraction * 100).round();
}

final voiceDownloadProvider =
    NotifierProvider<VoiceDownloadController, VoiceDownload?>(
      VoiceDownloadController.new,
    );

/// Downloads a voice, once at a time.
///
/// Serialised on purpose: two of these at once is two gigabytes competing for
/// the same connection, and neither finishes sooner for it.
class VoiceDownloadController extends Notifier<VoiceDownload?> {
  @override
  VoiceDownload? build() => null;

  bool get isBusy => state != null && state!.error == null;

  /// Fetches [model]. [confirmLicence] is asked before any bytes move and a
  /// false answer cancels — the terms are the publisher's, and agreeing to
  /// them is the user's to do, not the app's.
  Future<bool> download(
    VoiceModel model, {
    required Future<bool> Function(VoiceModel) confirmLicence,
  }) async {
    if (isBusy) return false;
    state = VoiceDownload(modelId: model.id);

    try {
      await ref.read(voiceCatalogueProvider).prepare(
            model,
            onLicence: confirmLicence,
            onProgress: (p) =>
                state = VoiceDownload(modelId: model.id, fraction: p.fraction),
          );
      state = null;
      // The catalogue reads the disk, so anything showing installed state has
      // to be told the disk changed.
      ref.invalidate(voiceCatalogueProvider);
      return true;
    } on ModelDeclined {
      state = null;
      return false;
    } catch (e) {
      state = VoiceDownload(modelId: model.id, error: '$e');
      return false;
    }
  }

  void clearError() => state = null;
}
