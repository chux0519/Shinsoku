import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shinsoku_mobile/main.dart';
import 'package:shinsoku_mobile/nearby/nearby_models.dart';
import 'package:shinsoku_mobile/nearby/nearby_protocol.dart';

const fixtureEndpoint = String.fromEnvironment('SHINSOKU_NEARBY_ENDPOINT');
const fixtureFingerprint = String.fromEnvironment(
  'SHINSOKU_NEARBY_FINGERPRINT',
);
const fixturePairingCode = String.fromEnvironment(
  'SHINSOKU_NEARBY_PAIRING_CODE',
);
const screenshotHoldSeconds = int.fromEnvironment(
  'SHINSOKU_SCREENSHOT_HOLD_SECONDS',
);

class _MemoryCredentialStore implements NearbyCredentialStore {
  final Map<String, NearbyCredential> credentials = {};

  @override
  Future<String> loadOrCreateClientId() async =>
      '00112233445566778899aabbccddeeff';

  @override
  Future<NearbyCredential?> read(String certificateSha256) async =>
      credentials[normalizeCertificateFingerprint(certificateSha256)];

  @override
  Future<void> write(NearbyCredential credential) async {
    credentials[credential.certificateSha256] = credential;
  }

  @override
  Future<void> delete(String certificateSha256) async {
    credentials.remove(normalizeCertificateFingerprint(certificateSha256));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pairs, streams PCM, and reconnects with long-term trust', (
    tester,
  ) async {
    expect(fixtureEndpoint, isNotEmpty, reason: 'fixture endpoint is required');
    expect(fixtureFingerprint, hasLength(64));
    expect(fixturePairingCode, matches(RegExp(r'^\d{2}$')));

    final desktop = NearbyDesktop.manual(
      endpoint: fixtureEndpoint,
      certificateSha256: fixtureFingerprint,
    );
    final store = _MemoryCredentialStore();
    final client = NearbyProtocolClient(credentialStore: store);
    addTearDown(client.dispose);

    await client.connect(desktop, pairingCode: fixturePairingCode);
    expect(client.authenticated, isTrue);
    expect(await client.isTrusted(desktop), isTrue);

    await client.startAudio(profileId: 'default');
    expect(client.state, NearbyConnectionState.streaming);
    final pcm = Uint8List(3200);
    for (var offset = 0; offset < pcm.length; offset += 2) {
      pcm[offset] = offset & 0xff;
      pcm[offset + 1] = (offset >> 8) & 0xff;
    }
    client.sendPcm(pcm);
    await tester.pump(const Duration(milliseconds: 100));
    await client.stopAudio();
    expect(client.state, NearbyConnectionState.authenticated);

    await client.disconnect();
    await client.connect(desktop);
    expect(client.authenticated, isTrue);
    await client.disconnect();
  });

  testWidgets('renders the Desktop Mic workflow on iPhone', (tester) async {
    await tester.pumpWidget(const ShinsokuMobileApp(initialTabIndex: 2));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Desktop Mic'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('nearby-discover-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nearby-profile-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('nearby-record-button')), findsOneWidget);

    final screenshot = await binding.takeScreenshot('desktop-mic');
    await File(
      '${Directory.systemTemp.path}/shinsoku-desktop-mic.png',
    ).writeAsBytes(screenshot, flush: true);
    if (screenshotHoldSeconds > 0) {
      await tester.pump(Duration(seconds: screenshotHoldSeconds));
    }
  });
}
