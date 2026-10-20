import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'nearby_discovery.dart';
import 'nearby_models.dart';
import 'nearby_protocol.dart';

class NearbyProfileOption {
  const NearbyProfileOption({required this.id, required this.label});

  final String id;
  final String label;
}

class NearbyMicrophoneView extends StatefulWidget {
  const NearbyMicrophoneView({required this.profiles, super.key});

  final List<NearbyProfileOption> profiles;

  @override
  State<NearbyMicrophoneView> createState() => _NearbyMicrophoneViewState();
}

class _NearbyMicrophoneViewState extends State<NearbyMicrophoneView> {
  final NearbyDiscoveryService _discovery = NearbyDiscoveryService();
  final NearbyProtocolClient _client = NearbyProtocolClient();
  final AudioRecorder _recorder = AudioRecorder();
  final TextEditingController _pairingCodeController = TextEditingController();
  final TextEditingController _manualEndpointController = TextEditingController(
    text: 'wss://192.168.1.2:39273',
  );
  final TextEditingController _manualFingerprintController =
      TextEditingController();

  StreamSubscription<NearbyClientStatus>? _statusSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  List<NearbyDesktop> _desktops = const [];
  NearbyDesktop? _selectedDesktop;
  NearbyClientStatus _status = const NearbyClientStatus(
    state: NearbyConnectionState.disconnected,
    message: 'Not connected',
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
        message: 'Searching the local network',
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
          message: desktops.isEmpty
              ? 'No Shinsoku desktop found'
              : '${desktops.length} desktop${desktops.length == 1 ? '' : 's'} found',
        );
      });
      if (desktops.length == 1) {
        await _selectDesktop(desktops.first);
      }
    } catch (error) {
      _setError('Discovery failed: $error');
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
        message: trusted
            ? 'Trusted desktop selected'
            : 'Verify the desktop fingerprint',
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
      _setError(error.message);
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
        _setError(error.toString());
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
          message: 'Local trust removed',
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
        throw const NearbyProtocolException('Microphone access is required.');
      }
      if (!await _recorder.hasPermission(request: false)) {
        throw const NearbyProtocolException(
          'The microphone recorder is not ready.',
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
            _setError('Microphone stream failed: $error');
            unawaited(_stopRecording());
          },
        );
      } catch (_) {
        await _client.stopAudio();
        rethrow;
      }
    } catch (error) {
      _setError(error.toString());
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
      _setError(error.toString());
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

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = NearbyClientStatus(
        state: NearbyConnectionState.error,
        message: message.replaceFirst('NearbyProtocolException: ', ''),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedDesktop;
    final profiles = [
      const NearbyProfileOption(id: '', label: 'Desktop automatic'),
      ...widget.profiles,
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _NearbyHeader(),
            const SizedBox(height: 22),
            _StatusBanner(status: _status),
            const SizedBox(height: 18),
            Text('Desktop', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: const ValueKey('nearby-discover-button'),
                            onPressed: _busy || _recording ? null : _discover,
                            icon:
                                _busy &&
                                    _status.state ==
                                        NearbyConnectionState.discovering
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.radar),
                            label: const Text('Find Desktops'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Add desktop manually',
                          onPressed: _recording
                              ? null
                              : () {
                                  setState(() {
                                    _showManual = !_showManual;
                                  });
                                },
                          icon: const Icon(Icons.add_link),
                        ),
                      ],
                    ),
                    if (_showManual) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _manualEndpointController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'WSS endpoint',
                          prefixIcon: Icon(Icons.dns_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _manualFingerprintController,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9a-fA-F:\s]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Certificate SHA-256',
                          prefixIcon: Icon(Icons.fingerprint),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _addManualDesktop,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ),
                    ],
                    if (_desktops.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      RadioGroup<String>(
                        groupValue: selected?.id,
                        onChanged: (id) {
                          if (!_recording && id != null) {
                            final desktop = _desktops.firstWhere(
                              (candidate) => candidate.id == id,
                            );
                            unawaited(_selectDesktop(desktop));
                          }
                        },
                        child: Column(
                          children: [
                            for (final desktop in _desktops)
                              RadioListTile<String>(
                                value: desktop.id,
                                title: Text(desktop.serviceName),
                                subtitle: Text(
                                  '${desktop.host}:${desktop.port}',
                                ),
                                secondary: Icon(
                                  desktop.discovered
                                      ? Icons.wifi_tethering
                                      : Icons.link,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 18),
              Text('Trust', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _trusted
                                ? Icons.verified_user_outlined
                                : Icons.fingerprint,
                            color: _trusted ? scheme.primary : scheme.onSurface,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _trusted
                                  ? 'Trusted desktop'
                                  : 'Certificate fingerprint',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        formatCertificateFingerprint(
                          selected.certificateSha256,
                        ),
                        key: const ValueKey('nearby-certificate-fingerprint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (!_trusted) ...[
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _fingerprintConfirmed,
                          onChanged: (value) {
                            setState(() {
                              _fingerprintConfirmed = value ?? false;
                            });
                          },
                          title: const Text('Matches desktop Settings'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('nearby-pairing-code-field'),
                          controller: _pairingCodeController,
                          enabled: !_connected,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            counterText: '',
                            labelText: 'Two-digit pairing code',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              key: const ValueKey('nearby-connect-button'),
                              onPressed:
                                  _busy ||
                                      _connected ||
                                      (!_trusted && !_fingerprintConfirmed)
                                  ? null
                                  : _connect,
                              icon: const Icon(Icons.link),
                              label: Text(
                                _trusted ? 'Connect' : 'Pair and Connect',
                              ),
                            ),
                          ),
                          if (_connected) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Disconnect',
                              onPressed: _busy ? null : _disconnect,
                              icon: const Icon(Icons.link_off),
                            ),
                          ],
                          if (_trusted && !_recording) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Forget desktop',
                              onPressed: _busy ? null : _forget,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Remote Input',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('nearby-profile-field'),
                      initialValue:
                          profiles.any(
                            (profile) => profile.id == _selectedProfileId,
                          )
                          ? _selectedProfileId
                          : '',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Requested desktop Profile',
                        prefixIcon: Icon(Icons.tune),
                      ),
                      items: [
                        for (final profile in profiles)
                          DropdownMenuItem(
                            value: profile.id,
                            child: Text(profile.label),
                          ),
                      ],
                      onChanged: _recording
                          ? null
                          : (value) {
                              setState(() {
                                _selectedProfileId = value ?? '';
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    SizedBox.square(
                      dimension: 104,
                      child: FilledButton(
                        key: const ValueKey('nearby-record-button'),
                        onPressed: !_connected || _busy
                            ? null
                            : _recording
                            ? _stopRecording
                            : _startRecording,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: _recording ? scheme.error : null,
                        ),
                        child: Icon(
                          _recording ? Icons.stop : Icons.mic,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _recording
                          ? 'Stop and transcribe'
                          : 'Start remote dictation',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyHeader extends StatelessWidget {
  const _NearbyHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/app-icon.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Desktop Mic',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Private local connection',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final NearbyClientStatus status;

  @override
  Widget build(BuildContext context) {
    final error = status.state == NearbyConnectionState.error;
    final active =
        status.state == NearbyConnectionState.authenticated ||
        status.state == NearbyConnectionState.streaming;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error
            ? scheme.errorContainer
            : active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline
                  : active
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: error ? scheme.onErrorContainer : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(status.message)),
          ],
        ),
      ),
    );
  }
}
