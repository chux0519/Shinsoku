// App Store screenshots, host-rendered (release-01 R3): real screens with the
// store fixtures, one locale per run, 6.9" iPhone (440×956 pt at 3× =
// 1320×2868 px), with a clean status bar (9:41, full battery). Run through
// tool/store_shots.sh; tool/store_frames.py frames the output.
//
// Output: build/store/raw/<store-locale>/NN-<scene>-<theme>.png (+ .json with
// any paragraph cut by its line limit).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/field_rules_view.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/nearby/nearby_models.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/services/field_rules.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';
import 'package:shinsoku_mobile/services/profile_reason.dart';
import 'package:shinsoku_mobile/services/region_defaults.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

import 'host_fonts.dart';
import 'store_fixtures.dart';

/// iPhone 17 Pro Max / Air class, 6.9" (points); status bar + home indicator.
const _size = Size(440, 956);
const _padding = FakeViewPadding(top: 62, bottom: 34);
const _pixelRatio = 3.0;

/// Everything a scene needs, in the render's language.
class _Ctx {
  _Ctx(this.l, this.text, String language)
    : profiles = [
        ...localizedDefaultProfiles(
          l,
          translationSource: translationSourceLanguages.contains(language)
              ? language
              : null,
        ),
        VoiceProfile(
          id: 'custom-email',
          name: text.emailProfileName,
          intent: text.emailProfileIntent,
          commitSuffix: CommitSuffix.none,
          autoCommit: false,
        ),
      ];

  final AppLocalizations l;
  final StoreText text;
  final List<VoiceProfile> profiles;

  VoiceProfile byId(String id) => profiles.firstWhere((p) => p.id == id);
  VoiceProfile get translation => profiles[3];
}

typedef _Scene = Widget Function(_Ctx c);

/// Today at 9:41, like the status bar (drafts group by the real date).
final _now = () {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day, 9, 41);
}();

Widget _shell(_Ctx c, int index, Widget page) => ShellScaffold(
  tabIndex: index,
  secondaryIndex: index == 0 ? 1 : index,
  onTabSelected: (_) {},
  pages: [
    index == 0 ? page : const SizedBox.shrink(),
    index == 1 ? page : const SizedBox.shrink(),
    index == 2 ? page : const SizedBox.shrink(),
    index == 3 ? page : const SizedBox.shrink(),
  ],
);

Widget _record(
  _Ctx c, {
  CaptureState state = CaptureState.idle,
  SmokeTestStatus? status,
  LiveTranscript? live,
}) {
  final dictation = c.byId('dictation');
  return _shell(
    c,
    0,
    RecordView(
      transcript: live == null ? null : ValueNotifier(live),
      onSaveText: (_) {},
      onCopyText: (_) {},
      profiles: c.profiles,
      selectedProfileIndex: 0,
      captureState: state,
      microphoneAllowed: true,
      smokeTestStatus: status,
      onProfileSelected: (_) {},
      onCapturePressed: () {},
      onOpenMicrophoneSettings: () {},
      onOpenSettings: () {},
      profileReason: activeProfileReason(
        c.l,
        dictation.name,
        ProfileSource.byDefault,
      ),
    ),
  );
}

List<DraftEntry> _drafts(_Ctx c) => [
  DraftEntry(
    text: c.text.result,
    profileName: c.byId('dictation').name,
    createdAt: _now.subtract(const Duration(minutes: 2)),
  ),
  DraftEntry(
    text: c.text.errand,
    profileName: c.byId('chat').name,
    createdAt: _now.subtract(const Duration(minutes: 52)),
  ),
  DraftEntry(
    text: translatedDraft,
    profileName: c.translation.name,
    createdAt: _now.subtract(const Duration(hours: 1, minutes: 26)),
  ),
  DraftEntry(
    text: c.text.weekend,
    profileName: c.byId('dictation').name,
    createdAt: _now
        .add(const Duration(hours: 8, minutes: 37))
        .subtract(const Duration(days: 1)),
  ),
  DraftEntry(
    text: c.text.email,
    profileName: c.text.emailProfileName,
    createdAt: _now.subtract(const Duration(days: 3, minutes: 26)),
  ),
];

