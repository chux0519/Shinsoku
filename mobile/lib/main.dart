import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/services/drafts.dart';

void main() {
  runApp(const ShinsokuMobileApp());
}

class ShinsokuMobileApp extends StatelessWidget {
  const ShinsokuMobileApp({
    this.initialDrafts = const [],
    this.initialTabIndex = 0,
    super.key,
  });

  final List<DraftEntry> initialDrafts;
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF256D7B);

    return MaterialApp(
      title: 'Shinsoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: MobileShell(
        initialDrafts: initialDrafts,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}

class KeyboardBridge {
  static const MethodChannel _channel = MethodChannel(
    'net.potafree.shinsoku/keyboard_bridge',
  );

  static Future<void> publishText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _channel.invokeMethod<void>('publishLatestText', {'text': trimmed});
  }
}

class DeepLinkBridge {
  static const MethodChannel channel = MethodChannel(
    'net.potafree.shinsoku/deep_link',
  );
}

class MobileShell extends StatefulWidget {
  const MobileShell({
    this.initialDrafts = const [],
    this.initialTabIndex = 0,
    super.key,
  });

  final List<DraftEntry> initialDrafts;
  final int initialTabIndex;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> with WidgetsBindingObserver {
  final ProviderSettingsStore _providerSettingsStore = ProviderSettingsStore();
  final VoiceProfileStore _voiceProfileStore = VoiceProfileStore();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<VoiceProfile> _profiles = List<VoiceProfile>.of(defaultVoiceProfiles);
  late final List<DraftEntry> _drafts;

  late int _tabIndex;
  int _selectedProfileIndex = 0;
  CaptureState _captureState = CaptureState.idle;
  bool _microphoneAllowed = false;
  bool _keyboardExtensionEnabled = false;
  bool _cloudProcessingEnabled = false;
  bool _providerSettingsLoading = true;
  bool _providerSettingsSaving = false;
  ProviderSettings _providerSettings = ProviderSettings.defaults();
  SmokeTestStatus? _smokeTestStatus;
  String? _recordingPath;
  BailianRealtimeLiveSession? _bailianLiveSession;
  StreamSubscription<Uint8List>? _recordingStreamSubscription;
  Object? _recordingStreamError;

  VoiceProfile get _activeProfile => _profiles[_selectedProfileIndex];

  @override
  void initState() {
    super.initState();

    _drafts = List<DraftEntry>.of(widget.initialDrafts);
    _tabIndex = widget.initialTabIndex.clamp(0, 3);

    WidgetsBinding.instance.addObserver(this);
    DeepLinkBridge.channel.setMethodCallHandler(_handleDeepLinkMethodCall);
    unawaited(_consumeInitialDeepLink());
    if (SmokeTestConfig.mode == 'soniox') {
      unawaited(_runSonioxSmokeTest());
    } else if (SmokeTestConfig.mode == 'bailian') {
      unawaited(_runBailianSmokeTest());
    }
    unawaited(_loadProviderSettings());
    unawaited(_loadVoiceProfiles());
    unawaited(_refreshMicrophonePermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkBridge.channel.setMethodCallHandler(null);
    unawaited(_recordingStreamSubscription?.cancel());
    unawaited(_bailianLiveSession?.close());
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_consumeInitialDeepLink());
    }
  }

  Future<dynamic> _handleDeepLinkMethodCall(MethodCall call) async {
    if (call.method == 'openURL' && call.arguments is String) {
      await _handleDeepLink(call.arguments as String);
    }
  }

  Future<void> _consumeInitialDeepLink() async {
    try {
      final url = await DeepLinkBridge.channel.invokeMethod<String>(
        'consumeInitialURL',
      );
      if (url != null) {
        await _handleDeepLink(url);
      }
    } catch (_) {
      // Deep links are best-effort; normal app launch should continue.
    }
  }

