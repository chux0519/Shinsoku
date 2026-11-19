// profile-01 P5: the active-profile world for the model test (invariants
// PR1–PR4 in docs/design/state_invariants.md).
//
// * [RefModel] is an independent, obviously-correct statement of the
//   precedence. It orders events by when they really happened (sequence
//   order) and never looks at a writer's clock or calls resolveActive.
// * [ProfileSystem] is the system under test: the real ActiveProfileStore
//   and resolveActive over a fake App Group, the App Intent and the keyboard
//   as thin stand-ins that follow the P1 contract (write `activeProfile.v1`,
//   resolve with resolveActive). Each writer has its own clock that may be
//   skewed by up to ±2 s.
import 'dart:math';

import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

import 'harness.dart';

// ---------------------------------------------------------------------------
// Events. Every event carries the real time it happens at (ms, increasing).

enum Writer { app, intent, keyboard }

enum FieldKind { message, search, email, url }

/// Field-kind rules configured in Settings (fixed for the whole run). `url`
/// points at a profile that only exists after `ProfileAdd('custom1')`.
const fieldRules = {
  FieldKind.search: 'review',
  FieldKind.email: 'zh_to_en',
  FieldKind.url: 'custom1',
};

/// Built-in profile the keyboard shows when it has never seen the group.
const keyboardFallbackId = 'dictation';

sealed class ProfileEvent {
  const ProfileEvent(this.at);

  /// Real time in ms since the start of the run.
  final int at;

  String get dart;

  @override
  String toString() => dart;
}

/// "Set Shinsoku Profile" App Intent (Shortcuts automation).
class AutomationSet extends ProfileEvent {
  const AutomationSet(this.id, {required int at}) : super(at);
  final String id;
  @override
  String get dart => "AutomationSet('$id', at: $at)";
}

/// A pick in the keyboard when it is up, otherwise in the app's Record
/// selector.
class ManualPick extends ProfileEvent {
  const ManualPick(this.id, {required int at}) : super(at);
  final String id;
  @override
  String get dart => "ManualPick('$id', at: $at)";
}

class KeyboardAppear extends ProfileEvent {
  const KeyboardAppear(this.kind, {required int at}) : super(at);
  final FieldKind kind;
  @override
  String get dart => 'KeyboardAppear(FieldKind.${kind.name}, at: $at)';
}

class KeyboardDisappear extends ProfileEvent {
  const KeyboardDisappear({required int at}) : super(at);
  @override
  String get dart => 'KeyboardDisappear(at: $at)';
}

/// Record tapped: in the keyboard when it is up, otherwise in the app.
class RecordStart extends ProfileEvent {
  const RecordStart({required int at}) : super(at);
  @override
  String get dart => 'RecordStart(at: $at)';
}

/// Stop tapped; the transcript is done.
class RecordStop extends ProfileEvent {
  const RecordStop({required int at}) : super(at);
  @override
  String get dart => 'RecordStop(at: $at)';
}

class ProfileDelete extends ProfileEvent {
  const ProfileDelete(this.id, {required int at}) : super(at);
  final String id;
  @override
  String get dart => "ProfileDelete('$id', at: $at)";
}

class ProfileRename extends ProfileEvent {
  const ProfileRename(this.id, this.name, {required int at}) : super(at);
  final String id;
  final String name;
  @override
  String get dart => "ProfileRename('$id', '$name', at: $at)";
}

/// A new profile in the app; the app picks it (as MobileShell does).
class ProfileAdd extends ProfileEvent {
  const ProfileAdd(this.id, {required int at}) : super(at);
  final String id;
  @override
  String get dart => "ProfileAdd('$id', at: $at)";
}

/// The app is killed and relaunched: it reloads from the mirrored store.
class AppRelaunch extends ProfileEvent {
  const AppRelaunch({required int at}) : super(at);
  @override
  String get dart => 'AppRelaunch(at: $at)';
}

