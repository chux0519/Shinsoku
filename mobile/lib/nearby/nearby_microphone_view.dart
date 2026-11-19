import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

import 'nearby_discovery.dart';
import 'nearby_models.dart';
import 'nearby_protocol.dart';
import 'nearby_text.dart';

class NearbyProfileOption {
  const NearbyProfileOption({required this.id, required this.label});

  final String id;
  final String label;
}

class NearbyMicrophoneView extends StatefulWidget {
  const NearbyMicrophoneView({
    required this.profiles,
    @visibleForTesting this.initialDesktops = const [],
    super.key,
  });

  final List<NearbyProfileOption> profiles;

  /// Host renders only: start with these desktops listed and the first one
  /// selected (untrusted), without discovery.
  final List<NearbyDesktop> initialDesktops;

  @override
  State<NearbyMicrophoneView> createState() => _NearbyMicrophoneViewState();
}

class _NearbyMicrophoneViewState extends State<NearbyMicrophoneView> {
  final NearbyDiscoveryService _discovery = NearbyDiscoveryService();
  final NearbyProtocolClient _client = NearbyProtocolClient();
  final AudioRecorder _recorder = AudioRecorder();
  final TextEditingController _pairingCodeController = TextEditingController();
  final TextEditingController _manualEndpointController = TextEditingController(
    text: 'wss://192.168.1.2:39273', // i18n-ignore: example address
  );
  final TextEditingController _manualFingerprintController =
      TextEditingController();

  StreamSubscription<NearbyClientStatus>? _statusSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  List<NearbyDesktop> _desktops = const [];
  NearbyDesktop? _selectedDesktop;
  NearbyClientStatus _status = const NearbyClientStatus(
    state: NearbyConnectionState.disconnected,
    logText: 'Not connected',
    code: 'not_connected_status',
  );
  String _selectedProfileId = '';
  bool _busy = false;
  bool _trusted = false;
  bool _fingerprintConfirmed = false;
  bool _showManual = false;

  bool get _recording =>
      _audioSubscription != null ||
      _client.state == NearbyConnectionState.streaming;
  bool get _connected => _client.authenticated;

