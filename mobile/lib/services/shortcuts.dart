import 'package:flutter/services.dart';

/// Opens the Shortcuts app (`shortcuts://`) through the profiles channel.
/// Returns false when it could not be opened.
Future<bool> openShortcutsApp() async {
  try {
    final opened = await const MethodChannel(
      'net.potafree.shinsoku/profiles',
    ).invokeMethod<bool>('openShortcuts');
    return opened ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// The iOS major version, or null when unknown (tests, other platforms).
Future<int?> systemMajorVersion() async {
  try {
    final v = await const MethodChannel(
      'net.potafree.shinsoku/profiles',
    ).invokeMethod<int>('systemMajorVersion');
    return v == null || v <= 0 ? null : v;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}
