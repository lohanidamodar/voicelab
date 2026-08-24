import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:record/record.dart';
import 'package:speech_pipeline/speech_pipeline.dart';

import '../../core/engine/pipeline_provider.dart';
import '../../core/engine/voice_library_provider.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/ui/views.dart';

/// One turn of the conversation, as shown on screen.
class Turn {
  Turn({required this.fromUser, required this.text, this.pending = false});

  final bool fromUser;
  String text;

  /// Still being generated — rendered dimmed so a half-sentence does not read
  /// as the finished answer.
  bool pending;
}

/// The assistant: speak, and it answers aloud.
///
/// The whole loop — VAD, recognition, the model, synthesis, barge-in — is
/// [SpeechPipeline] in the shared package. This screen supplies a microphone
/// stream and plays what comes back.
class SpeakScreen extends ConsumerStatefulWidget {
  const SpeakScreen({super.key});

  @override
  ConsumerState<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends ConsumerState<SpeakScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _turns = <Turn>[];
  final _scroll = ScrollController();

  StreamSubscription<PipelineEvent>? _events;
  bool _listening = false;
  bool _speaking = false;
  String _state = 'Idle';

  /// Audio for the reply being assembled. Playback waits for the turn to
  /// finish: audioplayers plays files, not a PCM stream, so the alternative
  /// would be a new file every few hundred milliseconds.
  final _reply = <double>[];
  int _replyRate = 24000;

