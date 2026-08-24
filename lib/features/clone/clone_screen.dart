import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picons/picons.dart';
import 'package:record/record.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import '../../core/engine/engine_provider.dart';
import '../../core/engine/voice_library_provider.dart';
import '../../core/ui/views.dart';

/// Pick a voice, or record a new one, then hear the model speak in it.
///
/// The screen holds no engine logic: everything native is behind
/// [CloneService] and [VoiceLibrary] in the shared package, which the CLI and
/// local server drive identically.
class CloneScreen extends ConsumerStatefulWidget {
  const CloneScreen({super.key});

  @override
  ConsumerState<CloneScreen> createState() => _CloneScreenState();
}

class _CloneScreenState extends ConsumerState<CloneScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _text = TextEditingController(text: 'नमस्ते। मेरो नाम राम हो।');
  final _refText = TextEditingController();
  final _name = TextEditingController();

  /// Non-null while a new voice is being recorded and named.
  String? _draftPath;

  bool _recording = false;
  bool _busy = false;
  String _status = '';
  String _language = 'ne';
  SynthesisResult? _result;
  String? _outPath;
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    _recorder.dispose();
    _text.dispose();
    _refText.dispose();
    _name.dispose();
    super.dispose();
  }

  // ─── recording a new voice ─────────────────────────────

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _draftPath = path;
      });
      if (path != null) await _transcribe(path);
      return;
    }

    if (!await _recorder.hasPermission()) {
      setState(() => _status = 'Microphone permission denied.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/ref_${DateTime.now().millisecondsSinceEpoch}.wav';
    // The engines want 16-bit PCM; recording straight to WAV avoids any
    // transcoding step on device.
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, numChannels: 1),
      path: path,
    );
    setState(() {
      _recording = true;
      _status = 'Recording…';
      _result = null;
    });
  }

  /// Fills the reference transcript in. It measurably improves the clone, and
  /// nobody wants to type Devanagari on a phone.
  Future<void> _transcribe(String path) async {
    final service = ref.read(cloneServiceProvider).value;
    if (service == null) return;
    setState(() => _status = 'Transcribing…');
    try {
      final (samples, rate) = decodeWav(await File(path).readAsBytes());
      if (samples.isEmpty) {
        setState(() => _status = 'Could not read the recording.');
        return;
      }
      final text = await service.transcribe(samples, rate, language: _language);
      setState(() {
        if (text.isNotEmpty) _refText.text = text;
        _status = text.isEmpty ? 'No speech recognised.' : 'Name it and save.';
      });
    } on CloneException catch (e) {
      setState(() => _status = e.message);
    }
  }

  Future<void> _saveVoice() async {
    final path = _draftPath;
    final library = ref.read(voiceLibraryProvider).value;
    if (path == null || library == null) return;

    final profile = await library.addFromFile(
      name: _name.text.trim().isEmpty ? 'Voice' : _name.text.trim(),
      wavPath: path,
      transcript: _refText.text.trim().isEmpty ? null : _refText.text.trim(),
      language: _language,
    );
    ref.read(selectedVoiceProvider.notifier).select(profile);
    setState(() {
      _draftPath = null;
      _name.clear();
      _refText.clear();
      _status = 'Saved "${profile.name}".';
    });
  }

  void _discardDraft() => setState(() {
    _draftPath = null;
    _name.clear();
    _refText.clear();
    _status = '';
  });

  Future<void> _deleteVoice(VoiceProfile profile) async {
    final library = ref.read(voiceLibraryProvider).value;
    if (library == null) return;
    await library.remove(profile.id);
    ref.read(selectedVoiceProvider.notifier).forget(profile.id);
    setState(() => _status = 'Removed "${profile.name}".');
  }

  // ─── speaking ──────────────────────────────────────────

  Future<void> _speak() async {
    final service = ref.read(cloneServiceProvider).value;
    if (service == null) return;
    final voice = ref.read(selectedVoiceProvider);

    setState(() {
      _busy = true;
      _status = voice.isCloned ? 'Speaking as ${voice.name}…' : 'Speaking…';
    });
    try {
      final result = await service.speak(
        _text.text,
        // The pipeline speaks ISO 639-1; OmniVoice's table is 639-3, where
        // Nepali is `npi` and `ne` is rejected outright.
        language: CloneTtsEngine.engineLanguageFor(_language),
        refWavPath: voice.referenceWavPath,
        refText: voice.hasTranscript ? voice.transcript : null,
      );
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/out_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(path)
          .writeAsBytes(encodeWav(result.samples, result.sampleRate));
      setState(() {
        _result = result;
        _outPath = path;
        _status = 'Done.';
      });
      await _play();
    } on CloneException catch (e) {
      setState(() => _status = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _play() async {
    final path = _outPath;
    if (path == null) return;
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    // DeviceFileSource rather than bytes: the player streams from disk, and
    // the file is already written for sharing or inspection anyway.
    await _player.play(DeviceFileSource(path));

    // Reset from the known duration rather than onPlayerComplete: the Windows
    // plugin posts completion events off the platform thread, which Flutter
    // warns about and which crashed the app here.
    final secs = _result?.seconds ?? 0;
    if (secs > 0) {
      await Future<void>.delayed(
        Duration(milliseconds: (secs * 1000).round() + 200),
      );
      if (mounted && _playing) setState(() => _playing = false);
    }
  }

  Future<void> _playFile(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  // ─── build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(cloneServiceProvider);

    return engine.when(
      loading: () => const LoadingView(),
      error: (e, _) =>
          ErrorView(message: e is CloneException ? e.message : '$e'),
      data: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._voiceSection(),
          const SizedBox(height: 24),
          const SectionLabel('Text to speak'),
          TextField(
            controller: _text,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Text'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ne', label: Text('Nepali')),
              ButtonSegment(value: 'sa', label: Text('Sanskrit')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {_language},
            onSelectionChanged: (s) => setState(() => _language = s.first),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || _draftPath != null ? null : _speak,
            icon: const Icon(PiconsRegular.play),
            label: Text('Speak as ${ref.watch(selectedVoiceProvider).name}'),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_result case final r?) ...[
            const SizedBox(height: 16),
            const SectionLabel('Result'),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _play,
                  icon: Icon(
                    _playing ? PiconsRegular.stop : PiconsRegular.play,
                  ),
                  label: Text(_playing ? 'Stop' : 'Play'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${r.seconds.toStringAsFixed(2)}s · '
                    '${r.elapsed.inMilliseconds}ms · '
                    'RTF ${r.realTimeFactor.toStringAsFixed(3)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _voiceSection() {
    if (_draftPath != null || _recording) return _draftSection();

    final library = ref.watch(voiceLibraryProvider).value;
    final selected = ref.watch(selectedVoiceProvider);
    final voices = library?.profiles ?? [VoiceProfile.builtIn];

    return [
      const SectionLabel('Voice'),
      RadioGroup<String>(
        groupValue: selected.id,
        // RadioGroup requires a handler, so the busy guard lives inside it
        // rather than disabling the callback.
        onChanged: (id) {
          if (_busy || id == null) return;
          final picked = voices.firstWhere((v) => v.id == id);
          ref.read(selectedVoiceProvider.notifier).select(picked);
        },
        child: Column(
          children: [
            for (final v in voices)
              RadioListTile<String>(
                value: v.id,
                contentPadding: EdgeInsets.zero,
                title: Text(v.name),
                subtitle: v.isCloned
                    ? Text(
                        v.hasTranscript ? v.transcript! : 'No reference transcript — the clone will be weaker',
                      )
                    : const Text("The model's own speaker"),
                secondary: v.isCloned
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Play reference',
                            icon: const Icon(PiconsRegular.play),
                            onPressed: () => _playFile(v.referenceWavPath!),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(PiconsRegular.trash),
                            onPressed: _busy ? null : () => _deleteVoice(v),
                          ),
                        ],
                      )
                    : null,
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _toggleRecord,
        icon: const Icon(PiconsRegular.microphone),
        label: const Text('Add a voice'),
      ),
    ];
  }

  List<Widget> _draftSection() => [
    const SectionLabel('New voice'),
    Row(
      children: [
        FilledButton.icon(
          onPressed: _toggleRecord,
          icon: Icon(
            _recording ? PiconsRegular.stop : PiconsRegular.microphone,
          ),
          label: Text(_recording ? 'Stop' : 'Re-record'),
        ),
        const SizedBox(width: 12),
        if (_draftPath != null && !_recording)
          OutlinedButton.icon(
            onPressed: () => _playFile(_draftPath!),
            icon: const Icon(PiconsRegular.play),
            label: const Text('Play'),
          ),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _name,
      decoration: const InputDecoration(
        labelText: 'Voice name',
        helperText: 'Anyone can be cloned — yours, a friend, a narrator',
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _refText,
      decoration: const InputDecoration(
        labelText: 'What the recording says',
        helperText: 'Filled in automatically; edit if it misheard',
      ),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        FilledButton(
          onPressed: _draftPath == null || _recording ? null : _saveVoice,
          child: const Text('Save voice'),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: _recording ? null : _discardDraft,
          child: const Text('Cancel'),
        ),
      ],
    ),
    if (_status.isNotEmpty) ...[
      const SizedBox(height: 12),
      Text(_status, style: Theme.of(context).textTheme.bodySmall),
    ],
  ];
}
