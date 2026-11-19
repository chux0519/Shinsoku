import 'package:flutter/services.dart';

/// Opens the Shortcuts app (`shortcuts://`) through the profiles channel.
/// Returns false when it could not be opened.
Future<bool> openShortcutsApp() async {
  try {
    final opened = await const MethodChannel('net.potafree.shinsoku/profiles')
        .invokeMethod<bool>('openShortcuts');
    return opened ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