  @override
  void initState() {
    super.initState();
    if (widget.initialDesktops.isNotEmpty) {
      _desktops = widget.initialDesktops;
      _selectedDesktop = widget.initialDesktops.first;
      _status = const NearbyClientStatus(
        state: NearbyConnectionState.disconnected,
        logText: 'Verify the desktop fingerprint',
        code: 'verify_fingerprint',
      );
    }
    _statusSubscription = _client.statuses.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
        if (_audioSubscription != null &&
            (status.state == NearbyConnectionState.disconnected ||
                status.state == NearbyConnectionState.error)) {
          unawaited(_abortLocalRecording());
        }
      }
    });
  }

  @override
  void dispose() {
    unawaited(_audioSubscription?.cancel());
    unawaited(_recorder.dispose());
    unawaited(_client.dispose());
    unawaited(_statusSubscription?.cancel());
    _pairingCodeController.dispose();
    _manualEndpointController.dispose();
    _manualFingerprintController.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    if (_busy || _recording) {
      return;
    }
    setState(() {
      _busy = true;
      _status = const NearbyClientStatus(
        state: NearbyConnectionState.discovering,
        logText: 'Searching the local network',
        code: 'searching',
      );
    });
    try {
      final desktops = await _discovery.discover();
      if (!mounted) {
        return;
      }
      setState(() {
        _desktops = desktops;
        _status = NearbyClientStatus(
          state: NearbyConnectionState.disconnected,
          logText: '${desktops.length} desktop(s) found',
          code: desktops.isEmpty ? 'none_found' : 'found',
          arg: '${desktops.length}',
        );
      });
      if (desktops.length == 1) {
        await _selectDesktop(desktops.first);
      }
    } catch (error) {
      _setError(error, fallback: 'discovery_failed');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _selectDesktop(NearbyDesktop desktop) async {
    if (_recording) {
      return;
    }
    if (_connected) {
      await _client.disconnect();
    }
    final trusted = await _client.isTrusted(desktop);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDesktop = desktop;
      _trusted = trusted;
      _fingerprintConfirmed = trusted;
      _pairingCodeController.clear();
      _status = NearbyClientStatus(
        state: NearbyConnectionState.disconnected,
        logText: trusted
            ? 'Trusted desktop selected'
            : 'Verify the desktop fingerprint',
        code: trusted ? 'trusted_selected' : 'verify_fingerprint',
      );
    });
  }

  Future<void> _addManualDesktop() async {
    try {
      final desktop = NearbyDesktop.manual(
        endpoint: _manualEndpointController.text,
        certificateSha256: _manualFingerprintController.text,
      );
      final desktops = [
        ..._desktops.where((candidate) => candidate.id != desktop.id),
        desktop,
      ];
      setState(() {
        _desktops = desktops;
        _showManual = false;
      });
      await _selectDesktop(desktop);
    } on FormatException catch (error) {
      _setError(error);
    }
  }

  Future<void> _connect() async {
    final desktop = _selectedDesktop;
    if (desktop == null || _busy || (!_trusted && !_fingerprintConfirmed)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
    });
    try {
      await _client.connect(
        desktop,
        pairingCode: _pairingCodeController.text.trim(),
      );
      final trusted = await _client.isTrusted(desktop);
      if (mounted) {
        setState(() {
          _trusted = trusted;
          _fingerprintConfirmed = trusted;
          _pairingCodeController.clear();
        });
      }
    } catch (error) {
      if (error is! NearbyProtocolException ||
          error.code != 'pairing_code_required') {
        _setError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    if (_recording) {
      if (_client.state == NearbyConnectionState.streaming) {
        await _stopRecording();
      } else {
        await _abortLocalRecording();
      }
    }
    await _client.disconnect();
  }

  Future<void> _forget() async {
    final desktop = _selectedDesktop;
    if (desktop == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    await _client.forget(desktop);
    if (mounted) {
      setState(() {
        _trusted = false;
        _fingerprintConfirmed = false;
        _busy = false;
        _status = const NearbyClientStatus(
          state: NearbyConnectionState.disconnected,
          logText: 'Local trust removed',
          code: 'trust_removed',
        );
      });
    }
  }

  Future<void> _startRecording() async {
    if (!_connected || _busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted && !permission.isLimited) {
        throw const NearbyProtocolException(
          'Microphone access is required.',
          code: 'mic_denied',
        );
      }
      if (!await _recorder.hasPermission(request: false)) {
        throw const NearbyProtocolException(
          'The microphone recorder is not ready.',
          code: 'recorder_not_ready',
        );
      }

      await _client.startAudio(profileId: _selectedProfileId);
      try {
        final audio = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: nearbySampleRate,
            numChannels: nearbyChannels,
            streamBufferSize: 3200,
          ),
        );
        _audioSubscription = audio.listen(
          _client.sendPcm,
          onError: (Object error) {
            _setError(error, fallback: 'mic_stream_failed');
            unawaited(_stopRecording());
          },
        );
      } catch (_) {
        await _client.stopAudio();
        rethrow;
      }
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) {
      return;
    }
    final ownsBusyState = !_busy;
    if (ownsBusyState && mounted) {
      setState(() {
        _busy = true;
      });
    }
    try {
      await _recorder.stop();
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      if (_client.state == NearbyConnectionState.streaming) {
        await _client.stopAudio();
      }
    } catch (error) {
      _setError(error);
    } finally {
      if (ownsBusyState && mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _abortLocalRecording() async {
    final subscription = _audioSubscription;
    if (subscription == null) {
      return;
    }
    _audioSubscription = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // The recorder may already have stopped after a stream failure.
    }
    await subscription.cancel();
    if (mounted) {
      setState(() {});
    }
  }

  /// Shows a failure as a coded status; the raw detail goes to the log.
  void _setError(Object error, {String? fallback}) {
    if (!mounted) {
      return;
    }
    final code = nearbyErrorCode(error);
    setState(() {
      _status = NearbyClientStatus(
        state: NearbyConnectionState.error,
        logText: error.toString(),
        code: code == 'unknown' ? fallback : code,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final l = context.l10n;
    final selected = _selectedDesktop;
    final profiles = [
      NearbyProfileOption(id: '', label: l.nearbyProfileAutomatic),
      ...widget.profiles,
    ];
    final profileLabel = profiles
        .firstWhere(
          (profile) => profile.id == _selectedProfileId,
          orElse: () => profiles.first,
        )
        .label;
    const gap = SizedBox(height: SkSpace.xl);

    return SkPage(
      title: l.nearbyTitle,
      subtitle: l.nearbySubtitle,
      children: [
        _NearbyStatusLine(status: _status),
        gap,
        SkSection(
          label: l.nearbySectionDesktop,
          children: [
            SkSectionBody(
              child: Row(
                children: [
                  Expanded(
                    child: SkButton.secondary(
                      key: const ValueKey('nearby-discover-button'),
                      label: l.nearbyFindDesktops,
                      icon: Icons.radar,
                      expand: true,
                      onPressed: _busy || _recording ? null : _discover,
                    ),
                  ),
                  const SizedBox(width: SkSpace.s),
                  SkIconButton(
                    tooltip: l.nearbyAddManually,
                    icon: Icons.add_link,
                    onPressed: _recording
                        ? null
                        : () => setState(() => _showManual = !_showManual),
                  ),
                ],
              ),
            ),
            if (_showManual)
              SkSectionBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SkTextArea.field(
                      controller: _manualEndpointController,
                      label: l.nearbyEndpointLabel,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: SkSpace.m),
                    SkTextArea.field(
                      controller: _manualFingerprintController,
                      label: l.nearbyCertificateLabel,
                      style: SkType.body.merge(SkType.mono),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9a-fA-F:\s]'),
                        ),
                      ],
                    ),
                    const SizedBox(height: SkSpace.m),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SkButton.secondary(
                        label: l.nearbyAdd,
                        icon: Icons.add,
                        onPressed: _addManualDesktop,
                      ),
                    ),
                  ],
                ),
              ),
            for (final desktop in _desktops)
              SkListRow(
                leading: desktop.discovered ? Icons.wifi_tethering : Icons.link,
                title: desktop.serviceName,
                subtitle: '${desktop.host}:${desktop.port}',
                selected: selected?.id == desktop.id,
                onTap: _recording
                    ? null
                    : () => unawaited(_selectDesktop(desktop)),
              ),
          ],
        ),
        if (selected != null) ...[
          gap,
          SkSection(
            label: l.nearbySectionTrust,
            children: [
              SkSectionBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _trusted
                              ? Icons.verified_user_outlined
                              : Icons.fingerprint,
                          size: 20,
                          color: _trusted ? c.success : c.textSecondary,
                        ),
                        const SizedBox(width: SkSpace.s),
                        Expanded(
                          child: Text(
                            _trusted
                                ? l.nearbyTrustedDesktop
                                : l.nearbyCertificateFingerprint,
                            style: SkType.title.copyWith(color: c.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SkSpace.s),
                    SelectableText(
                      formatCertificateFingerprint(selected.certificateSha256),
                      key: const ValueKey('nearby-certificate-fingerprint'),
                      style: SkType.secondary
                          .merge(SkType.mono)
                          .copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!_trusted) ...[
                SkListRow.toggle(
                  title: l.nearbyMatchesTitle,
                  subtitle: l.nearbyMatchesSubtitle,
                  value: _fingerprintConfirmed,
                  onChanged: (value) =>
                      setState(() => _fingerprintConfirmed = value),
                ),
                SkSectionBody(
                  child: SkTextArea.field(
                    fieldKey: const ValueKey('nearby-pairing-code-field'),
                    controller: _pairingCodeController,
                    label: l.nearbyPairingCodeLabel,
                    placeholder: '--',
                    enabled: !_connected,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    style: SkType.mono.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 12,
                      height: 1.2,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
              SkSectionBody(
                child: Row(
                  children: [
                    Expanded(
                      child: _connected
                          ? SkButton.secondary(
                              label: l.nearbyDisconnect,
                              icon: Icons.link_off,
                              expand: true,
                              onPressed: _busy ? null : _disconnect,
                            )
                          : SkButton(
                              key: const ValueKey('nearby-connect-button'),
                              label: _trusted
                                  ? l.nearbyConnect
                                  : l.nearbyPairAndConnect,
                              icon: Icons.link,
                              expand: true,
                              onPressed:
                                  _busy || (!_trusted && !_fingerprintConfirmed)
                                  ? null
                                  : _connect,
                            ),
                    ),
                    if (_trusted && !_recording) ...[
                      const SizedBox(width: SkSpace.s),
                      SkIconButton(
                        tooltip: l.nearbyForget,
                        icon: Icons.delete_outline,
                        onPressed: _busy ? null : _forget,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
        gap,
        SkSection(
          label: l.nearbySectionRemoteInput,
          children: [
            SkListRow(
              key: const ValueKey('nearby-profile-field'),
              leading: Icons.tune,
              title: l.nearbyProfileRow,
              value: profileLabel,
              chevron: true,
              onTap: _recording ? null : () => _pickProfile(profiles),
            ),
          ],
        ),
        gap,
        Center(
          child: SkRecordButton(
            key: const ValueKey('nearby-record-button'),
            state: _recording
                ? SkRecordState.listening
                : !_connected
                ? SkRecordState.unavailable
                : _busy
                ? SkRecordState.processing
                : SkRecordState.idle,
            semanticLabel: _recording
                ? l.nearbyStopAndTranscribe
                : l.nearbyStartRemote,
            onPressed: !_connected || _busy
                ? null
                : _recording
                ? _stopRecording
                : _startRecording,
          ),
        ),
        const SizedBox(height: SkSpace.s),
        Text(
          _recording
              ? l.nearbyStopAndTranscribe
              : _connected
              ? l.nearbyStartRemote
              : l.nearbyConnectToDictate,
          textAlign: TextAlign.center,
          style: SkType.secondary.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }

  Future<void> _pickProfile(List<NearbyProfileOption> profiles) async {
    final picked = await showSkSheet<String>(
      context: context,
      builder: (context) => SkSheet(
        title: context.l10n.nearbyProfileSheetTitle,
        child: SkSection(
          children: [
            for (final profile in profiles)
              SkListRow(
                title: profile.label,
                selected: profile.id == _selectedProfileId,
                onTap: () => Navigator.of(context).pop(profile.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedProfileId = picked);
    }
  }
}

class _NearbyStatusLine extends StatelessWidget {
  const _NearbyStatusLine({required this.status});

  final NearbyClientStatus status;

  @override
  Widget build(BuildContext context) {
    final text = nearbyStatusText(context.l10n, status);
    return switch (status.state) {
      NearbyConnectionState.error => SkStatusLine(
        icon: Icons.error_outline_rounded,
        tone: SkTone.danger,
        text: text,
      ),
      NearbyConnectionState.discovering ||
      NearbyConnectionState.connecting => SkStatusLine(busy: true, text: text),
      NearbyConnectionState.pairingRequired => SkStatusLine(
        icon: Icons.pin_outlined,
        tone: SkTone.warning,
        text: text,
      ),
      NearbyConnectionState.authenticated => SkStatusLine(
        icon: Icons.check_circle_outline_rounded,
        tone: SkTone.success,
        text: text,
      ),
      NearbyConnectionState.streaming => SkStatusLine(
        icon: Icons.fiber_manual_record_rounded,
        tone: SkTone.danger,
        text: text,
      ),
      NearbyConnectionState.disconnected => SkStatusLine(
        icon: Icons.info_outline_rounded,
        text: text,
      ),
    };
  }
}
