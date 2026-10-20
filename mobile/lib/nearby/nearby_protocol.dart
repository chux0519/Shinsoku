import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/io.dart';

import 'nearby_models.dart';

const nearbyProtocolVersion = 1;
const nearbySampleRate = 16000;
const nearbyChannels = 1;
const nearbyMaxFrameSamples = 3200;

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List _decodeHex(String value) {
  if (value.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    throw const FormatException('Invalid hexadecimal value.');
  }
  return Uint8List.fromList([
    for (var offset = 0; offset < value.length; offset += 2)
      int.parse(value.substring(offset, offset + 2), radix: 16),
  ]);
}

String nearbyPairingProof({
  required String code,
  required String pairingId,
  required String clientId,
}) {
  final payload = 'shinsoku-nearby-pair/v1\n$pairingId\n$clientId';
  return _hex(
    Hmac(sha256, utf8.encode(code)).convert(utf8.encode(payload)).bytes,
  );
}

String nearbyAuthenticationProof({
  required String credentialHex,
  required String challengeId,
  required String nonceHex,
  required String clientId,
}) {
  final verifier = sha256.convert(_decodeHex(credentialHex)).bytes;
  final payload = 'shinsoku-nearby-auth/v1\n$challengeId\n$nonceHex\n$clientId';
  return _hex(Hmac(sha256, verifier).convert(utf8.encode(payload)).bytes);
}

Uint8List encodeNearbyAudioFrame({
  required int streamId,
  required int sequence,
  required Uint8List pcm16le,
}) {
  if (streamId <= 0 ||
      pcm16le.isEmpty ||
      pcm16le.length.isOdd ||
      pcm16le.length ~/ 2 > nearbyMaxFrameSamples) {
    throw const FormatException('Invalid Nearby PCM frame.');
  }
  final frame = Uint8List(20 + pcm16le.length);
  frame.setRange(0, 4, ascii.encode('SNPA'));
  final header = ByteData.sublistView(frame);
  header.setUint8(4, nearbyProtocolVersion);
  header.setUint8(5, 0);
  header.setUint16(6, 20, Endian.big);
  header.setUint32(8, streamId, Endian.big);
  header.setUint32(12, sequence, Endian.big);
  header.setUint32(16, pcm16le.length ~/ 2, Endian.big);
  frame.setRange(20, frame.length, pcm16le);
  return frame;
}

class NearbyCredential {
  const NearbyCredential({
    required this.credentialHex,
    required this.certificateSha256,
  });

  final String credentialHex;
  final String certificateSha256;
}

abstract class NearbyCredentialStore {
  Future<String> loadOrCreateClientId();
  Future<NearbyCredential?> read(String certificateSha256);
  Future<void> write(NearbyCredential credential);
  Future<void> delete(String certificateSha256);
}

