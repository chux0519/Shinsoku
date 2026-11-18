import 'dart:async';

import 'package:flutter/services.dart';

class KeyboardBridge {
  static const MethodChannel _channel = MethodChannel(
    'net.potafree.shinsoku/keyboard_bridge',
  );

  static Future<void> publishText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _channel.invokeMethod<void>('publishLatestText', {'text': trimmed});
  }
}

class DeepLinkBridge {
  static const MethodChannel channel = MethodChannel(
    'net.potafree.shinsoku/deep_link',
  );
}