  Future<void> _handleDeepLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'shinsoku') {
      return;
    }
    if (uri.host == 'dictation' || uri.pathSegments.contains('dictation')) {
      await _handleKeyboardRecordRequest();
    }
  }

  Future<void> _handleKeyboardRecordRequest() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _tabIndex = 0;
    });

    if (_captureState != CaptureState.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shinsoku is already recording.')),
      );
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || _captureState != CaptureState.idle) {
      return;
    }
    await _startRecording();
  }

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  bool _profileNeedsPostProcessing(VoiceProfile profile) {
    return profile.id != 'review' && profile.intent.trim().isNotEmpty;
  }

  Future<void> _selectProfile(int index) async {
    final profile = _profiles[index];
    setState(() {
      _selectedProfileIndex = index;
    });
    await _ensurePostProcessingForProfile(profile);
  }

  Future<void> _ensurePostProcessingForProfile(VoiceProfile profile) async {
    if (!_profileNeedsPostProcessing(profile) ||
        _providerSettings.textTransformEnabled) {
      return;
    }

    final settings = _providerSettings.copyWith(textTransformEnabled: true);
    try {
      await _saveProviderSettings(settings);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Text post-processing enabled for ${profile.name}.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post-processing setting was not saved: $error'),
        ),
      );
    }
  }

  Future<void> _publishTextWithFeedback(
    String text, {
    required String message,
  }) async {
    try {
      await KeyboardBridge.publishText(text);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clipboard update failed: $error')),
      );
    }
  }

  Future<void> _toggleCapture() async {
    if (_captureState == CaptureState.idle) {
      await _startRecording();
      return;
    }

    await _stopRecordingAndTranscribe();
  }

  Future<void> _startRecording() async {
    final permission = await Permission.microphone.request();
    final hasPermission = permission.isGranted || permission.isLimited;
    if (!hasPermission) {
      if (!mounted) {
        return;
      }
      setState(() {
        _microphoneAllowed = false;
        _tabIndex = 2;
        _smokeTestStatus = const SmokeTestStatus(
          label: 'Microphone permission required',
          detail:
              'Allow microphone access in iOS Settings, then try recording again.',
          failed: true,
          finished: true,
        );
      });
      return;
    }

    final recorderReady = await _audioRecorder.hasPermission(request: false);
    if (!recorderReady) {
      if (!mounted) {
        return;
      }
      setState(() {
        _microphoneAllowed = false;
        _smokeTestStatus = const SmokeTestStatus(
          label: 'Recording failed',
          detail:
              'Microphone permission was granted but the recorder is not ready.',
          failed: true,
          finished: true,
        );
      });
      return;
    }

    if (!_providerSettings.activeProviderConfigured) {
      setState(() {
        _microphoneAllowed = true;
        _tabIndex = 2;
        _smokeTestStatus = const SmokeTestStatus(
          label: 'Provider settings required',
          detail: 'Save a Bailian or Soniox API key before recording.',
          failed: true,
          finished: true,
        );
      });
      return;
    }

    _recordingStreamError = null;
    _recordingPath = null;
    _bailianLiveSession = null;
    await _recordingStreamSubscription?.cancel();
    _recordingStreamSubscription = null;

    try {
      final shouldStreamBailian =
          _providerSettings.speechProvider == 'bailian' &&
          _providerSettings.bailianAsrMode == bailianAsrModeRealtime;
      if (!shouldStreamBailian) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/shinsoku-${DateTime.now().microsecondsSinceEpoch}.wav';
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: bailianRealtimeSampleRate,
            numChannels: bailianRealtimeChannels,
          ),
          path: path,
        );
        _recordingPath = path;
      } else {
        final session = await BailianRealtimeLiveSession.start(
          _providerSettings,
        );
        try {
          final stream = await _audioRecorder.startStream(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: bailianRealtimeSampleRate,
              numChannels: bailianRealtimeChannels,
              streamBufferSize: bailianRealtimeStreamBufferSize,
            ),
          );
          _bailianLiveSession = session;
          _recordingStreamSubscription = stream.listen(
            session.addPcm,
            onError: (Object error) {
              _recordingStreamError = error;
              unawaited(session.close());
            },
          );
        } catch (_) {
          await session.close();
          rethrow;
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _microphoneAllowed = true;
        _captureState = CaptureState.idle;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Recording failed',
          detail: error.toString(),
          failed: true,
          finished: true,
        );
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _microphoneAllowed = true;
      _captureState = CaptureState.listening;
      _smokeTestStatus = null;
    });
  }

  Future<void> _stopRecordingAndTranscribe() async {
    final stopTotalWatch = Stopwatch()..start();
    final liveSession = _bailianLiveSession;
    final streamSubscription = _recordingStreamSubscription;
    _bailianLiveSession = null;
    _recordingStreamSubscription = null;
    final recorderStopWatch = Stopwatch()..start();
    final path = await _audioRecorder.stop() ?? _recordingPath;
    recorderStopWatch.stop();
    final streamCancelWatch = Stopwatch()..start();
    await streamSubscription?.cancel();
    streamCancelWatch.stop();
    _recordingPath = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _captureState = CaptureState.processing;
      _smokeTestStatus = const SmokeTestStatus(
        label: 'Transcribing recording',
        detail: 'Uploading recorded audio to the selected provider.',
      );
    });

    try {
      final streamError = _recordingStreamError;
      _recordingStreamError = null;
      final service = RealTranscriptionService(settings: _providerSettings);
      late final RealTranscriptionResult result;
      final transcribeWatch = Stopwatch()..start();
      if (liveSession != null) {
        if (streamError != null) {
          await liveSession.close();
          throw StateError('Recording stream failed: $streamError');
        }
        result = await service.finishBailianRealtimeSession(
          session: liveSession,
          profile: _activeProfile,
        );
      } else {
        if (path == null || !File(path).existsSync()) {
          throw StateError('Recording file was not created.');
        }
        final audio = await File(path).readAsBytes();
        if (audio.isEmpty) {
          throw StateError('Recording file is empty.');
        }

        result = await service.transcribe(
          wavBytes: audio,
          profile: _activeProfile,
        );
      }
      transcribeWatch.stop();
      stopTotalWatch.stop();
      final finalDetail =
          '${result.detail} appRecorderStop=${recorderStopWatch.elapsedMilliseconds}ms '
          'appStreamCancel=${streamCancelWatch.elapsedMilliseconds}ms '
          'appTranscribe=${transcribeWatch.elapsedMilliseconds}ms '
          'appStopToDraft=${stopTotalWatch.elapsedMilliseconds}ms';
      debugPrint('SHINSOKU_RECORDING_E2E $finalDetail');

      final draft = DraftEntry(
        text: result.text,
        profileName: result.provider,
        createdAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _captureState = CaptureState.idle;
        _drafts.insert(0, draft);
        _tabIndex = 1;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Recording transcribed',
          detail: finalDetail,
          transcript: result.text,
          finished: true,
        );
      });
      await _publishTextWithFeedback(
        draft.text,
        message: 'Transcript copied to clipboard.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Recording failed',
          detail: error.toString(),
          failed: true,
          finished: true,
        );
      });
    } finally {
      if (path != null) {
        unawaited(File(path).delete().catchError((_) => File(path)));
      }
    }
  }

  Future<void> _refreshMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (!mounted) {
      return;
    }
    setState(() {
      _microphoneAllowed = status.isGranted || status.isLimited;
    });
  }

  Future<void> _handleMicrophoneSettingsPressed() async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    }
    await _refreshMicrophonePermission();
  }

  void _deleteDraft(DraftEntry draft) {
    setState(() {
      _drafts.remove(draft);
    });
  }

  Future<void> _showDraftEditor(DraftEntry draft) async {
    final result = await Navigator.of(context).push<_DraftEditResult>(
      MaterialPageRoute<_DraftEditResult>(
        fullscreenDialog: true,
        builder: (context) => DraftEditorScreen(draft: draft),
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    final index = _drafts.indexOf(draft);
    if (index < 0) {
      return;
    }
    setState(() {
      _drafts[index] = draft.copyWith(text: result.text);
    });

    if (result.copyToClipboard) {
      await _publishTextWithFeedback(
        result.text,
        message: 'Draft saved and copied to clipboard.',
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft updated.')));
  }

  Future<void> _loadVoiceProfiles() async {
    final profiles = await _voiceProfileStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      if (_selectedProfileIndex >= _profiles.length) {
        _selectedProfileIndex = _profiles.length - 1;
      }
      if (_selectedProfileIndex < 0) {
        _selectedProfileIndex = 0;
      }
    });
  }

  Future<void> _saveVoiceProfiles(List<VoiceProfile> profiles) async {
    await _voiceProfileStore.save(profiles);
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      if (_selectedProfileIndex >= _profiles.length) {
        _selectedProfileIndex = _profiles.length - 1;
      }
      if (_selectedProfileIndex < 0) {
        _selectedProfileIndex = 0;
      }
    });
  }

  Future<void> _upsertVoiceProfile(VoiceProfile profile) async {
    final profiles = List<VoiceProfile>.of(_profiles);
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
      await _saveVoiceProfiles(profiles);
      if (index == _selectedProfileIndex) {
        await _ensurePostProcessingForProfile(profile);
      }
      return;
    }
    profiles.add(profile);
    await _saveVoiceProfiles(profiles);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedProfileIndex = profiles.length - 1;
    });
    await _ensurePostProcessingForProfile(profile);
  }

  Future<void> _deleteVoiceProfile(VoiceProfile profile) async {
    if (_profiles.length <= 1) {
      return;
    }
    final profiles = _profiles.where((item) => item.id != profile.id).toList();
    await _saveVoiceProfiles(profiles);
  }

  Future<void> _showVoiceProfileEditor({VoiceProfile? profile}) async {
    final nameController = TextEditingController(text: profile?.name ?? '');
    final intentController = TextEditingController(
      text:
          profile?.intent ??
          'Clean up the transcript. Return only the final text.',
    );
    var commitSuffix = profile?.commitSuffix ?? CommitSuffix.space;
    var autoCommit = profile?.autoCommit ?? true;
    try {
      final edited = await showDialog<VoiceProfile>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(profile == null ? 'New profile' : 'Edit profile'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Profile name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: intentController,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Post-processing prompt',
                            helperText:
                                'Example: Translate Chinese speech into natural English.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SegmentedButton<CommitSuffix>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment<CommitSuffix>(
                                value: CommitSuffix.none,
                                label: Text('None'),
                              ),
                              ButtonSegment<CommitSuffix>(
                                value: CommitSuffix.space,
                                label: Text('Space'),
                              ),
                              ButtonSegment<CommitSuffix>(
                                value: CommitSuffix.newline,
                                label: Text('New line'),
                              ),
                            ],
                            selected: {commitSuffix},
                            onSelectionChanged: (selection) {
                              setDialogState(() {
                                commitSuffix = selection.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: autoCommit,
                          onChanged: (value) {
                            setDialogState(() {
                              autoCommit = value;
                            });
                          },
                          title: const Text('Auto commit'),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final intent = intentController.text.trim();
                      Navigator.of(context).pop(
                        VoiceProfile(
                          id:
                              profile?.id ??
                              'profile_${DateTime.now().microsecondsSinceEpoch}',
                          name: name.isEmpty ? 'Untitled' : name,
                          intent: intent.isEmpty
                              ? 'Clean up the transcript. Return only the final text.'
                              : intent,
                          commitSuffix: commitSuffix,
                          autoCommit: autoCommit,
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (edited != null) {
        await _upsertVoiceProfile(edited);
      }
    } finally {
      nameController.dispose();
      intentController.dispose();
    }
  }

  Future<void> _confirmDeleteVoiceProfile(VoiceProfile profile) async {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one profile')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete profile'),
          content: Text('Delete "${profile.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _deleteVoiceProfile(profile);
    }
  }

  Future<void> _loadProviderSettings() async {
    try {
      final settings = await _providerSettingsStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _providerSettings = settings;
        _providerSettingsLoading = false;
        _cloudProcessingEnabled = settings.activeProviderConfigured;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _providerSettingsLoading = false;
      });
    }
  }

  Future<void> _saveProviderSettings(ProviderSettings settings) async {
    setState(() {
      _providerSettingsSaving = true;
    });
    try {
      await _providerSettingsStore.save(settings);
      if (!mounted) {
        return;
      }
      setState(() {
        _providerSettings = settings;
        _providerSettingsSaving = false;
        _cloudProcessingEnabled = settings.activeProviderConfigured;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _providerSettingsSaving = false;
      });
      rethrow;
    }
  }

  Future<void> _runSonioxSmokeTest() async {
    setState(() {
      _captureState = CaptureState.processing;
      _smokeTestStatus = const SmokeTestStatus(
        label: 'Real Soniox smoke test',
        detail: 'Streaming public WAV audio to Soniox from the iOS simulator.',
      );
    });

    try {
      final result = await SonioxSmokeTestRunner(
        apiKey: SmokeTestConfig.sonioxApiKey,
        audioUrl: SmokeTestConfig.audioUrl,
        audioFormat: SmokeTestConfig.audioFormat,
      ).run();

      if (!mounted) {
        return;
      }

      final draft = DraftEntry(
        text: result.transcript,
        profileName: 'Soniox',
        createdAt: DateTime.now(),
      );
      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Soniox smoke test passed',
          detail: result.partial
              ? 'Received realtime tokens after sending ${result.bytesSent} bytes.'
              : 'Sent ${result.bytesSent} bytes and received a finished result.',
          transcript: result.transcript,
          finished: true,
        );
        _drafts.insert(0, draft);
      });
      await _publishTextWithFeedback(
        draft.text,
        message: 'Smoke test transcript copied to clipboard.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Soniox smoke test failed',
          detail: error.toString(),
          failed: true,
          finished: true,
        );
      });
    }
  }

  Future<void> _runBailianSmokeTest() async {
    setState(() {
      _captureState = CaptureState.processing;
      _smokeTestStatus = const SmokeTestStatus(
        label: 'Real Bailian smoke test',
        detail:
            'Calling Bailian text, ASR, and realtime APIs from the iOS simulator.',
      );
    });

    try {
      final result = await BailianSmokeTestRunner(
        apiBase: SmokeTestConfig.bailianApiBase,
        apiKey: SmokeTestConfig.bailianApiKey,
        textModel: SmokeTestConfig.bailianOpenAiModel,
        asrModel: SmokeTestConfig.bailianAsrModel,
        asrAudioUrl: SmokeTestConfig.bailianAsrAudioUrl,
        realtimeUrl: SmokeTestConfig.bailianRealtimeUrl,
        realtimeModel: SmokeTestConfig.bailianRealtimeModel,
        realtimeAudioUrl: SmokeTestConfig.audioUrl,
      ).run();
      debugPrint(
        'SHINSOKU_BAILIAN_E2E_PASS ${result.steps.map((step) => '${step.name}: ${step.detail}').join(' | ')}',
      );

      if (!mounted) {
        return;
      }

      final draft = result.transcript.isNotEmpty
          ? DraftEntry(
              text: result.transcript,
              profileName: 'Bailian',
              createdAt: DateTime.now(),
            )
          : null;
      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Bailian smoke test passed',
          detail: result.steps
              .map((step) => '${step.name}: ${step.detail}')
              .join('\n'),
          transcript: result.transcript,
          finished: true,
        );
        if (draft != null) {
          _drafts.insert(0, draft);
        }
      });
      if (draft != null) {
        await _publishTextWithFeedback(
          draft.text,
          message: 'Smoke test transcript copied to clipboard.',
        );
      }
    } catch (error) {
      debugPrint('SHINSOKU_BAILIAN_E2E_FAIL $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Bailian smoke test failed',
          detail: error.toString(),
          failed: true,
          finished: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.mic_none),
        selectedIcon: Icon(Icons.mic),
        label: 'Record',
      ),
      NavigationDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description),
        label: 'Drafts',
      ),
      NavigationDestination(
        icon: Icon(Icons.wifi_tethering),
        selectedIcon: Icon(Icons.podcasts),
        label: 'Desktop',
      ),
      NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final body = IndexedStack(
          index: _tabIndex,
          children: [
            RecordView(
              profiles: _profiles,
              selectedProfileIndex: _selectedProfileIndex,
              captureState: _captureState,
              microphoneAllowed: _microphoneAllowed,
              smokeTestStatus: _smokeTestStatus,
              onProfileSelected: (index) {
                unawaited(_selectProfile(index));
              },
              onProfileAdded: () => _showVoiceProfileEditor(),
              onProfileEdited: (profile) =>
                  _showVoiceProfileEditor(profile: profile),
              onProfileDeleted: _confirmDeleteVoiceProfile,
              onCapturePressed: _toggleCapture,
            ),
            DraftsView(
              drafts: _drafts,
              onDelete: _deleteDraft,
              onEdit: _showDraftEditor,
              onCopy: (draft) => _publishTextWithFeedback(
                draft.text,
                message: 'Draft copied to clipboard.',
              ),
            ),
            NearbyMicrophoneView(
              profiles: [
                for (final profile in _profiles)
                  NearbyProfileOption(
                    id: switch (profile.id) {
                      'dictation' => 'default',
                      'zh_to_en' => 'zh-to-en',
                      _ => profile.id,
                    },
                    label: profile.name,
                  ),
              ],
            ),
            SettingsView(
              microphoneAllowed: _microphoneAllowed,
              keyboardExtensionEnabled: _keyboardExtensionEnabled,
              cloudProcessingEnabled: _cloudProcessingEnabled,
              providerSettings: _providerSettings,
              providerSettingsLoading: _providerSettingsLoading,
              providerSettingsSaving: _providerSettingsSaving,
              onMicrophonePressed: _handleMicrophoneSettingsPressed,
              onKeyboardChanged: (value) {
                setState(() {
                  _keyboardExtensionEnabled = value;
                });
              },
              onCloudProcessingChanged: (value) {
                setState(() {
                  _cloudProcessingEnabled = value;
                });
              },
              onProviderSettingsSaved: _saveProviderSettings,
            ),
          ],
        );

        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _tabIndex,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 18),
                      child: ShinsokuMark(),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.mic_none),
                        selectedIcon: Icon(Icons.mic),
                        label: Text('Record'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description),
                        label: Text('Drafts'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.wifi_tethering),
                        selectedIcon: Icon(Icons.podcasts),
                        label: Text('Desktop'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_outlined),
                        selectedIcon: Icon(Icons.tune),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(child: body),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: _selectTab,
            destinations: destinations,
          ),
        );
      },
    );
  }
}

