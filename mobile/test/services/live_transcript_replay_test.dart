import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

import 'replay_live_socket.dart';

const _profile = VoiceProfile(
  id: 'example-profile',
  name: 'Example',
  intent: 'Clean up the example text.',
  commitSuffix: CommitSuffix.none,
  autoCommit: false,
);

ProviderSettings _settings({
  required String provider,
  bool transform = false,
  String bailianMode = bailianAsrModeRealtime,
}) {
  return ProviderSettings.defaults().copyWith(
    speechProvider: provider,
    textTransformEnabled: transform,
    bailianAsrMode: bailianMode,
    bailianApiBase: 'https://example-provider.invalid/v1',
    bailianApiKey: 'example-key',
    bailianRealtimeUrl: 'wss://example-provider.invalid/ws',
    sonioxApiKey: 'example-key',
  );
}

/// L1: while listening, each committed value extends the previous one.
void expectCommittedOnlyGrows(List<LiveTranscript> history) {
  String? previous;
  for (final state in history.where((s) => s.phase == LivePhase.listening)) {
    if (previous != null) {
      expect(
        state.committed.startsWith(previous),
        isTrue,
        reason:
            'L1: committed "${state.committed}" does not extend "$previous"',
      );
    }
    previous = state.committed;
  }
}

class _Run {
  _Run(this.service, this.socket, this.history);

  final RealTranscriptionService service;
  final ReplayLiveSocket socket;
  final List<LiveTranscript> history;
}

Future<_Run> _startLive(
  String fixtureName,
  String provider, {
  bool transform = false,
  http.Client Function()? httpClient,
}) async {
  final socket = ReplayLiveSocket(StreamingFixture.load(fixtureName));
  final service = RealTranscriptionService(
    settings: _settings(provider: provider, transform: transform),
    connect: socket.connect,
    httpClient: httpClient,
  );
  final history = <LiveTranscript>[];
  service.live.addListener(() => history.add(service.live.value));
  return _Run(service, socket, history);
}

http.Client Function() _chatReturning(String content) {
  return () => MockClient((request) async {
    expect(request.url.host, 'example-provider.invalid');
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': content},
            },
          ],
        }),
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

