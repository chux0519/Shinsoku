// Tier A UI review: render real screens on the host (no simulator) for every
// scene × device × theme and write PNGs. Run through tool/host_review.sh,
// which also writes the index.html contact sheet.
//
// Not covered here (tier B/C): the keyboard extension, native fonts beyond
// the host's SF Pro, real safe areas and the real iPhone Duo fold (the
// *-fold devices use a fake centre hinge line).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/ui/theme.dart';

import 'host_fonts.dart';
import 'scenes.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';

class _Device {
  const _Device(this.size, this.padding, {this.textScale = 1, this.fold});

  final Size size;
  final FakeViewPadding padding;
  final double textScale;

  /// A fake iPhone Duo division region (window coordinates), fed in as a
  /// hinge display feature like the native bridge does.
  final Rect? fold;
}

/// Logical points. Safe areas follow the task brief for iPhone 17 and the
/// iPhone Duo (outer: trailing only; inner: top/bottom portrait, trailing
/// landscape).
const _devices = <String, _Device>{
  'iphone': _Device(Size(402, 874), FakeViewPadding(top: 62, bottom: 34)),
  'duo-outer': _Device(Size(466, 678), FakeViewPadding(right: 84)),
  'duo-inner-portrait': _Device(
    Size(669, 951),
    FakeViewPadding(top: 84, bottom: 95),
  ),
  'duo-inner-landscape': _Device(Size(951, 669), FakeViewPadding(right: 84)),
};

/// Inner display with a fake fold at the centre (0-width hinge line), for
/// [foldScenes]. Real region sizes when folded are pending tier B.
const _foldDevices = <String, _Device>{
  'duo-inner-landscape-fold': _Device(
    Size(951, 669),
    FakeViewPadding(right: 84),
    fold: Rect.fromLTWH(475.5, 0, 0, 669),
  ),
  'duo-inner-portrait-fold': _Device(
    Size(669, 951),
    FakeViewPadding(top: 84, bottom: 95),
    fold: Rect.fromLTWH(0, 475.5, 669, 0),
  ),
};

/// Dynamic Type review size (2.0×) on the iPhone, for [largeTextScenes].
const _largeText = _Device(
  Size(402, 874),
  FakeViewPadding(top: 62, bottom: 34),
  textScale: 2.0,
);

Set<String> _envSet(String name) => (Platform.environment[name] ?? '')
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toSet();