class RecordView extends StatelessWidget {
  const RecordView({
    required this.profiles,
    required this.selectedProfileIndex,
    required this.captureState,
    required this.microphoneAllowed,
    required this.smokeTestStatus,
    required this.onProfileSelected,
    required this.onProfileAdded,
    required this.onProfileEdited,
    required this.onProfileDeleted,
    required this.onCapturePressed,
    super.key,
  });

  final List<VoiceProfile> profiles;
  final int selectedProfileIndex;
  final CaptureState captureState;
  final bool microphoneAllowed;
  final SmokeTestStatus? smokeTestStatus;
  final ValueChanged<int> onProfileSelected;
  final VoidCallback onProfileAdded;
  final ValueChanged<VoiceProfile> onProfileEdited;
  final ValueChanged<VoiceProfile> onProfileDeleted;
  final VoidCallback onCapturePressed;

  @override
  Widget build(BuildContext context) {
    final profile = profiles[selectedProfileIndex];
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppHeader(title: 'Shinsoku', subtitle: 'Mobile voice input'),
        const SizedBox(height: 20),
        if (smokeTestStatus != null) ...[
          SmokeTestPanel(status: smokeTestStatus!),
          const SizedBox(height: 18),
        ],
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.graphic_eq, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusTitle(captureState),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _statusCopy(captureState, microphoneAllowed),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: captureState == CaptureState.processing
                      ? null
                      : onCapturePressed,
                  icon: Icon(_captureIcon(captureState, microphoneAllowed)),
                  label: Text(_captureLabel(captureState, microphoneAllowed)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Profile',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Add profile',
              onPressed: onProfileAdded,
              icon: const Icon(Icons.add_circle_outline),
            ),
            IconButton(
              tooltip: 'Edit selected profile',
              onPressed: () => onProfileEdited(profile),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete selected profile',
              onPressed: profiles.length <= 1
                  ? null
                  : () => onProfileDeleted(profile),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < profiles.length; index += 1) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_profileIcon(profiles[index]), size: 18),
                        const SizedBox(width: 8),
                        Flexible(child: Text(profiles[index].name)),
                      ],
                    ),
                    selected: selectedProfileIndex == index,
                    showCheckmark: false,
                    onSelected: (_) => onProfileSelected(index),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                profile.intent,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                    icon: profile.autoCommit
                        ? Icons.flash_on_outlined
                        : Icons.rate_review_outlined,
                    label: profile.autoCommit ? 'Auto commit' : 'Review first',
                  ),
                  StatusChip(
                    icon: Icons.keyboard_return,
                    label: _suffixLabel(profile.commitSuffix),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusTitle(CaptureState state) {
    return switch (state) {
      CaptureState.idle => 'Ready to record',
      CaptureState.listening => 'Listening',
      CaptureState.processing => 'Processing transcript',
    };
  }

  String _statusCopy(CaptureState state, bool microphoneAllowed) {
    if (!microphoneAllowed) {
      return 'Microphone access is disabled. Enable it in Settings before recording.';
    }

    return switch (state) {
      CaptureState.idle => 'Choose a profile, then capture a note or message.',
      CaptureState.listening => 'Tap stop when you are done speaking.',
      CaptureState.processing => 'Preparing a draft with the selected profile.',
    };
  }

  IconData _captureIcon(CaptureState state, bool microphoneAllowed) {
    if (!microphoneAllowed) {
      return Icons.mic_off_outlined;
    }

    return switch (state) {
      CaptureState.idle => Icons.mic,
      CaptureState.listening => Icons.stop,
      CaptureState.processing => Icons.hourglass_top,
    };
  }

  String _captureLabel(CaptureState state, bool microphoneAllowed) {
    if (!microphoneAllowed) {
      return 'Open Settings';
    }

    return switch (state) {
      CaptureState.idle => 'Start Recording',
      CaptureState.listening => 'Stop and Draft',
      CaptureState.processing => 'Processing',
    };
  }

  IconData _profileIcon(VoiceProfile profile) {
    return switch (profile.name) {
      'Chat' => Icons.chat_bubble_outline,
      'Review' => Icons.fact_check_outlined,
      _ => Icons.notes,
    };
  }

  String _suffixLabel(CommitSuffix suffix) {
    return switch (suffix) {
      CommitSuffix.none => 'No suffix',
      CommitSuffix.space => 'Trailing space',
      CommitSuffix.newline => 'New line',
    };
  }
}

