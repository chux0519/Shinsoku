import 'package:flutter/foundation.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';

import 'nearby_models.dart';
import 'nearby_protocol.dart';

/// The error code a failure maps to; the raw detail only goes to the log.
String nearbyErrorCode(Object error) {
  debugPrint('Nearby failure: $error');
  if (error is NearbyProtocolException) return error.code ?? 'unknown';
  if (error is NearbyInputException) return error.code;
  return 'unknown';
}

/// What the Nearby status line says. Everything shown comes from the ARB;
/// [NearbyClientStatus.message] is English for logs only.
String nearbyStatusText(AppLocalizations l, NearbyClientStatus status) {
  final arg = status.arg ?? '';
  return switch (status.code) {
    'connecting' => l.nearbyConnectingTo(arg),
    'connected' => l.nearbyConnectedTo(arg),
    'streaming' => l.nearbyStreaming,
    'streaming_gaps' => l.nearbyStreamingGaps(int.tryParse(arg) ?? 0),
    'recording_sent' => l.nearbyRecordingSent,
    'not_connected_status' => l.nearbyNotConnected,
    'disconnected' => l.nearbyDisconnected,
    'searching' => l.nearbySearching,
    'none_found' => l.nearbyNoneFound,
    'found' => l.nearbyDesktopsFound(int.tryParse(arg) ?? 0),
    'trusted_selected' => l.nearbyTrustedSelected,
    'verify_fingerprint' => l.nearbyVerifyFingerprint,
    'trust_removed' => l.nearbyTrustRemoved,
    'pairing_code_required' => l.nearbyErrorPairingCodeRequired,
    'fingerprint_invalid' => l.nearbyErrorFingerprintInvalid,
    'endpoint_invalid' => l.nearbyErrorEndpointInvalid,
    'certificate_changed' => l.nearbyErrorCertificateChanged,
    'credential_missing' => l.nearbyErrorCredentialMissing,
    'pairing_unavailable' => l.nearbyErrorPairingUnavailable,
    'pairing_expired' => l.nearbyErrorPairingExpired,
    'invalid_proof' => l.nearbyErrorWrongCode,
    'attempts_exhausted' => l.nearbyErrorAttemptsExhausted,
    'audio_start_rejected' => l.nearbyErrorDesktopBusy,
    'not_connected' => l.nearbyErrorConnectFirst,
    'timeout' => l.nearbyErrorTimeout,
    'connection_closed' ||
    'connection_failed' ||
    'disconnected_error' => l.nearbyErrorConnectionLost,
    'mic_denied' => l.nearbyErrorMicDenied,
    'recorder_not_ready' => l.nearbyErrorRecorderNotReady,
    'mic_stream_failed' => l.nearbyErrorMicStream,
    'discovery_failed' => l.nearbyErrorDiscovery,
    'handshake_unexpected' ||
    'challenge_invalid' ||
    'pairing_prompt_invalid' ||
    'credential_invalid' ||
    'response_invalid' => l.nearbyErrorUnexpectedResponse,
    _ =>
      status.state == NearbyConnectionState.error
          ? l.nearbyErrorGeneric
          : l.nearbyNotConnected,
  };
}
