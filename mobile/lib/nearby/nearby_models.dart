/// A manual-entry mistake; [code] picks the localized wording.
class NearbyInputException extends FormatException {
  const NearbyInputException(super.message, this.code);

  final String code;
}

class NearbyDesktop {
  const NearbyDesktop({
    required this.serviceName,
    required this.host,
    required this.port,
    required this.certificateSha256,
    required this.instanceId,
    this.discovered = true,
  });

  final String serviceName;
  final String host;
  final int port;
  final String certificateSha256;
  final String instanceId;
  final bool discovered;

  Uri get websocketUri => Uri(scheme: 'wss', host: host, port: port);

  String get id => '$instanceId@$host:$port';

  factory NearbyDesktop.manual({
    required String endpoint,
    required String certificateSha256,
  }) {
    final raw = endpoint.trim();
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'wss://$raw');
    final fingerprint = normalizeCertificateFingerprint(certificateSha256);
    if (uri == null ||
        uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.port <= 0 ||
        uri.port > 65535) {
      throw const NearbyInputException(
        'Enter a valid wss:// host and port.',
        'endpoint_invalid',
      );
    }
    if (!isCertificateFingerprint(fingerprint)) {
      throw const NearbyInputException(
        'Enter the desktop certificate SHA-256 fingerprint.',
        'fingerprint_invalid',
      );
    }
    return NearbyDesktop(
      serviceName: uri.host,
      host: uri.host,
      port: uri.port,
      certificateSha256: fingerprint,
      instanceId: 'manual-${fingerprint.substring(0, 24)}',
      discovered: false,
    );
  }
}

String normalizeCertificateFingerprint(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
}

bool isCertificateFingerprint(String value) {
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}

String formatCertificateFingerprint(String value) {
  final normalized = normalizeCertificateFingerprint(value);
  if (!isCertificateFingerprint(normalized)) {
    return value;
  }
  return [
    for (var offset = 0; offset < normalized.length; offset += 8)
      normalized.substring(offset, offset + 8),
  ].join(' ');
}

enum NearbyConnectionState {
  disconnected,
  discovering,
  connecting,
  pairingRequired,
  authenticated,
  streaming,
  error,
}

class NearbyClientStatus {
  const NearbyClientStatus({
    required this.state,
    required this.message,
    this.code,
    this.arg,
    this.missingFrames = 0,
  });

  final NearbyConnectionState state;

  /// English detail for logs; the UI shows text chosen by [code] (see
  /// `nearby_text.dart`).
  final String message;
  final String? code;

  /// The value a coded message mentions (a desktop name or a count).
  final String? arg;
  final int missingFrames;
}