class DraftsView extends StatelessWidget {
  const DraftsView({
    required this.drafts,
    required this.onDelete,
    required this.onEdit,
    required this.onCopy,
    super.key,
  });

  final List<DraftEntry> drafts;
  final ValueChanged<DraftEntry> onDelete;
  final ValueChanged<DraftEntry> onEdit;
  final ValueChanged<DraftEntry> onCopy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppHeader(title: 'Drafts', subtitle: 'Captured mobile text'),
        const SizedBox(height: 20),
        if (drafts.isEmpty)
          const InfoPanel(child: EmptyState())
        else
          for (final draft in drafts) ...[
            DraftCard(
              draft: draft,
              onDelete: () => onDelete(draft),
              onEdit: () => onEdit(draft),
              onCopy: () => onCopy(draft),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _DraftEditResult {
  const _DraftEditResult({required this.text, required this.copyToClipboard});

  final String text;
  final bool copyToClipboard;
}

class DraftEditorScreen extends StatefulWidget {
  const DraftEditorScreen({required this.draft, super.key});

  final DraftEntry draft;

  @override
  State<DraftEditorScreen> createState() => _DraftEditorScreenState();
}

class _DraftEditorScreenState extends State<DraftEditorScreen> {
  late final TextEditingController _controller;
  bool _hasText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft.text);
    _hasText = widget.draft.text.trim().isNotEmpty;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText == _hasText) {
      return;
    }
    setState(() {
      _hasText = hasText;
    });
  }

