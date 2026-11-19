import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'l10n.dart';

/// What a failure looks like to a person: a short sentence with the next
/// step, never the exception text (i18n-01 I1, review rule M10). The raw
/// detail goes to the log only. Provider messages are English and not ours,
/// so they are classified here and never shown.
String describeFailure(AppLocalizations l, Object error) {
  debugPrint('Failure: $error');
  final text = error.toString().toLowerCase();
  if (error is TimeoutException) return l.failureTimeout;
  if (error is SocketException ||
      error is HttpException ||
      error is HandshakeException ||
      error is WebSocketException ||
      error is http.ClientException) {
    return l.failureNetwork;
  }
  if (text.contains('credentials are missing') ||
      text.contains('missing') && text.contains('api key')) {
    return l.failureKeyMissing;
  }
  if (text.contains('401') ||
      text.contains('403') ||
      text.contains('unauthor') ||
      text.contains('invalid api') ||
      text.contains('invalid_api') ||
      text.contains('incorrect api') ||
      text.contains('authentication') ||
      text.contains('forbidden')) {
    return l.failureKeyInvalid;
  }
  if (text.contains('429') ||
      text.contains('quota') ||
      text.contains('insufficient') ||
      text.contains('arrearage') ||
      text.contains('rate limit') ||
      text.contains('balance')) {
    return l.failureQuota;
  }
  if (text.contains('connection closed') ||
      text.contains('connection failed') ||
      text.contains('websocket') ||
      text.contains('socket')) {
    return l.failureConnectionLost;
  }
  if (text.contains('returned no transcript') ||
      text.contains('no transcript')) {
    return l.failureNothingHeard;
  }
  if (text.contains('recording')) return l.failureRecording;
  if (text.contains('microphone')) return l.failureMicrophone;
  return l.failureGeneric;
}
