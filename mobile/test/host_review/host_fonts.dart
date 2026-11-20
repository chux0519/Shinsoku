// Host fonts for tier-A renders (host review and store screenshots): SF Pro
// or the system CJK font in place of the iOS system font.
import 'dart:io';

import 'package:flutter/services.dart';

/// The host font that stands in for the iOS system font: SF Pro, or for a CJK
/// language the system CJK font (SF has no CJK glyphs and the test engine has
/// no per-character fallback, so CJK text would render as boxes). Latin text in
/// those renders uses the CJK font's Latin glyphs, slightly wider than SF.
String uiFontPath(String localeName) {
  final language = localeName.split('-').first;
  if (language == 'ja') return '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc';
  if (language == 'ko') return '/System/Library/Fonts/AppleSDGothicNeo.ttc';
  if (language == 'zh') {
    // PingFang ships as a font asset: AssetsV2/com_apple_MobileAsset_Font*/
    // <hash>.asset/AssetData/PingFang.ttc (other AssetsV2 folders are not
    // readable).
    String? pingFang;
    try {
      for (final fonts in Directory('/System/Library/AssetsV2').listSync()) {
        if (!fonts.path.contains('com_apple_MobileAsset_Font')) continue;
        for (final asset in Directory(fonts.path).listSync()) {
          final file = File('${asset.path}/AssetData/PingFang.ttc');
          if (file.existsSync()) pingFang ??= file.path;
        }
      }
    } on FileSystemException {
      pingFang = null;
    }
    return pingFang ?? '/System/Library/Fonts/Hiragino Sans GB.ttc';
  }
  return '/System/Library/Fonts/SFNS.ttf';
}

Future<void> loadHostFonts(String uiFontPath) async {
  // SF Pro from the host so text metrics match iOS. iOS typography asks for
  // CupertinoSystemText/Display; unnamed styles fall back to the test fonts,
  // so those map to SF too.
  final sf = ByteData.sublistView(await File(uiFontPath).readAsBytes());
  for (final name in [
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    '.AppleSystemUIFont',
    'Roboto',
    'FlutterTest',
    'Ahem',
  ]) {
    await (FontLoader(name)..addFont(Future.value(sf))).load();
  }
  final mono = ByteData.sublistView(
    await File('/System/Library/Fonts/SFNSMono.ttf').readAsBytes(),
  );
  for (final name in ['Menlo', 'Courier', 'monospace']) {
    await (FontLoader(name)..addFont(Future.value(mono))).load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