  void _complete({required bool copyToClipboard}) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    Navigator.of(
      context,
    ).pop(_DraftEditResult(text: text, copyToClipboard: copyToClipboard));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text('Edit draft'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Captured with ${widget.draft.profileName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('draft-editor-field'),
                  controller: _controller,
                  autofocus: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    labelText: 'Transcript',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const ValueKey('draft-save-button'),
                        onPressed: _hasText
                            ? () => _complete(copyToClipboard: false)
                            : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('draft-save-copy-button'),
                        onPressed: _hasText
                            ? () => _complete(copyToClipboard: true)
                            : null,
                        icon: const Icon(Icons.content_copy_outlined),
                        label: const Text('Save & Copy'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.microphoneAllowed,
    required this.keyboardExtensionEnabled,
    required this.cloudProcessingEnabled,
    required this.providerSettings,
    required this.providerSettingsLoading,
    required this.providerSettingsSaving,
    required this.onMicrophonePressed,
    required this.onKeyboardChanged,
    required this.onCloudProcessingChanged,
    required this.onProviderSettingsSaved,
    super.key,
  });

  final bool microphoneAllowed;
  final bool keyboardExtensionEnabled;
  final bool cloudProcessingEnabled;
  final ProviderSettings providerSettings;
  final bool providerSettingsLoading;
  final bool providerSettingsSaving;
  final VoidCallback onMicrophonePressed;
  final ValueChanged<bool> onKeyboardChanged;
  final ValueChanged<bool> onCloudProcessingChanged;
  final Future<void> Function(ProviderSettings settings)
  onProviderSettingsSaved;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late String _speechProvider;
  late String _bailianAsrMode;
  late bool _textTransformEnabled;
  bool _showBailianKey = false;
  bool _showSonioxKey = false;

  late final TextEditingController _bailianBaseController;
  late final TextEditingController _bailianKeyController;
  late final TextEditingController _bailianTextModelController;
  late final TextEditingController _bailianAsrModelController;
  late final TextEditingController bailianRealtimeUrlController;
  late final TextEditingController bailianRealtimeModelController;
  late final TextEditingController _sonioxKeyController;
  late final TextEditingController _sonioxModelController;

  @override
  void initState() {
    super.initState();
    _bailianBaseController = TextEditingController();
    _bailianKeyController = TextEditingController();
    _bailianTextModelController = TextEditingController();
    _bailianTextModelController.addListener(_refreshPostProcessingModelLabel);
    _bailianAsrModelController = TextEditingController();
    bailianRealtimeUrlController = TextEditingController();
    bailianRealtimeModelController = TextEditingController();
    _sonioxKeyController = TextEditingController();
    _sonioxModelController = TextEditingController();
    _applySettings(widget.providerSettings);
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerSettings != widget.providerSettings) {
      _applySettings(widget.providerSettings);
    }
  }