  @override
  void dispose() {
    _events?.cancel();
    _recorder.dispose();
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) return _stop();
    await _start();
  }

  Future<void> _start() async {
    final pipeline = await ref.read(speechPipelineProvider.future);

    if (!await _recorder.hasPermission()) {
      setState(() => _state = 'Microphone permission denied.');
      return;
    }

    // The pipeline is built for 16 kHz mono; asking the recorder for exactly
    // that avoids a resample on every frame.
    final mic = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: kSampleRate,
        numChannels: 1,
      ),
    );

    _replyRate = pipeline.outputSampleRate;
    setState(() {
      _listening = true;
      _state = 'Listening';
    });

    _events = pipeline
        .run(framePcm16(mic))
        .listen(
          _onEvent,
          onError: (e) {
            setState(() => _state = '$e');
          },
        );
  }

  Future<void> _stop() async {
    await _events?.cancel();
    _events = null;
    if (await _recorder.isRecording()) await _recorder.stop();
    await _player.stop();
    setState(() {
      _listening = false;
      _speaking = false;
      _state = 'Idle';
    });
  }

  void _onEvent(PipelineEvent event) {
    switch (event) {
      case UserSpeaking():
        setState(() => _state = 'Hearing you');

      case UserFinishedSpeaking():
        _reply.clear();
        setState(() => _state = 'Thinking');

      case UserTranscript(:final text):
        setState(() => _turns.add(Turn(fromUser: true, text: text)));
        _toBottom();

      case AssistantDelta(:final text):
        setState(() {
          if (_turns.isEmpty || _turns.last.fromUser) {
            _turns.add(Turn(fromUser: false, text: text, pending: true));
          } else {
            _turns.last.text += text;
          }
        });
        _toBottom();

      case AssistantAudio(:final samples):
        _reply.addAll(samples);

      case TurnComplete():
        if (_turns.isNotEmpty && !_turns.last.fromUser) {
          setState(() => _turns.last.pending = false);
        }
        unawaited(_playReply());

      case Interrupted():
        // Barge-in: the user talked over the answer, so it is abandoned
        // rather than finished into an empty room.
        _reply.clear();
        unawaited(_player.stop());
        setState(() {
          _speaking = false;
          _state = 'Listening';
          if (_turns.isNotEmpty && !_turns.last.fromUser) {
            _turns.last.pending = false;
            _turns.last.text += ' …';
          }
        });

      case PipelineError(:final error):
        // An unreachable model is a settings problem, not a crash: offer the
        // way in rather than leaving a raw exception on the status bar.
        setState(() => _state = '$error');
        if (error is LlmUnreachable && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$error'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => context.goTo(Routes.llm),
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
    }
  }

  Future<void> _playReply() async {
    if (_reply.isEmpty) return;
    final samples = Float32List.fromList(_reply);
    _reply.clear();

    final dir = await assistantScratch();
    final path =
        '${dir.path}/reply_${DateTime.now().millisecondsSinceEpoch}.wav';
    await File(path).writeAsBytes(encodeWav(samples, _replyRate));

    setState(() {
      _speaking = true;
      _state = 'Speaking';
    });
    await _player.play(DeviceFileSource(path));

    // Reset from the known duration rather than onPlayerComplete: the Windows
    // plugin posts completion events off the platform thread, which Flutter
    // warns about and which crashed the app here.
    final seconds = samples.length / _replyRate;
    await Future<void>.delayed(
      Duration(milliseconds: (seconds * 1000).round() + 200),
    );
    if (!mounted) return;
    setState(() {
      _speaking = false;
      if (_listening) _state = 'Listening';
    });
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(assistantConfigProvider);
    final controller = ref.read(assistantConfigProvider.notifier);
    final notice = ref.watch(pipelineNoticeProvider);
    final pipeline = ref.watch(speechPipelineProvider);

    // A configuration problem is the user's to fix, so it is shown as a
    // message with a way in rather than as a crash.
    if (pipeline case AsyncError(:final error)
        when error is PipelineUnavailable) {
      return _notConfigured(context, error.message);
    }

    return Column(
      children: [
        _controls(config, controller),
        const Divider(height: 1),
        Expanded(
          child: _turns.isEmpty
              ? EmptyView(
                  icon: PiconsRegular.chat,
                  title: 'Say something',
                  message: config.autoLanguage
                      ? 'Speak English, Nepali or Sanskrit — it follows you.'
                      : 'Answers come back in ${config.language.label}.',
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _turns.length,
                  itemBuilder: (_, i) => _bubble(context, _turns[i]),
                ),
        ),
        _statusBar(context, notice, pipeline.isLoading),
      ],
    );
  }

  Widget _controls(AssistantConfig config, AssistantConfigController c) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(
                    _listening ? PiconsRegular.stop : PiconsRegular.microphone,
                  ),
                  label: Text(_listening ? 'Stop' : 'Start talking'),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Language model',
                  icon: const Icon(PiconsRegular.gear),
                  onPressed: () => context.goTo(Routes.llm),
                ),
                const Spacer(),
                if (_turns.isNotEmpty)
                  TextButton(
                    onPressed: _listening ? null : () => setState(_turns.clear),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: config.autoLanguage,
              // Changing this rebuilds the pipeline, which reloads models.
              onChanged: _listening ? null : c.setAuto,
              contentPadding: EdgeInsets.zero,
              title: const Text('Detect language automatically'),
              subtitle: Text(
                config.autoLanguage
                    ? 'Sanskrit speech is heard as Nepali — pick it manually '
                          'for Sanskrit input.'
                    : 'Fixed to ${config.language.label}.',
              ),
            ),
            if (!config.autoLanguage)
              SegmentedButton<PipelineLanguage>(
                segments: const [
                  ButtonSegment(
                    value: PipelineLanguage.english,
                    label: Text('English'),
                  ),
                  ButtonSegment(
                    value: PipelineLanguage.nepali,
                    label: Text('Nepali'),
                  ),
                  ButtonSegment(
                    value: PipelineLanguage.sanskrit,
                    label: Text('Sanskrit'),
                  ),
                ],
                selected: {config.language},
                onSelectionChanged: _listening
                    ? null
                    : (s) => c.setLanguage(s.first),
              ),
            SwitchListTile(
              value: config.useClonedVoice,
              onChanged: _listening ? null : c.setClonedVoice,
              contentPadding: EdgeInsets.zero,
              title: Text('Answer as ${ref.watch(selectedVoiceProvider).name}'),
              subtitle: const Text(
                'Cloned voices need a GPU backend to keep up with a '
                'conversation, and cannot switch language automatically.',
              ),
            ),
          ],
        ),
      );

  Widget _bubble(BuildContext context, Turn turn) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: turn.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: turn.fromUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            color: turn.fromUser
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontStyle: turn.pending ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  Widget _statusBar(BuildContext context, String? notice, bool loading) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                _speaking
                    ? PiconsRegular.play
                    : _listening
                    ? PiconsRegular.microphone
                    : PiconsRegular.pause,
                size: 16,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loading ? 'Loading models…' : _state,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (notice != null)
              Flexible(
                child: Text(
                  notice,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      );

  Widget _notConfigured(BuildContext context, String message) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(PiconsRegular.gear, size: 40),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.goTo(Routes.llm),
          child: const Text('Choose a language model'),
        ),
      ],
    ),
  );
}
