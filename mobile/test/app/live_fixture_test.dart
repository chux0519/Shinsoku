// live-01 T3 item 5: the DEBUG launch argument -ShinsokuSceneLiveFixture
// replays T1's fixtures through the real RealTranscriptionService.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/debug_live_fixtures.dart';
import 'package:shinsoku_mobile/app/live_fixture_pipeline.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

const _profile = VoiceProfile(
  id: 'example-profile',
  name: 'Example',
  intent: '',
  commitSuffix: CommitSuffix.none,
  autoCommit: false,
);

void main() {
  test('the embedded fixtures match test/fixtures/streaming '
      '(regenerate: python3 tool/gen_live_fixtures.py)', () {
    final files = Directory('test/fixtures/streaming')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(debugLiveFixtures.keys.toSet(), {
      for (final f in files) f.uri.pathSegments.last.replaceAll('.json', ''),
    });
    for (final f in files) {
      final name = f.uri.pathSegments.last.replaceAll('.json', '');
      expect(
        jsonDecode(debugLiveFixtures[name]!),
        jsonDecode(f.readAsStringSync()),
        reason: name,
      );
    }
  });

  for (final name in ['bailian_basic', 'soniox_basic']) {
    test('$name replays live words, then the expected final text', () async {
      final fixture = LiveFixture.named(name)!;
      final pipeline = LiveFixturePipeline(
        fixture,
        interval: const Duration(milliseconds: 1),
      );
      final history = <LiveTranscript>[];
      pipeline.live.addListener(() => history.add(pipeline.live.value));
      await pipeline.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        history.where((s) => s.phase == LivePhase.listening && s.text != ''),
        isNotEmpty,
      );
      final result = await pipeline.stop(_profile);
      final expected = fixture.json['expected_final'] as String?;
      if (expected != null) expect(result.text, expected);
      expect(pipeline.live.value.phase, LivePhase.done);
      await pipeline.dispose();
    });
  }

  test('a dropped fixture fails with the heard words kept', () async {
    final pipeline = LiveFixturePipeline(
      LiveFixture.named('soniox_dropped')!,
      interval: const Duration(milliseconds: 1),
    );
    await pipeline.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(pipeline.live.value.phase, LivePhase.failed);
    expect(pipeline.live.value.text, 'Example one');
    await expectLater(pipeline.stop(_profile), throwsA(anything));
    await pipeline.dispose();
  });
}