/// Store scenes in upload order (file names `NN-<scene>`).
final _scenes = <String, _Scene>{
  // Words appear live, mid-sentence.
  'record-live': (c) => _record(
    c,
    state: CaptureState.listening,
    live: LiveTranscript(
      committed: c.text.liveCommitted,
      pending: c.text.livePending,
      phase: LivePhase.listening,
    ),
  ),
  // Done: the cleaned text, editable, with the active profile.
  'record-done': (c) => _record(
    c,
    status: SmokeTestStatus(
      label: c.l.recordTranscribed,
      detail: '',
      transcript: c.text.result,
      finished: true,
    ),
  ),
  'drafts': (c) => _shell(
    c,
    1,
    DraftsView(
      drafts: _drafts(c),
      onDelete: (_) {},
      onEdit: (_) {},
      onCopy: (_) {},
    ),
  ),
  // Settings › Profiles on its own page (the section as Settings shows it),
  // so the screen starts at the heading; no key field in view.
  'profiles': (c) => _shell(
    c,
    3,
    SkPage(
      title: c.l.settingsSectionProfiles,
      children: [
        SettingsProfilesSection(
          profiles: c.profiles,
          label: '',
          onProfileAdded: () {},
          onProfileOpened: (_) {},
        ),
      ],
    ),
  ),
  'field-rules': (c) => FieldRulesView(
    profiles: c.profiles,
    rules: const FieldRules({
      FieldKind.message: 'chat',
      FieldKind.email: 'custom-email',
    }),
    onChanged: (_) async {},
  ),
  'desktop': (c) => _shell(
    c,
    2,
    NearbyMicrophoneView(
      profiles: [
        for (final p in c.profiles.take(3))
          NearbyProfileOption(id: p.id, label: p.name),
      ],
      previewConnected: true,
      initialDesktops: const [
        NearbyDesktop(
          serviceName: 'example-mac',
          host: '192.0.2.10',
          port: 39273,
          certificateSha256:
              '3f9a1c2b7d4e8f60a1b2c3d4e5f60718293a4b5c6d7e8f9012a3b4c5d6e7f809',
          instanceId: 'example-instance',
        ),
      ],
    ),
  ),
};

/// Steps after a scene settles, before the screenshot.
final _setups = <String, Future<void> Function(WidgetTester t, _Ctx c)>{
  // The picker for Email open, the custom profile selected.
  'field-rules': (t, c) async {
    await t.tap(find.text(c.text.emailProfileName));
    await t.pumpAndSettle();
  },
  'desktop': (t, c) async {
    // Scroll so the record button is in view below the paired desktop.
    final record = find.byKey(const ValueKey('nearby-record-button'));
    await t.scrollUntilVisible(
      record,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
  },
};

/// iOS-style status bar: 9:41, full signal, Wi-Fi, full battery.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final color = SkColors.of(context).text;
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 18, 36, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '9:41',
              style: TextStyle(
                fontFamily: 'CupertinoSystemText',
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in [4.0, 6.5, 9.0, 11.5]) ...[
                    Container(
                      width: 3,
                      height: h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 1.6),
                  ],
                  const SizedBox(width: 4),
                  Icon(Icons.wifi_rounded, size: 16, color: color),
                  const SizedBox(width: 6),
                  _Battery(color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 25,
        height: 12,
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(3.6),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(width: 1),
      Container(
        width: 1.6,
        height: 4,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(1),
          ),
        ),
      ),
    ],
  );
}

Locale _locale(String tag) {
  final parts = tag.split('-');
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: parts.length > 1 && parts[1].length == 4 ? parts[1] : null,
    countryCode: parts.length > 1 && parts.last.length == 2 ? parts.last : null,
  );
}