class FullAccess extends ProfileEvent {
  const FullAccess(this.on, {required int at}) : super(at);
  final bool on;
  @override
  String get dart => 'FullAccess($on, at: $at)';
}

/// [writer]'s clock now reads real time + [offsetMs] (|offset| ≤ 2000).
class ClockSkew extends ProfileEvent {
  const ClockSkew(this.writer, this.offsetMs, {required int at}) : super(at);
  final Writer writer;
  final int offsetMs;
  @override
  String get dart => 'ClockSkew(Writer.${writer.name}, $offsetMs, at: $at)';
}

// ---------------------------------------------------------------------------
// Generator.

const _pool = ['dictation', 'chat', 'review', 'zh_to_en', 'custom1', 'gone'];

ProfileEvent genEvent(Random rng, List<ProfileEvent> sofar) {
  final at = (sofar.isEmpty ? 0 : sofar.last.at) + 1 + rng.nextInt(3000);
  String id() => _pool[rng.nextInt(_pool.length)];
  final roll = rng.nextInt(100);
  if (roll < 14) return AutomationSet(id(), at: at);
  if (roll < 28) return ManualPick(id(), at: at);
  if (roll < 40) {
    return KeyboardAppear(
      FieldKind.values[rng.nextInt(FieldKind.values.length)],
      at: at,
    );
  }
  if (roll < 48) return KeyboardDisappear(at: at);
  if (roll < 58) return RecordStart(at: at);
  if (roll < 66) return RecordStop(at: at);
  if (roll < 71) return ProfileDelete(id(), at: at);
  if (roll < 75) return ProfileRename(id(), 'Name${rng.nextInt(9)}', at: at);
  if (roll < 79) return ProfileAdd(rng.nextBool() ? 'custom1' : 'gone', at: at);
  if (roll < 84) return AppRelaunch(at: at);
  if (roll < 90) return FullAccess(rng.nextInt(3) > 0, at: at);
  return ClockSkew(
    Writer.values[rng.nextInt(Writer.values.length)],
    rng.nextInt(4001) - 2000,
    at: at,
  );
}

// ---------------------------------------------------------------------------
// Reference model.

class RefModel {
  /// The app's profiles, in order (ids → names). The first is the default.
  final ids = <String>[for (final p in defaultVoiceProfiles) p.id];
  final names = <String, String>{
    for (final p in defaultVoiceProfiles) p.id: p.name,
  };

  /// The newest explicit event (manual pick or automation set), by real
  /// order; null when there is none or its profile was deleted.
  String? explicitId;
  int explicitSeq = -1;

  bool keyboardUp = false;
  int keyboardSeq = -1;
  FieldKind kind = FieldKind.message;
  bool fullAccess = true;

  /// What the keyboard showed the last time it could read the group (PR4).
  String? keyboardLastShown;

  /// Profile captured at record start; null when not recording.
  String? recording;

  /// True right after a keyboard Record tap, for the PR1 "same as shown"
  /// check.
  String? shownAtRecordTap;

  int _seq = 0;

  String get defaultId => ids.first;

  /// Selection without a keyboard session (the app, App Intents "Get").
  String get selectionId => explicitId ?? defaultId;

  /// What the keyboard shows (PR2, PR3, PR4).
  String? get keyboardShows {
    if (!keyboardUp) return null;
    if (!fullAccess) return keyboardLastShown ?? keyboardFallbackId;
    final rule = fieldRules[kind];
    final ruleApplies = rule != null && ids.contains(rule);
    final explicitAfterKeyboard =
        explicitId != null && explicitSeq > keyboardSeq;
    if (ruleApplies && !explicitAfterKeyboard) return rule;
    return selectionId;
  }

  void _explicit(String id) {
    explicitId = id;
    explicitSeq = _seq;
  }