void main() {
  if (Platform.environment['SHINSOKU_HOST_REVIEW'] != '1') {
    test('host review (set SHINSOKU_HOST_REVIEW=1)', () {}, skip: 'opt-in');
    return;
  }
  final out = Directory(
    Platform.environment['SHINSOKU_HOST_REVIEW_OUT'] ??
        '../build/ui-review/host-review',
  );
  if (!out.absolute.path.contains('/build/ui-review/')) {
    throw StateError('host review output must stay under build/ui-review/');
  }
  final onlyScenes = _envSet('SHINSOKU_HOST_REVIEW_SCENES');
  final onlyDevices = _envSet('SHINSOKU_HOST_REVIEW_DEVICES');
  final themes = _envSet('SHINSOKU_HOST_REVIEW_THEMES');
  // en (default), pseudo (accented, ~40% longer: unextracted strings stay
  // plain English, overflow shows), or a locale tag such as ja or zh-Hant.
  final localeName =
      Platform.environment['SHINSOKU_HOST_REVIEW_LOCALE'] ?? 'en';
  final pseudo = localeName == 'pseudo';
  final locale = pseudo
      ? pseudoLocale
      : Locale.fromSubtags(
          languageCode: localeName.split('-').first,
          scriptCode:
              localeName.contains('-') && localeName.split('-')[1].length == 4
              ? localeName.split('-')[1]
              : null,
          countryCode:
              localeName.contains('-') && localeName.split('-').last.length == 2
              ? localeName.split('-').last
              : null,
        );

  final fontPath = uiFontPath(localeName);

  final runs = <(String scene, String device, _Device spec)>[
    for (final scene in scenes.keys) ...[
      for (final MapEntry(key: device, value: spec) in _devices.entries)
        (scene, device, spec),
      if (largeTextScenes.contains(scene))
        (scene, 'iphone-text200', _largeText),
      if (foldScenes.contains(scene))
        for (final MapEntry(key: device, value: spec) in _foldDevices.entries)
          (scene, device, spec),
    ],
  ];

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Plugins answer nothing: screens that construct a recorder or read
    // permissions render their resting state without native code.
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

  for (final (scene, device, spec) in runs) {
    if (onlyScenes.isNotEmpty && !onlyScenes.contains(scene)) continue;
    if (onlyDevices.isNotEmpty && !onlyDevices.contains(device)) continue;
    for (final brightness in Brightness.values) {
      final theme = brightness.name;
      if (themes.isNotEmpty && !themes.contains(theme)) continue;
      testWidgets('$scene $device $theme', (t) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        EditableText.debugDeterministicCursor = true;
        // flutter_test draws shadows as solid outlines by default.
        debugDisableShadows = false;
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = spec.size;
        t.view.padding = spec.padding;
        t.view.viewPadding = spec.padding;
        final boundary = GlobalKey();
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
                // A still frame: Reduce Motion turns spinners into a still
                // arc, so pumpAndSettle never waits on an endless animation.
                builder: (context, page) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(spec.textScale),
                    displayFeatures: [
                      if (spec.fold != null)
                        ui.DisplayFeature(
                          bounds: spec.fold!,
                          type: ui.DisplayFeatureType.hinge,
                          state: ui.DisplayFeatureState.postureHalfOpened,
                        ),
                    ],
                  ),
                  child: page!,
                ),
                home: scenes[scene]!(),
              ),
            ),
          );
          await t.pumpAndSettle();
          await sceneSetups[scene]?.call(t, device);
          // Overflow and layout errors fail the scene.
          expect(t.takeException(), isNull);
          // So does localized text cut off by its line limit (pseudo strings
          // start with '[', which an ellipsis would replace at the end); the
          // image is written first so the cut can be looked at.
          // (Not at 200% text: pseudo text that long is beyond the goal.)
          // Other locales: cut paragraphs are listed in the .json and the
          // log (sample transcripts may be cut by design), not failed.
          final clipped = localeName != 'en' && spec.textScale == 1
              ? _clippedLocalizedText(
                  t.binding.rootElement!,
                  pseudoOnly: pseudo,
                )
              : const <String>[];
          for (final text in clipped) {
            debugPrint('CLIPPED $device/$scene-$theme: $text');
          }
          await t.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            final dir = Directory('${out.path}/$device');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/$scene-$theme.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            await File('${dir.path}/$scene-$theme.json').writeAsString(
              jsonEncode({
                'scene': scene,
                'device': device,
                'theme': theme,
                'width': spec.size.width,
                'height': spec.size.height,
                'safeArea': {
                  'top': spec.padding.top,
                  'bottom': spec.padding.bottom,
                  'left': spec.padding.left,
                  'right': spec.padding.right,
                },
                'locale': localeName,
                'textScale': spec.textScale,
                if (spec.fold case final fold?)
                  'fold': {
                    'left': fold.left,
                    'top': fold.top,
                    'width': fold.width,
                    'height': fold.height,
                  },
                'uiFont': fontPath.split('/').last,
                if (clipped.isNotEmpty) 'clippedText': clipped,
              }),
            );
          });
          if (pseudo) {
            expect(clipped, isEmpty, reason: 'clipped text: $clipped');
          }
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

/// Paragraphs that did not fit their max lines; with [pseudoOnly], only
/// pseudo-locale strings (they start with '[').
List<String> _clippedLocalizedText(Element root, {required bool pseudoOnly}) {
  final clipped = <String>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph &&
        object.didExceedMaxLines &&
        (!pseudoOnly || object.text.toPlainText().startsWith('['))) {
      final owner = (object.debugCreator as DebugCreator).element;
      clipped.add(
        '${object.text.toPlainText()} in '
        '${owner.debugGetCreatorChain(pseudoOnly ? 8 : 3)}',
      );
    }
    object.visitChildren(visit);
  }

  final render = root.renderObject;
  if (render != null) visit(render);
  return clipped;
}
