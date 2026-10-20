import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/nearby/nearby_models.dart';
import 'package:shinsoku_mobile/nearby/nearby_protocol.dart';

void main() {
  test('normalizes a manually configured pinned WSS desktop', () {
    final desktop = NearbyDesktop.manual(
      endpoint: '192.168.1.13:39273',
      certificateSha256:
          'AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:'
          'AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA',
    );

    expect(desktop.websocketUri.toString(), 'wss://192.168.1.13:39273');
    expect(desktop.certificateSha256, 'a' * 64);
    expect(desktop.discovered, isFalse);
  });

  test('matches the desktop pairing and authentication proof vectors', () {
    expect(
      nearbyPairingProof(
        code: '42',
        pairingId: '00112233445566778899aabbccddeeff',
        clientId: 'ios-client',
      ),
      'be5a48876cda47b9e5cf0af76bd2cbb0508ca30f6dee0cf3e7c37742731fb6d1',
    );

    expect(
      nearbyAuthenticationProof(
        credentialHex:
            '000102030405060708090a0b0c0d0e0f'
            '101112131415161718191a1b1c1d1e1f',
        challengeId: 'aabbccddeeff00112233445566778899',
        nonceHex:
            '0123456789abcdef0123456789abcdef'
            '0123456789abcdef0123456789abcdef',
        clientId: 'ios-client',
      ),
      '0da957882594b4910f7adc818fd3714393ed314c277feb5a0c46d28db13cd359',
    );
  });

  test('encodes the versioned PCM frame in network byte order', () {
    final frame = encodeNearbyAudioFrame(
      streamId: 0x01020304,
      sequence: 7,
      pcm16le: Uint8List.fromList([0x34, 0x12, 0xfe, 0xff]),
    );
    final header = ByteData.sublistView(frame);

    expect(String.fromCharCodes(frame.sublist(0, 4)), 'SNPA');
    expect(header.getUint8(4), nearbyProtocolVersion);
    expect(header.getUint16(6), 20);
    expect(header.getUint32(8), 0x01020304);
    expect(header.getUint32(12), 7);
    expect(header.getUint32(16), 2);
    expect(frame.sublist(20), [0x34, 0x12, 0xfe, 0xff]);
  });

  test('rejects malformed PCM frames and unpinned manual endpoints', () {
    expect(
      () => encodeNearbyAudioFrame(
        streamId: 1,
        sequence: 0,
        pcm16le: Uint8List.fromList([1]),
      ),
      throwsFormatException,
    );
    expect(
      () => NearbyDesktop.manual(
        endpoint: 'ws://127.0.0.1:39273',
        certificateSha256: 'a' * 64,
      ),
      throwsFormatException,
    );
  });
}