  void apply(ProfileEvent ev) {
    _seq++;
    shownAtRecordTap = null;
    switch (ev) {
      case AutomationSet(:final id):
        if (ids.contains(id)) _explicit(id);
      case ManualPick(:final id):
        final canWrite = !keyboardUp || fullAccess;
        if (canWrite && ids.contains(id)) _explicit(id);
      case KeyboardAppear(kind: final k):
        keyboardUp = true;
        keyboardSeq = _seq;
        kind = k;
      case KeyboardDisappear():
        keyboardUp = false;
      case RecordStart():
        if (recording != null) break;
        if (keyboardUp) {
          final shown = keyboardShows!;
          shownAtRecordTap = shown;
          // A stale read-only keyboard may show a deleted profile: the app
          // can't record with it and falls back (PR3 wins).
          recording = ids.contains(shown) ? shown : selectionId;
        } else {
          recording = selectionId;
        }
      case RecordStop():
        recording = null;
      case ProfileDelete(:final id):
        if (ids.length > 1 && ids.remove(id)) {
          names.remove(id);
          if (explicitId == id) explicitId = null;
        }
      case ProfileRename(:final id, :final name):
        if (ids.contains(id)) names[id] = name;
      case ProfileAdd(:final id):
        if (!ids.contains(id)) {
          ids.add(id);
          names[id] = id;
          _explicit(id);
        }
      case AppRelaunch():
        recording = null;
      case FullAccess(:final on):
        fullAccess = on;
      case ClockSkew():
        break;
    }
    if (keyboardUp && fullAccess) keyboardLastShown = keyboardShows;
  }
}

// ---------------------------------------------------------------------------
// System under test.

/// The App Group as the app, the App Intent and the keyboard see it.
class FakeGroup implements ProfileGroupBridge {
  String? profilesRaw;
  List<Map<String, String>> profiles = const [];
  String? activeRaw;

  @override
  Future<void> publishProfiles(List<Map<String, String>> list) async {
    profiles = [for (final p in list) Map.of(p)];
  }

  @override
  Future<void> setActive(ProfileSelection selection) async {
    activeRaw = selection.encode();
  }

  @override
  Future<String?> readActive() async => activeRaw;

  ProfileSelection? get active => ProfileSelection.decode(activeRaw);

  List<VoiceProfile> get listed => [
    for (final p in profiles)
      VoiceProfile(
        id: p['id']!,
        name: p['name']!,
        intent: '',
        commitSuffix: CommitSuffix.space,
        autoCommit: true,
      ),
  ];
}

/// The keyboard extension as P3 must behave (P1 notes): resolve with
/// resolveActive against the group, write manual picks to the group, keep
/// the last shown profile for read-only mode.
class KeyboardStandIn {
  KeyboardStandIn(this.group, this.clock);

  final FakeGroup group;
  final DateTime Function() clock;

  bool up = false;
  bool fullAccess = true;
  FieldKind kind = FieldKind.message;
  DateTime? appearedAt;
  ProfileSelection? selectionAtAppear;
  VoiceProfile? lastShown;

  void appear(FieldKind k) {
    up = true;
    kind = k;
    appearedAt = clock();
    selectionAtAppear = group.active;
  }

  /// Null when the keyboard is down.
  VoiceProfile? get shows {
    if (!up) return null;
    if (!fullAccess) {
      return lastShown ??
          defaultVoiceProfiles.firstWhere((p) => p.id == keyboardFallbackId);
    }
    final rule = fieldRules[kind];
    final resolved = resolveActive(
      group.active,
      group.listed,
      fieldRuleMatch: rule == null ? null : FieldRuleMatch(rule),
      keyboardAppearedAt: appearedAt,
      selectionAtKeyboardAppear: selectionAtAppear,
    ).profile;
    return lastShown = resolved;
  }

  /// PR4: why the keyboard can't switch, or null when it can.
  String? get readOnlyReason =>
      up && !fullAccess ? 'Allow Full Access to switch profiles' : null;