  @override
  void dispose() {
    _bailianTextModelController.removeListener(
      _refreshPostProcessingModelLabel,
    );
    _bailianBaseController.dispose();
    _bailianKeyController.dispose();
    _bailianTextModelController.dispose();
    _bailianAsrModelController.dispose();
    bailianRealtimeUrlController.dispose();
    bailianRealtimeModelController.dispose();
    _sonioxKeyController.dispose();
    _sonioxModelController.dispose();
    super.dispose();
  }

  void _refreshPostProcessingModelLabel() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applySettings(ProviderSettings settings) {
    _speechProvider = settings.speechProvider;
    _bailianAsrMode =
        {
          bailianAsrModeRealtime,
          bailianAsrModeQwen,
        }.contains(settings.bailianAsrMode)
        ? settings.bailianAsrMode
        : bailianAsrModeRealtime;
    _textTransformEnabled = settings.textTransformEnabled;
    _bailianBaseController.text = settings.bailianApiBase;
    _bailianKeyController.text = settings.bailianApiKey;
    _bailianTextModelController.text = settings.bailianTextModel;
    _bailianAsrModelController.text = settings.bailianAsrModel;
    bailianRealtimeUrlController.text = settings.bailianRealtimeUrl;
    bailianRealtimeModelController.text = settings.bailianRealtimeModel;
    _sonioxKeyController.text = settings.sonioxApiKey;
    _sonioxModelController.text = settings.sonioxModel;
  }

