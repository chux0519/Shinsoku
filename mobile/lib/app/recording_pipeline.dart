import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:record/record.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

/// One recording, from the microphone (or a stand-in) to its text.
///
/// The shell creates one per recording. [live] carries the words while the
/// user speaks (streaming providers), the phases, and the text heard so far
/// when something fails: on any failure [stop] throws and `live.value` still
/// holds committed + pending, which the shell keeps as a draft (L2/L3).
abstract interface class RecordingPipeline {
  ValueListenable<LiveTranscript> get live;

  /// Starts capturing. Throws when the recording could not start.
  Future<void> start();

  /// Ends the recording and returns its text (post-processed per [profile]).
  Future<RealTranscriptionResult> stop(VoiceProfile profile);

  /// Releases the recorder stream, the provider socket and [live].
  Future<void> dispose();
}

/// Microphone + provider: streaming providers (Bailian realtime, Soniox) get
/// PCM while the user speaks and show live words; batch providers record a
/// WAV file and transcribe it after stop.
class MicrophonePipeline implements RecordingPipeline {
  MicrophonePipeline({
    required ProviderSettings settings,
    required this.recorder,
  }) : service = RealTranscriptionService(settings: settings);

  final AudioRecorder recorder;
  final RealTranscriptionService service;

  LiveAsrSession? _session;
  StreamSubscription<Uint8List>? _subscription;
  Object? _streamError;
  String? _path;
  var _disposed = false;

  @override
  ValueListenable<LiveTranscript> get live => service.live;

  @override
  Future<void> start() async {
    if (!service.streamsLive) {
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/shinsoku-${DateTime.now().microsecondsSinceEpoch}.wav';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: bailianRealtimeSampleRate,
          numChannels: bailianRealtimeChannels,
        ),
        path: path,
      );
      _path = path;
      service.beginBatchListening();
      return;
    }
    final session = await service.startLiveSession();
    try {
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: bailianRealtimeSampleRate,
          numChannels: bailianRealtimeChannels,
          streamBufferSize: bailianRealtimeStreamBufferSize,
        ),
      );
      _session = session;
      _subscription = stream.listen(
        session.addPcm,
        onError: (Object error) => _streamError = error,
      );
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  @override
  Future<RealTranscriptionResult> stop(VoiceProfile profile) async {
    final stopWatch = Stopwatch()..start();
    final path = await recorder.stop() ?? _path;
    await _subscription?.cancel();
    _subscription = null;
    _path = null;
    final recorderMs = stopWatch.elapsedMilliseconds;
    try {
      final session = _session;
      final RealTranscriptionResult result;
      if (session != null) {
        final streamError = _streamError;
        if (streamError != null) {
          await session.close();
          throw StateError('Recording stream failed: $streamError');
        }
        result = await service.finishLiveSession(
          session: session,
          profile: profile,
        );
      } else {
        if (path == null || !File(path).existsSync()) {
          throw StateError('Recording file was not created.');
        }
        final audio = await File(path).readAsBytes();
        if (audio.isEmpty) {
          throw StateError('Recording file is empty.');
        }
        result = await service.transcribe(wavBytes: audio, profile: profile);
      }
      return RealTranscriptionResult(
        text: result.text,
        provider: result.provider,
        detail:
            '${result.detail} appRecorderStop=${recorderMs}ms '
            'appStopToDraft=${stopWatch.elapsedMilliseconds}ms',
        postProcessTimedOut: result.postProcessTimedOut,
      );
    } finally {
      if (path != null) {
        unawaited(File(path).delete().catchError((_) => File(path)));
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    await _session?.close();
    service.dispose();
  }
}

/// Stands in for the recorder and provider pipeline in widget tests, so
/// capture state can be driven without plugins or network.
abstract interface class DebugCapture {
  Future<void> start();

  /// Returns the transcript.
  Future<String> stop();
}

/// [DebugCapture] as a batch provider: Listening…, then the text.
class DebugCapturePipeline implements RecordingPipeline {
  DebugCapturePipeline(this.capture);

  final DebugCapture capture;
  final _live = ValueNotifier<LiveTranscript>(LiveTranscript.idle);

  @override
  ValueListenable<LiveTranscript> get live => _live;

  @override
  Future<void> start() async {
    await capture.start();
    _live.value = const LiveTranscript(phase: LivePhase.listening);
  }

  @override
  Future<RealTranscriptionResult> stop(VoiceProfile profile) async {
    _live.value = const LiveTranscript(phase: LivePhase.finishing);
    final text = await capture.stop();
    _live.value = LiveTranscript(committed: text, phase: LivePhase.done);
    // Like the service: the result carries the profile's suffix.
    return RealTranscriptionResult(
      text: withCommitSuffix(text, profile.commitSuffix),
      provider: profile.name,
      detail: '',
    );
  }

  @override
  Future<void> dispose() async => _live.dispose();
}