void main() {
  for (final (fixture, provider) in [
    ('bailian_basic', 'bailian'),
    ('bailian_out_of_order', 'bailian'),
    ('bailian_unended_at_finish', 'bailian'),
    ('soniox_basic', 'soniox'),
    ('soniox_repeated', 'soniox'),
  ]) {
    test('$fixture: committed only grows (L1), final has every segment once '
        '(L2)', () async {
      final run = await _startLive(fixture, provider);
      final session = await run.service.startLiveSession();
      expect(run.service.live.value.phase, LivePhase.listening);
      session.addPcm(Uint8List(3200));
      await run.socket.replayDuring();
      expect(run.service.live.value.phase, LivePhase.listening);

      final result = await run.service.finishLiveSession(
        session: session,
        profile: _profile,
      );
      final expected = run.socket.fixture.string('expected_final')!;
      expect(result.text, expected);
      expect(
        run.service.live.value,
        LiveTranscript(committed: expected, phase: LivePhase.done),
      );
      expectCommittedOnlyGrows(run.history);
      final phases = run.history.map((s) => s.phase).toSet().toList();
      expect(phases, [
        LivePhase.connecting,
        LivePhase.listening,
        LivePhase.finishing,
        LivePhase.done,
      ]);
      expect(run.socket.audioBytes, 3200);
      expect(run.socket.closed, isTrue);
    });
  }

  for (final (fixture, provider) in [
    ('bailian_dropped', 'bailian'),
    ('bailian_task_failed', 'bailian'),
    ('soniox_dropped', 'soniox'),
    ('soniox_error', 'soniox'),
  ]) {
    test('$fixture: failed while listening keeps committed text', () async {
      final run = await _startLive(fixture, provider);
      final session = await run.service.startLiveSession();
      await run.socket.replayDuring();

      final live = run.service.live.value;
      expect(live.phase, LivePhase.failed);
      expect(live.error, isNotNull);
      expect(live.committed, run.socket.fixture.string('expected_committed'));
      expect(live.pending, run.socket.fixture.string('expected_pending'));
      expectCommittedOnlyGrows(run.history);

      // Audio after the failure is not sent; stopping reports the failure and keeps the text.
      final sentBefore = run.socket.sent.length;
      session.addPcm(Uint8List(3200));
      expect(run.socket.sent.length, sentBefore);
      await expectLater(
        run.service.finishLiveSession(session: session, profile: _profile),
        throwsA(anything),
      );
      expect(run.service.live.value, live);
    });
  }

  test(
    'bailian live: per-message snapshots of committed and pending',
    () async {
      final run = await _startLive('bailian_out_of_order', 'bailian');
      await run.service.startLiveSession();
      final snapshots = <(String, String)>[];
      await run.socket.replayDuring((_) {
        final v = run.service.live.value;
        snapshots.add((v.committed, v.pending));
      });
      expect(snapshots, [
        ('', '示例一'),
        ('', '示例一示例二。'), // 2 ended, but 1 is still open: not committed yet
        ('示例一。示例二。', ''),
        ('示例一。示例二。', ''), // repeated end of 1
        ('示例一。示例二。', ''), // repeated end of 2
        ('示例一。示例二。', ''), // rewrite of committed 1 ignored
        ('示例一。示例二。', '示例三'),
        ('示例一。示例二。示例三。', ''), // end_time-only end
        ('示例一。示例二。示例三。', ''),
      ]);
    },
  );

  test('soniox live: per-message snapshots of committed and pending', () async {
    final run = await _startLive('soniox_basic', 'soniox');
    await run.service.startLiveSession();
    final snapshots = <(String, String)>[];
    await run.socket.replayDuring((_) {
      final v = run.service.live.value;
      snapshots.add((v.committed, v.pending));
    });
    expect(snapshots, [
      ('', 'This'),
      ('This', ' is an'),
      ('This is an', ' ex'),
      ('This is an example.', ''),
      ('This is an example.', ' Second'),
    ]);
  });

  test('soniox live session streams raw PCM and sends the key only in the '
      'config message', () async {
    final run = await _startLive('soniox_basic', 'soniox');
    final session = await run.service.startLiveSession();
    final config = jsonDecode(run.socket.sent.first as String) as Map;
    expect(config['audio_format'], 'pcm_s16le');
    expect(config['sample_rate'], 16000);
    expect(config['num_channels'], 1);
    expect(run.socket.headers, isNull);
    await session.close();
  });

  test('post-processing: processing shows raw text, then done swaps in the '
      'processed text once (L2)', () async {
    final run = await _startLive(
      'bailian_basic',
      'bailian',
      transform: true,
      httpClient: _chatReturning('Processed example.'),
    );
    final session = await run.service.startLiveSession();
    await run.socket.replayDuring();
    final result = await run.service.finishLiveSession(
      session: session,
      profile: _profile,
    );
    expect(result.text, 'Processed example.');
    final tail = run.history.skipWhile((s) => s.phase != LivePhase.processing);
    expect(tail.toList(), const [
      LiveTranscript(
        committed: '示例第一句。Example two.',
        phase: LivePhase.processing,
      ),
      LiveTranscript(committed: 'Processed example.', phase: LivePhase.done),
    ]);
    expectCommittedOnlyGrows(run.history);
  });

  test('commit suffix stays out of the live text', () async {
    final run = await _startLive('soniox_basic', 'soniox');
    final session = await run.service.startLiveSession();
    await run.socket.replayDuring();
    final result = await run.service.finishLiveSession(
      session: session,
      profile: _profile.copyWith(commitSuffix: CommitSuffix.newline),
    );
    expect(result.text, 'This is an example. Second line.\n');
    expect(
      run.service.live.value.committed,
      'This is an example. Second line.',
    );
  });

  test('batch provider: phases only, no words until the result', () async {
    final service = RealTranscriptionService(
      settings: _settings(provider: 'bailian', bailianMode: bailianAsrModeQwen),
      httpClient: _chatReturning('Example batch result.'),
    );
    expect(service.streamsLive, isFalse);
    final history = <LiveTranscript>[];
    service.live.addListener(() => history.add(service.live.value));
    service.beginBatchListening();
    final result = await service.transcribe(
      wavBytes: Uint8List(44),
      profile: _profile,
    );
    expect(result.text, 'Example batch result.');
    expect(history, const [
      LiveTranscript(phase: LivePhase.listening),
      LiveTranscript(phase: LivePhase.finishing),
      LiveTranscript(committed: 'Example batch result.', phase: LivePhase.done),
    ]);
  });

  test(
    'soniox upload after stop: words flow in, phase stays finishing',
    () async {
      final socket = ReplayLiveSocket(StreamingFixture.load('soniox_basic'));
      final service = RealTranscriptionService(
        settings: _settings(provider: 'soniox'),
        connect: socket.connect,
      );
      final history = <LiveTranscript>[];
      service.live.addListener(() => history.add(service.live.value));
      final pending = service.transcribe(
        wavBytes: Uint8List(100),
        profile: _profile,
      );
      await ReplayLiveSocket.pump();
      await socket.replayDuring();
      final result = await pending;
      expect(result.text, 'This is an example. Second line.');
      expect(history.map((s) => s.phase).toSet(), {
        LivePhase.finishing,
        LivePhase.done,
      });
      expect(history.any((s) => s.committed == 'This is an example.'), isTrue);
      expect(
        (jsonDecode(socket.sent.first as String) as Map)['audio_format'],
        'wav',
      );
    },
  );

  test('missing credentials: failed before connecting', () async {
    final service = RealTranscriptionService(
      settings: _settings(provider: 'soniox').copyWith(sonioxApiKey: ''),
    );
    await expectLater(service.startLiveSession(), throwsStateError);
    expect(service.live.value.phase, LivePhase.failed);
  });
}