  Future<void> pick(String id) async {
    if (!fullAccess) return;
    if (!group.listed.any((p) => p.id == id)) return;
    await group.setActive(
      ProfileSelection(
        profileId: id,
        source: ProfileSource.manual,
        at: clock(),
      ),
    );
  }
}

class ProfileSystem {
  ProfileSystem() {
    keyboard = KeyboardStandIn(group, () => _clock(Writer.keyboard));
  }

  static final _t0 = DateTime.utc(2026, 11, 19, 9);

  final group = FakeGroup();
  late final KeyboardStandIn keyboard;
  final _skew = {for (final w in Writer.values) w: 0};
  int _now = 0;

  List<VoiceProfile> profiles = List.of(defaultVoiceProfiles);
  late ActiveProfileStore store;

  /// Profile the recording uses (MobileShell._recordingProfile).
  VoiceProfile? recording;
  VoiceProfile? shownAtRecordTap;

  DateTime _clock(Writer w) =>
      _t0.add(Duration(milliseconds: _now + _skew[w]!));

  Future<void> launch() async {
    store = ActiveProfileStore(bridge: group, clock: () => _clock(Writer.app));
    await store.sync(profiles);
  }

  /// MobileShell._startRecording after a Record tap ([requestedId] is the
  /// profile the keyboard showed, when the tap came from the keyboard).
  Future<VoiceProfile> appRecordStart({String? requestedId}) async {
    await store.refresh();
    return profileForRecordStart(
      store.selection,
      profiles,
      requestedProfileId: requestedId,
    );
  }

  Future<void> _saveProfiles(List<VoiceProfile> next) async {
    profiles = next;
    await store.sync(profiles);
  }

  Future<void> apply(ProfileEvent ev) async {
    _now = ev.at;
    shownAtRecordTap = null;
    switch (ev) {
      case AutomationSet(:final id):
        // SetProfileIntent: the entity query only offers listed profiles.
        if (group.listed.any((p) => p.id == id)) {
          await group.setActive(
            ProfileSelection(
              profileId: id,
              source: ProfileSource.automation,
              at: _clock(Writer.intent),
            ),
          );
        }
      case ManualPick(:final id):
        if (keyboard.up) {
          await keyboard.pick(id);
        } else if (profiles.any((p) => p.id == id)) {
          await store.selectManually(id);
        }
      case KeyboardAppear(:final kind):
        keyboard.appear(kind);
      case KeyboardDisappear():
        keyboard.up = false;
      case RecordStart():
        if (recording != null) break;
        if (keyboard.up) {
          final shown = keyboard.shows!;
          shownAtRecordTap = shown;
          recording = await appRecordStart(requestedId: shown.id);
        } else {
          recording = await appRecordStart();
        }
      case RecordStop():
        recording = null;
      case ProfileDelete(:final id):
        if (profiles.length > 1 && profiles.any((p) => p.id == id)) {
          await _saveProfiles([
            for (final p in profiles)
              if (p.id != id) p,
          ]);
        }
      case ProfileRename(:final id, :final name):
        if (profiles.any((p) => p.id == id)) {
          await _saveProfiles([
            for (final p in profiles) p.id == id ? p.copyWith(name: name) : p,
          ]);
        }
      case ProfileAdd(:final id):
        if (!profiles.any((p) => p.id == id)) {
          await _saveProfiles([
            ...profiles,
            VoiceProfile(
              id: id,
              name: id,
              intent: '',
              commitSuffix: CommitSuffix.space,
              autoCommit: true,
            ),
          ]);
          await store.selectManually(id);
        }
      case AppRelaunch():
        recording = null;
        await launch();
      case FullAccess(:final on):
        keyboard.fullAccess = on;
      case ClockSkew(:final writer, :final offsetMs):
        _skew[writer] = offsetMs;
    }
    // The keyboard re-renders on every change while it is up.
    keyboard.shows;
  }
}