void main() {
  if (Platform.environment['SHINSOKU_STORE_SHOTS'] != '1') {
    test(
      'store screenshots (set SHINSOKU_STORE_SHOTS=1)',
      () {},
      skip: 'opt-in',
    );
    return;
  }
  final storeLocale = Platform.environment['SHINSOKU_STORE_LOCALE'] ?? 'en-US';
  final appTag = storeAppLocale[storeLocale];
  final text = storeText[storeLocale];
  if (appTag == null || text == null) {
    throw StateError('unknown store locale $storeLocale');
  }
  final out = Directory(
    '${Platform.environment['SHINSOKU_STORE_OUT'] ?? '../build/store/raw'}/'
    '$storeLocale',
  );
  if (!out.absolute.path.contains('/build/store/')) {
    throw StateError('store output must stay under build/store/');
  }
  final themes = (Platform.environment['SHINSOKU_STORE_THEMES'] ?? 'light')
      .split(',')
      .where((s) => s.isNotEmpty)
      .toSet();
  final locale = _locale(appTag);
  final fontPath = uiFontPath(appTag);

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.record/messages',
      'flutter.baseflow.com/permissions/methods',
      'plugins.it_nomads.com/flutter_secure_storage',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    await loadHostFonts(fontPath);
  });

  var index = 0;
  for (final MapEntry(key: scene, value: build) in _scenes.entries) {
    index++;
    final name = '${index.toString().padLeft(2, '0')}-$scene';
    for (final brightness in Brightness.values) {
      if (!themes.contains(brightness.name)) continue;
      testWidgets('$storeLocale $name ${brightness.name}', (t) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        EditableText.debugDeterministicCursor = true;
        debugDisableShadows = false;
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = _size;
        t.view.padding = _padding;
        t.view.viewPadding = _padding;
        final boundary = GlobalKey();
        late _Ctx ctx;
        try {
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: locale,
                debugShowCheckedModeBanner: false,
                theme: buildSkTheme(brightness),
                themeAnimationStyle: AnimationStyle.noAnimation,
                builder: (context, page) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: Stack(
                    children: [
                      page!,
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: Material(
                          type: MaterialType.transparency,
                          child: _StatusBar(),
                        ),
                      ),
                    ],
                  ),
                ),
                home: ProScope(
                  entitlement: FakeProEntitlement(owned: true),
                  child: Builder(
                    builder: (context) => build(
                      ctx = _Ctx(context.l10n, text, appTag.split('-')[0]),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          await _setups[scene]?.call(t, ctx);
          expect(t.takeException(), isNull);
          final clipped = _clipped(t.binding.rootElement!);
          for (final c in clipped) {
            debugPrint('CLIPPED $storeLocale/$name-${brightness.name}: $c');
          }
          await t.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: _pixelRatio);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            await out.create(recursive: true);
            final base = '${out.path}/$name-${brightness.name}';
            await File('$base.png').writeAsBytes(bytes!.buffer.asUint8List());
            await File('$base.json').writeAsString(
              jsonEncode({
                'scene': scene,
                'locale': storeLocale,
                'appLocale': appTag,
                'theme': brightness.name,
                'size': [_size.width * _pixelRatio, _size.height * _pixelRatio],
                'uiFont': fontPath.split('/').last,
                'clippedText': clipped,
              }),
            );
          });
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          t.view.reset();
          debugDefaultTargetPlatformOverride = null;
          EditableText.debugDeterministicCursor = false;
          debugDisableShadows = true;
        }
      });
    }
  }
}

/// Paragraphs that did not fit their max lines (draft previews are cut by
/// design; anything else is a defect to look at).
List<String> _clipped(Element root) {
  final clipped = <String>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph && object.didExceedMaxLines) {
      clipped.add(object.text.toPlainText());
    }
    object.visitChildren(visit);
  }

  final render = root.renderObject;
  if (render != null) visit(render);
  return clipped;
}
