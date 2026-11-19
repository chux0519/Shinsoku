// profile-01 P5: named regression cases for the active-profile model test.
// Paste new shrunk sequences printed by profile_model_test.dart here.
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

import 'profile_world.dart';

void regression(String name, List<ProfileEvent> seq) {
  test(name, () async {
    final failure = await runProfileSequence(seq);
    expect(failure, isNull, reason: '$failure');
  });
}

void main() {
  // Found by P5 (seed 1, before the fix): the keyboard had no Full Access
  // and showed its last known profile (Dictation); an automation had set
  // Review meanwhile. Record in the keyboard → the app re-resolved the group
  // and recorded with Review. Same with a field rule: the app can't see it.
  // Fix: the deep link carries the shown profile (profileForRecordStart).
  regression('PR1: keyboard Record tap records what the keyboard shows', const [
    FullAccess(false, at: 259692),
    AutomationSet('review', at: 261469),
    KeyboardAppear(FieldKind.url, at: 270885),
    RecordStart(at: 300445),
  ]);

  regression('PR1: keyboard Record tap with a field rule', const [
    AutomationSet('chat', at: 1000),
    KeyboardAppear(FieldKind.search, at: 2000),
    RecordStart(at: 3000),
  ]);

  // Found by P5 (seed 1, after the PR1 fix): the keyboard's clock was 1.8 s
  // behind; an automation (Translate) fired 1.1 s before the keyboard
  // appeared in a search field. By timestamps the automation looked newer
  // than the keyboard, so it suppressed the search-field rule (Review).
  // Fix: compare with the selection seen at appear, not clocks.
  regression('PR2: clock skew does not reorder automation and keyboard', const [
    ClockSkew(Writer.keyboard, -1762, at: 76001),
    AutomationSet('zh_to_en', at: 82390),
    KeyboardAppear(FieldKind.search, at: 83516),
  ]);

  regression(
    'PR2: an automation after appear wins despite a fast keyboard '
    'clock and a slow intent clock',
    const [
      ClockSkew(Writer.keyboard, 2000, at: 10),
      ClockSkew(Writer.intent, -2000, at: 20),
      KeyboardAppear(FieldKind.search, at: 1000),
      AutomationSet('chat', at: 1500),
    ],
  );

  regression(
    'PR3: deleting the selected profile while the keyboard is up',
    const [
      ManualPick('chat', at: 1000),
      KeyboardAppear(FieldKind.message, at: 2000),
      ProfileDelete('chat', at: 3000),
      RecordStart(at: 4000),
    ],
  );

  regression(
    'PR4: read-only keyboard keeps the last profile and its name',
    const [
      KeyboardAppear(FieldKind.message, at: 1000),
      ManualPick('chat', at: 2000),
      FullAccess(false, at: 3000),
      ManualPick('review', at: 4000),
      KeyboardDisappear(at: 5000),
      AutomationSet('zh_to_en', at: 6000),
      KeyboardAppear(FieldKind.search, at: 7000),
      RecordStart(at: 8000),
    ],
  );

  group('profileForRecordStart', () {
    final profiles = List.of(defaultVoiceProfiles);
    final stored = ProfileSelection(
      profileId: 'chat',
      source: ProfileSource.automation,
      at: DateTime.utc(2026, 11, 19),
    );

    test('uses the profile the keyboard showed', () {
      expect(
        profileForRecordStart(
          stored,
          profiles,
          requestedProfileId: 'review',
        ).id,
        'review',
      );
    });

    test('falls back to the selection when the shown profile is gone', () {
      expect(
        profileForRecordStart(stored, profiles, requestedProfileId: 'gone').id,
        'chat',
      );
      expect(profileForRecordStart(stored, profiles).id, 'chat');
    });
  });
}
