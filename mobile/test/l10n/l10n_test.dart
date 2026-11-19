import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/l10n/failure_text.dart';
import 'package:shinsoku_mobile/nearby/nearby_models.dart';
import 'package:shinsoku_mobile/nearby/nearby_protocol.dart';
import 'package:shinsoku_mobile/nearby/nearby_text.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/theme.dart';

import '../support/l10n.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _placeholders(String message) => {
  for (final m in RegExp(r'\{(\w+)(?=[},])').allMatches(message)) m.group(1)!,
};

void main() {
  group('ARB files', () {
    final template = _arb('app_en.arb');
    final keys = template.keys.where((k) => !k.startsWith('@')).toList();
    final files = Directory('lib/l10n')
        .listSync()
        .map((f) => f.path.split('/').last)
        .where((n) => n.startsWith('app_') && n.endsWith('.arb'))
        .toList();

    test('every message has a description for the translator', () {
      for (final key in keys) {
        final meta = template['@$key'] as Map<String, dynamic>?;
        expect(meta?['description'], isA<String>(), reason: key);
        expect((meta!['description'] as String).trim(), isNotEmpty);
      }
    });

    test('keys are meanings, not English text', () {
      for (final key in keys) {
        expect(key, matches(RegExp(r'^[a-z][a-zA-Z0-9]*$')));
      }
    });

    test('every placeholder in the text is declared', () {
      for (final key in keys) {
        final declared = ((template['@$key'] as Map)['placeholders'] as Map?)
            ?.keys
            .toSet();
        expect(
          declared ?? <String>{},
          _placeholders(template[key] as String),
          reason: key,
        );
      }
    });

    test('the locale of each file has the same keys and placeholders', () {
      expect(files, contains('app_en_XA.arb'));
      for (final name in files) {
        final arb = _arb(name);
        expect(
          arb.keys.where((k) => !k.startsWith('@')).toSet(),
          keys.toSet(),
          reason: name,
        );
        for (final key in keys) {
          expect(
            _placeholders(arb[key] as String),
            _placeholders(template[key] as String),
            reason: '$name $key',
          );
        }
      }
    });

    test('the pseudo-locale is longer and bracketed (regenerate with '
        'tool/pseudo_arb.py)', () {
      final pseudo = _arb('app_en_XA.arb');
      for (final key in keys) {
        final text = pseudo[key] as String;
        expect(text, startsWith('['), reason: key);
        expect(text, endsWith(']'), reason: key);
        expect(
          text.length,
          greaterThan((template[key] as String).length),
          reason: key,
        );
      }
    });

    test('the app does not offer the pseudo-locale', () {
      expect(appSupportedLocales, isNot(contains(pseudoLocale)));
      expect(appSupportedLocales, contains(const Locale('en')));
    });
  });

  group('describeFailure', () {
    test('known failures become sentences with a next step', () {
      expect(describeFailure(en, TimeoutException('x')), en.failureTimeout);
      expect(
        describeFailure(en, const SocketException('x')),
        en.failureNetwork,
      );
      expect(describeFailure(en, http.ClientException('x')), en.failureNetwork);
      expect(
        describeFailure(
          en,
          StateError(
            'Provider credentials are missing. Save them in Settings first.',
          ),
        ),
        en.failureKeyMissing,
      );
      expect(describeFailure(en, StateError('HTTP 401')), en.failureKeyInvalid);
      expect(
        describeFailure(en, StateError('Throttling: rate limit exceeded')),
        en.failureQuota,
      );
      expect(
        describeFailure(en, StateError('Soniox connection closed before.')),
        en.failureConnectionLost,
      );
      expect(
        describeFailure(en, StateError('Soniox returned no transcript.')),
        en.failureNothingHeard,
      );
    });

    test('the exception text never reaches the person', () {
      const raw = 'Bad state: Soniox connection closed before the result.';
      final text = describeFailure(en, StateError(raw));
      expect(text, isNot(contains('Bad state')));
      expect(text, isNot(contains('StateError')));
      expect(
        describeFailure(en, StateError('zzz unknown failure 0xDEAD')),
        en.failureGeneric,
      );
    });
  });

  group('Nearby text', () {
    NearbyClientStatus coded(String code, {String? arg}) => NearbyClientStatus(
      state: NearbyConnectionState.error,
      logText: 'English log text',
      code: code,
      arg: arg,
    );

    test('every code the client emits has its own wording', () {
      const codes = [
        'connecting',
        'connected',
        'streaming',
        'streaming_gaps',
        'recording_sent',
        'not_connected_status',
        'disconnected',
        'searching',
        'none_found',
        'found',
        'trusted_selected',
        'verify_fingerprint',
        'trust_removed',
        'pairing_code_required',
        'fingerprint_invalid',
        'endpoint_invalid',
        'certificate_changed',
        'credential_missing',
        'pairing_unavailable',
        'pairing_expired',
        'invalid_proof',
        'attempts_exhausted',
        'audio_start_rejected',
        'not_connected',
        'timeout',
        'connection_closed',
        'connection_failed',
        'mic_denied',
        'recorder_not_ready',
        'mic_stream_failed',
        'discovery_failed',
        'handshake_unexpected',
        'response_invalid',
      ];
      for (final code in codes) {
        final text = nearbyStatusText(en, coded(code, arg: '2'));
        expect(text, isNot(en.nearbyErrorGeneric), reason: code);
        expect(text, isNot('English log text'), reason: code);
      }
    });

    test('counts use plural forms', () {
      expect(nearbyStatusText(en, coded('found', arg: '1')), '1 desktop found');
      expect(
        nearbyStatusText(en, coded('found', arg: '3')),
        '3 desktops found',
      );
      expect(
        nearbyStatusText(en, coded('streaming_gaps', arg: '1')),
        'Streaming with 1 missing frame',
      );
    });

    test('an unknown error shows the generic wording, not the log text', () {
      expect(
        nearbyStatusText(en, coded('never_heard_of_it')),
        en.nearbyErrorGeneric,
      );
    });

    test('protocol exceptions carry a code for every failure', () {
      expect(
        nearbyErrorCode(const NearbyProtocolException('x', code: 'timeout')),
        'timeout',
      );
      expect(
        nearbyErrorCode(const NearbyInputException('x', 'endpoint_invalid')),
        'endpoint_invalid',
      );
      expect(nearbyErrorCode(StateError('x')), 'unknown');
    });
  });

  group('built-in profiles', () {
    test('are created from the strings of the language', () async {
      final profiles = localizedDefaultProfiles(en);
      expect(profiles.map((p) => p.id), [
        for (final p in defaultVoiceProfiles) p.id,
      ]);
      expect(profiles.map((p) => p.name), [
        for (final p in defaultVoiceProfiles) p.name,
      ]);
      final pseudo = await AppLocalizations.delegate.load(pseudoLocale);
      expect(
        localizedDefaultProfiles(pseudo).first.name,
        isNot(profiles.first.name),
      );
    });
  });

  testWidgets('Drafts date groups follow the locale', (tester) async {
    final old = DateTime(2020, 3, 5, 9, 30);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: DraftsView(
          drafts: [
            DraftEntry(text: 'Old.', profileName: 'Chat', createdAt: old),
            DraftEntry(
              text: 'New.',
              profileName: 'Chat',
              createdAt: DateTime.now(),
            ),
          ],
          onDelete: (_) {},
          onEdit: (_) {},
          onCopy: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text(en.draftsToday.toUpperCase()), findsOneWidget);
    expect(find.text('MARCH 5, 2020'), findsOneWidget);
  });
}