class SecureNearbyCredentialStore implements NearbyCredentialStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _clientIdKey = 'nearby.client-id.v1';

  @override
  Future<String> loadOrCreateClientId() async {
    final existing = await _storage.read(key: _clientIdKey);
    if (existing != null && RegExp(r'^[0-9a-f]{32}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final clientId = _hex(List<int>.generate(16, (_) => random.nextInt(256)));
    await _storage.write(key: _clientIdKey, value: clientId);
    return clientId;
  }

  String _credentialKey(String fingerprint) =>
      'nearby.credential.v1.${normalizeCertificateFingerprint(fingerprint)}';

  @override
  Future<NearbyCredential?> read(String certificateSha256) async {
    final fingerprint = normalizeCertificateFingerprint(certificateSha256);
    final credential = await _storage.read(key: _credentialKey(fingerprint));
    if (credential == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(credential)) {
      return null;
    }
    return NearbyCredential(
      credentialHex: credential,
      certificateSha256: fingerprint,
    );
  }

  @override
  Future<void> write(NearbyCredential credential) {
    return _storage.write(
      key: _credentialKey(credential.certificateSha256),
      value: credential.credentialHex,
    );
  }

  @override
  Future<void> delete(String certificateSha256) {
    return _storage.delete(key: _credentialKey(certificateSha256));
  }
}

class NearbyProtocolException implements Exception {
  const NearbyProtocolException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class _ResponseWaiter {
  _ResponseWaiter(this.types, this.completer, this.timer);

  final Set<String> types;
  final Completer<Map<String, dynamic>> completer;
  final Timer timer;
}

class NearbyProtocolClient {
  NearbyProtocolClient({NearbyCredentialStore? credentialStore})
    : _credentialStore = credentialStore ?? SecureNearbyCredentialStore();

  final NearbyCredentialStore _credentialStore;
  final _statusController = StreamController<NearbyClientStatus>.broadcast();
  final List<_ResponseWaiter> _waiters = [];
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  HttpClient? _httpClient;
  NearbyDesktop? _desktop;
  String? _clientId;
  int? _streamId;
  int _sequence = 0;
  Uint8List _partialPcm = Uint8List(0);
  NearbyConnectionState _state = NearbyConnectionState.disconnected;
  int _missingFrames = 0;

  Stream<NearbyClientStatus> get statuses => _statusController.stream;
  NearbyConnectionState get state => _state;
  NearbyDesktop? get desktop => _desktop;
  bool get authenticated =>
      _state == NearbyConnectionState.authenticated ||
      _state == NearbyConnectionState.streaming;

  Future<bool> isTrusted(NearbyDesktop desktop) async {
    return await _credentialStore.read(desktop.certificateSha256) != null;
  }

  Future<void> forget(NearbyDesktop desktop) async {
    await disconnect();
    await _credentialStore.delete(desktop.certificateSha256);
  }

  Future<void> connect(NearbyDesktop desktop, {String pairingCode = ''}) async {
    await disconnect();
    final fingerprint = normalizeCertificateFingerprint(
      desktop.certificateSha256,
    );
    if (!isCertificateFingerprint(fingerprint)) {
      throw const NearbyProtocolException(
        'The desktop certificate fingerprint is invalid.',
      );
    }
    final stored = await _credentialStore.read(fingerprint);
    if (stored != null && stored.certificateSha256 != fingerprint) {
      throw const NearbyProtocolException(
        'The desktop certificate has changed. Forget it and pair again.',
      );
    }

    _desktop = desktop;
    _clientId = await _credentialStore.loadOrCreateClientId();
    _emit(
      NearbyConnectionState.connecting,
      'Connecting to ${desktop.serviceName}',
    );

    final securityContext = SecurityContext(withTrustedRoots: false);
    final httpClient = HttpClient(context: securityContext)
      ..connectionTimeout = const Duration(seconds: 5)
      ..badCertificateCallback = (certificate, host, port) {
        return _constantTimeEquals(
          sha256.convert(certificate.der).toString(),
          fingerprint,
        );
      };
    _httpClient = httpClient;
    final channel = IOWebSocketChannel.connect(
      desktop.websocketUri,
      customClient: httpClient,
      pingInterval: const Duration(seconds: 15),
      connectTimeout: const Duration(seconds: 6),
    );
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleMessage,
      onError: _handleTransportError,
      onDone: _handleTransportDone,
      cancelOnError: false,
    );

    try {
      await channel.ready.timeout(const Duration(seconds: 7));
      final response = await _sendAndWait(
        {
          'type': 'hello',
          'protocol_version': nearbyProtocolVersion,
          'client': {
            'id': _clientId,
            'name': Platform.isIOS ? 'Shinsoku on iPhone' : 'Shinsoku Mobile',
            'kind': Platform.isIOS ? 'iphone' : 'android',
          },
        },
        {'auth.challenge', 'pairing.required', 'pairing.unavailable'},
      );
      switch (response['type']) {
        case 'auth.challenge':
          if (stored == null) {
            throw const NearbyProtocolException(
              'This desktop remembers the device, but its local credential is missing. Revoke it on desktop and pair again.',
              code: 'credential_missing',
            );
          }
          await _authenticate(response, stored);
          break;
        case 'pairing.required':
          if (!RegExp(r'^\d{2}$').hasMatch(pairingCode)) {
            _emit(
              NearbyConnectionState.pairingRequired,
              'Enter the two-digit code shown on desktop.',
            );
            throw const NearbyProtocolException(
              'Enter the two-digit code shown on desktop.',
              code: 'pairing_code_required',
            );
          }
          await _pair(response, pairingCode, fingerprint);
          break;
        case 'pairing.unavailable':
          throw const NearbyProtocolException(
            'Create a pairing code in desktop Settings, then connect again.',
            code: 'pairing_unavailable',
          );
        default:
          throw const NearbyProtocolException(
            'The desktop sent an unexpected handshake response.',
          );
      }
      _emit(
        NearbyConnectionState.authenticated,
        'Connected to ${desktop.serviceName}',
      );
    } catch (error) {
      if (_state != NearbyConnectionState.pairingRequired) {
        _emit(NearbyConnectionState.error, error.toString());
      }
      await _closeTransport();
      rethrow;
    }
  }

  Future<void> _authenticate(
    Map<String, dynamic> challenge,
    NearbyCredential credential,
  ) async {
    final challengeId = challenge['challenge_id'];
    final nonce = challenge['nonce'];
    if (challengeId is! String || nonce is! String) {
      throw const NearbyProtocolException(
        'The desktop sent an invalid authentication challenge.',
      );
    }
    await _sendAndWait(
      {
        'type': 'auth.prove',
        'challenge_id': challengeId,
        'proof': nearbyAuthenticationProof(
          credentialHex: credential.credentialHex,
          challengeId: challengeId,
          nonceHex: nonce,
          clientId: _clientId!,
        ),
      },
      {'auth.accepted'},
    );
  }

  Future<void> _pair(
    Map<String, dynamic> prompt,
    String code,
    String fingerprint,
  ) async {
    final pairingId = prompt['pairing_id'];
    if (pairingId is! String) {
      throw const NearbyProtocolException(
        'The desktop sent an invalid pairing prompt.',
      );
    }
    final response = await _sendAndWait(
      {
        'type': 'pairing.prove',
        'pairing_id': pairingId,
        'proof': nearbyPairingProof(
          code: code,
          pairingId: pairingId,
          clientId: _clientId!,
        ),
      },
      {'pairing.accepted'},
    );
    final credential = response['credential'];
    if (credential is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(credential)) {
      throw const NearbyProtocolException(
        'The desktop returned an invalid trust credential.',
      );
    }
    await _credentialStore.write(
      NearbyCredential(
        credentialHex: credential,
        certificateSha256: fingerprint,
      ),
    );
  }

  Future<void> startAudio({String profileId = ''}) async {
    if (!authenticated || _channel == null || _streamId != null) {
      throw const NearbyProtocolException(
        'Connect to a desktop before recording.',
      );
    }
    final random = Random.secure();
    final streamId = random.nextInt(0x7ffffffe) + 1;
    await _sendAndWait(
      {
        'type': 'audio.start',
        'stream_id': streamId,
        'profile_id': profileId,
        'format': {
          'encoding': 'pcm16le',
          'sample_rate_hz': nearbySampleRate,
          'channels': nearbyChannels,
        },
      },
      {'audio.ready'},
    );
    _streamId = streamId;
    _sequence = 0;
    _partialPcm = Uint8List(0);
    _missingFrames = 0;
    _emit(NearbyConnectionState.streaming, 'Streaming microphone audio');
  }

  void sendPcm(Uint8List chunk) {
    final streamId = _streamId;
    final channel = _channel;
    if (streamId == null || channel == null || chunk.isEmpty) {
      return;
    }
    final combined = Uint8List(_partialPcm.length + chunk.length)
      ..setRange(0, _partialPcm.length, _partialPcm)
      ..setRange(_partialPcm.length, _partialPcm.length + chunk.length, chunk);
    var offset = 0;
    final maximumBytes = nearbyMaxFrameSamples * 2;
    while (combined.length - offset >= 2) {
      final available = combined.length - offset;
      final frameBytes = min(available - (available % 2), maximumBytes);
      if (frameBytes <= 0) {
        break;
      }
      channel.sink.add(
        encodeNearbyAudioFrame(
          streamId: streamId,
          sequence: _sequence++,
          pcm16le: Uint8List.sublistView(combined, offset, offset + frameBytes),
        ),
      );
      offset += frameBytes;
    }
    _partialPcm = Uint8List.sublistView(combined, offset);
  }

  Future<void> stopAudio() async {
    final streamId = _streamId;
    if (streamId == null) {
      return;
    }
    _streamId = null;
    _partialPcm = Uint8List(0);
    await _sendAndWait(
      {'type': 'audio.stop', 'stream_id': streamId},
      {'audio.stopped'},
    );
    _emit(NearbyConnectionState.authenticated, 'Recording sent to desktop');
  }

  Future<void> disconnect() async {
    if (_streamId != null) {
      try {
        await stopAudio();
      } catch (_) {
        _streamId = null;
      }
    }
    await _closeTransport();
    _desktop = null;
    _emit(NearbyConnectionState.disconnected, 'Not connected');
  }

  Future<Map<String, dynamic>> _sendAndWait(
    Map<String, dynamic> message,
    Set<String> responseTypes,
  ) {
    final channel = _channel;
    if (channel == null) {
      throw const NearbyProtocolException('The desktop connection is closed.');
    }
    final completer = Completer<Map<String, dynamic>>();
    late final _ResponseWaiter waiter;
    final timer = Timer(const Duration(seconds: 7), () {
      _waiters.remove(waiter);
      if (!completer.isCompleted) {
        completer.completeError(
          const NearbyProtocolException('The desktop did not respond in time.'),
        );
      }
    });
    waiter = _ResponseWaiter(responseTypes, completer, timer);
    _waiters.add(waiter);
    channel.sink.add(jsonEncode(message));
    return completer.future;
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final message = Map<String, dynamic>.from(decoded);
      final type = message['type'];
      if (type == 'audio.gap') {
        _missingFrames += (message['missing_frames'] as num?)?.toInt() ?? 0;
        _emit(_state, 'Streaming with $_missingFrames missing frame(s)');
        return;
      }
      final waiterIndex = _waiters.indexWhere(
        (waiter) =>
            waiter.types.contains(type) ||
            type == 'error' ||
            type == 'pairing.error',
      );
      if (waiterIndex < 0) {
        return;
      }
      final waiter = _waiters.removeAt(waiterIndex);
      waiter.timer.cancel();
      if (type == 'error' || type == 'pairing.error') {
        waiter.completer.completeError(
          NearbyProtocolException(
            message['message'] as String? ??
                _friendlyProtocolError(message['code'] as String?),
            code: message['code'] as String?,
          ),
        );
      } else {
        waiter.completer.complete(message);
      }
    } catch (error) {
      _failWaiters(NearbyProtocolException('Invalid desktop response: $error'));
    }
  }

  String _friendlyProtocolError(String? code) {
    return switch (code) {
      'invalid_proof' => 'The pairing code is incorrect.',
      'attempts_exhausted' =>
        'Pairing attempts are exhausted. Create a new desktop code.',
      'pairing_expired' => 'The desktop pairing code expired.',
      'pairing_unavailable' => 'Create a pairing code in desktop Settings.',
      'audio_start_rejected' =>
        'The desktop is already recording or processing audio.',
      _ => 'The desktop rejected the request${code == null ? '' : ' ($code)'}.',
    };
  }

  void _handleTransportError(Object error, StackTrace stackTrace) {
    _failWaiters(NearbyProtocolException('Desktop connection failed: $error'));
    _clearClosedTransport();
    _emit(NearbyConnectionState.error, 'Desktop connection failed');
  }

  void _handleTransportDone() {
    _failWaiters(const NearbyProtocolException('The desktop disconnected.'));
    _clearClosedTransport();
    if (_state != NearbyConnectionState.disconnected &&
        _state != NearbyConnectionState.error) {
      _emit(NearbyConnectionState.disconnected, 'Desktop disconnected');
    }
  }

  void _clearClosedTransport() {
    _subscription = null;
    _channel = null;
    _streamId = null;
    _partialPcm = Uint8List(0);
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  void _failWaiters(Object error) {
    for (final waiter in List<_ResponseWaiter>.of(_waiters)) {
      waiter.timer.cancel();
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(error);
      }
    }
    _waiters.clear();
  }

  Future<void> _closeTransport() async {
    _failWaiters(
      const NearbyProtocolException('The desktop connection closed.'),
    );
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    _streamId = null;
    _partialPcm = Uint8List(0);
    await subscription?.cancel();
    if (channel != null) {
      await channel.sink.close();
    }
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  void _emit(NearbyConnectionState state, String message) {
    _state = state;
    if (!_statusController.isClosed) {
      _statusController.add(
        NearbyClientStatus(
          state: state,
          message: message,
          missingFrames: _missingFrames,
        ),
      );
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
  }
}

bool _constantTimeEquals(String left, String right) {
  final maximum = max(left.length, right.length);
  var difference = left.length ^ right.length;
  for (var index = 0; index < maximum; ++index) {
    final leftCode = index < left.length ? left.codeUnitAt(index) : 0;
    final rightCode = index < right.length ? right.codeUnitAt(index) : 0;
    difference |= leftCode ^ rightCode;
  }
  return difference == 0;
}
