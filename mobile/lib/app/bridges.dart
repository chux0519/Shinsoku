import 'dart:async';

import 'package:flutter/services.dart';

class KeyboardBridge {
  static const MethodChannel _channel = MethodChannel(
    'net.potafree.shinsoku/keyboard_bridge',
  );

  static Future<void> publishText(String text) async {
    // Sent as is: a profile's commit suffix (space, new line) is part of it.
    if (text.trim().isEmpty) {
      return;
    }

    await _channel.invokeMethod<void>('publishLatestText', {'text': text});
  }
}

class DeepLinkBridge {
  static const MethodChannel channel = MethodChannel(
    'net.potafree.shinsoku/deep_link',
  );
}