// ---------------------------------------------------------------------------
// Invariants, checked after every event.

typedef Invariant = String? Function(RefModel m, ProfileSystem s);

String? pr1RecordUsesWhatKeyboardShows(RefModel m, ProfileSystem s) {
  final shown = s.shownAtRecordTap;
  if (shown != null &&
      s.profiles.any((p) => p.id == shown.id) &&
      s.recording?.id != shown.id) {
    return 'keyboard showed ${shown.id}, recording uses ${s.recording?.id}';
  }
  if (s.recording?.id != m.recording) {
    return 'recording uses ${s.recording?.id}, model ${m.recording}';
  }
  return null;
}

String? pr2NewerEventWins(RefModel m, ProfileSystem s) {
  final stored = resolveActive(s.group.active, s.profiles).profile.id;
  if (stored != m.selectionId) {
    return 'stored selection resolves to $stored, newest event is '
        '${m.selectionId}';
  }
  if (m.keyboardUp && m.fullAccess) {
    final shows = s.keyboard.shows?.id;
    if (shows != m.keyboardShows) {
      return 'keyboard (${m.kind.name} field) shows $shows, model '
          '${m.keyboardShows}';
    }
  }
  return null;
}

String? pr3NoDanglingSelection(RefModel m, ProfileSystem s) {
  final stored = s.group.active?.profileId;
  if (stored == null || !m.ids.contains(stored)) {
    return 'stored selection $stored is not in ${m.ids}';
  }
  final listed = [for (final p in s.group.profiles) p['id']];
  if (listed.join(',') != m.ids.join(',')) {
    return 'group lists $listed, app has ${m.ids}';
  }
  if (m.keyboardUp && m.fullAccess) {
    final shows = s.keyboard.shows!;
    if (!m.ids.contains(shows.id) || shows.name != m.names[shows.id]) {
      return 'keyboard shows ${shows.id} "${shows.name}"';
    }
  }
  return null;
}

String? pr4ReadOnlyWithoutFullAccess(RefModel m, ProfileSystem s) {
  if (!m.keyboardUp || m.fullAccess) {
    return s.keyboard.readOnlyReason == null
        ? null
        : 'read-only reason shown with Full Access';
  }
  if (s.keyboard.readOnlyReason == null) return 'no read-only reason';
  final shows = s.keyboard.shows?.id;
  final expected = m.keyboardLastShown ?? keyboardFallbackId;
  if (shows != expected) return 'keyboard shows $shows, last known $expected';
  return null;
}

const invariants = <String, Invariant>{
  'PR1': pr1RecordUsesWhatKeyboardShows,
  'PR2': pr2NewerEventWins,
  'PR3': pr3NoDanglingSelection,
  'PR4': pr4ReadOnlyWithoutFullAccess,
};

/// Builds a fresh model and system, launches the app, applies [seq] and
/// checks every invariant after every event.
Future<ModelFailure?> runProfileSequence(
  List<ProfileEvent> seq, {
  RefModel Function()? makeModel,
  ProfileSystem Function()? makeSystem,
}) async {
  final model = (makeModel ?? RefModel.new)();
  final system = (makeSystem ?? ProfileSystem.new)();
  await system.launch();
  for (var i = 0; i < seq.length; i++) {
    model.apply(seq[i]);
    await system.apply(seq[i]);
    for (final MapEntry(key: rule, value: inv) in invariants.entries) {
      final why = inv(model, system);
      if (why != null) return ModelFailure(i, rule, why);
    }
  }
  return null;
}

/// A shrunk failing sequence as a test to paste into regressions_test.dart.
String profileCaseToDart(String name, List<ProfileEvent> seq) {
  final events = seq.map((e) => '    ${e.dart},').join('\n');
  return "  regression('$name', const [\n$events\n  ]);";
}