  Future<void> _save() async {
    final settings = ProviderSettings(
      speechProvider: _speechProvider,
      textTransformEnabled: _textTransformEnabled,
      bailianAsrMode: _bailianAsrMode,
      bailianApiBase: _bailianBaseController.text.trim(),
      bailianApiKey: _bailianKeyController.text.trim(),
      bailianTextModel: _bailianTextModelController.text.trim(),
      bailianAsrModel: _bailianAsrModelController.text.trim(),
      bailianRealtimeUrl: bailianRealtimeUrlController.text.trim(),
      bailianRealtimeModel: bailianRealtimeModelController.text.trim(),
      sonioxApiKey: _sonioxKeyController.text.trim(),
      sonioxModel: _sonioxModelController.text.trim(),
    );

    try {
      await widget.onProviderSettingsSaved(settings);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Provider settings saved')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final providerConfigured = switch (_speechProvider) {
      'soniox' => _sonioxKeyController.text.trim().isNotEmpty,
      _ => _bailianKeyController.text.trim().isNotEmpty,
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppHeader(title: 'Settings', subtitle: 'Providers and workflow'),
        const SizedBox(height: 20),
        InfoPanel(
          child: Column(
            children: [
              SwitchListTile(
                value: widget.microphoneAllowed,
                onChanged: (_) => widget.onMicrophonePressed(),
                secondary: const Icon(Icons.mic_none),
                title: const Text('Microphone access'),
                subtitle: Text(
                  widget.microphoneAllowed
                      ? 'Allowed for voice capture'
                      : 'Tap to request iOS microphone access',
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.keyboard_alt_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: openAppSettings,
                title: const Text('Keyboard setup'),
                subtitle: const Text(
                  'Add Shinsoku in iOS Keyboard settings and allow Full Access',
                ),
              ),
              const Divider(),
              SwitchListTile(
                value: widget.cloudProcessingEnabled,
                onChanged: widget.onCloudProcessingChanged,
                secondary: const Icon(Icons.cloud_outlined),
                title: const Text('Cloud processing'),
                subtitle: Text(
                  providerConfigured
                      ? 'Provider credentials are saved'
                      : 'Save provider credentials before real transcription',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.keyboard_command_key, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enable Shinsoku Keyboard',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '1. Open iOS Settings > General > Keyboard > Keyboards.\n'
                '2. Add Shinsoku as a third-party keyboard.\n'
                '3. Turn on Allow Full Access so Paste can read the latest Shinsoku text.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open iOS Settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Speech Provider', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.providerSettingsLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'bailian',
                    label: Text('Bailian'),
                    icon: Icon(Icons.cloud_queue),
                  ),
                  ButtonSegment<String>(
                    value: 'soniox',
                    label: Text('Soniox'),
                    icon: Icon(Icons.graphic_eq),
                  ),
                ],
                selected: {_speechProvider},
                onSelectionChanged: (selection) {
                  setState(() {
                    _speechProvider = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _textTransformEnabled,
                onChanged: (value) {
                  setState(() {
                    _textTransformEnabled = value;
                  });
                },
                secondary: const Icon(Icons.translate),
                title: const Text('Text post-processing'),
                subtitle: Text(
                  'Use ${_bailianTextModelController.text.trim().isEmpty ? "qwen-flash" : _bailianTextModelController.text.trim()} for cleanup or translation',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SaveSettingsButton(
          saving: widget.providerSettingsSaving,
          onPressed: _save,
        ),
        const SizedBox(height: 18),
        Text('Bailian', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            children: [
              ConfigTextField(
                controller: _bailianBaseController,
                icon: Icons.link,
                label: 'OpenAI-compatible base URL',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianKeyController,
                icon: Icons.key,
                label: 'API key',
                obscureText: !_showBailianKey,
                trailing: IconButton(
                  tooltip: _showBailianKey ? 'Hide key' : 'Show key',
                  onPressed: () {
                    setState(() {
                      _showBailianKey = !_showBailianKey;
                    });
                  },
                  icon: Icon(
                    _showBailianKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianTextModelController,
                icon: Icons.auto_fix_high_outlined,
                label: 'Post-processing OpenAI model',
                helperText: 'Used only when Text post-processing is enabled',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: bailianAsrModeRealtime,
                      label: Text('Streaming'),
                      icon: Icon(Icons.podcasts),
                    ),
                    ButtonSegment<String>(
                      value: bailianAsrModeQwen,
                      label: Text('Qwen-ASR'),
                      icon: Icon(Icons.hearing),
                    ),
                  ],
                  selected: {_bailianAsrMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _bailianAsrMode = selection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianAsrModelController,
                icon: Icons.hearing,
                label: 'Qwen-ASR batch model',
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: bailianRealtimeUrlController,
                icon: Icons.hub_outlined,
                label: 'Realtime WebSocket URL',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: bailianRealtimeModelController,
                icon: Icons.multitrack_audio,
                label: 'Streaming ASR model',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Soniox', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            children: [
              ConfigTextField(
                controller: _sonioxKeyController,
                icon: Icons.key,
                label: 'API key',
                obscureText: !_showSonioxKey,
                trailing: IconButton(
                  tooltip: _showSonioxKey ? 'Hide key' : 'Show key',
                  onPressed: () {
                    setState(() {
                      _showSonioxKey = !_showSonioxKey;
                    });
                  },
                  icon: Icon(
                    _showSonioxKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _sonioxModelController,
                icon: Icons.multitrack_audio,
                label: 'Realtime model',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SaveSettingsButton(
          saving: widget.providerSettingsSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _SaveSettingsButton extends StatelessWidget {
  const _SaveSettingsButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(saving ? 'Saving' : 'Save Settings'),
      ),
    );
  }
}

class ConfigTextField extends StatelessWidget {
  const ConfigTextField({
    required this.controller,
    required this.icon,
    required this.label,
    this.helperText,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
    super.key,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String? helperText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixIcon: trailing,
        labelText: label,
        helperText: helperText,
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ShinsokuMark(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class ShinsokuMark extends StatelessWidget {
  const ShinsokuMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/app-icon.png',
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surface,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class SmokeTestPanel extends StatelessWidget {
  const SmokeTestPanel({required this.status, super.key});

  final SmokeTestStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = status.failed
        ? Icons.error_outline
        : status.finished
        ? Icons.check_circle_outline
        : Icons.cloud_sync_outlined;
    final color = status.failed ? scheme.error : scheme.primary;

    return InfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(status.detail),
          if (status.transcript != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              status.transcript!,
              key: const ValueKey('soniox-smoke-transcript'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}

class DraftCard extends StatelessWidget {
  const DraftCard({
    required this.draft,
    required this.onDelete,
    required this.onEdit,
    required this.onCopy,
    super.key,
  });

  final DraftEntry draft;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: StatusChip(
                    icon: Icons.person_search_outlined,
                    label: draft.profileName,
                  ),
                ),
                const Spacer(),
                Text(
                  _relativeTime(draft.createdAt),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(draft.text, style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit draft',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Copy draft',
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_outlined),
                ),
                IconButton(
                  tooltip: 'Delete draft',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} hr ago';
    }
    return '${diff.inDays} days ago';
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.inbox_outlined, size: 44),
        SizedBox(height: 12),
        Text('No drafts yet'),
      ],
    );
  }
}
