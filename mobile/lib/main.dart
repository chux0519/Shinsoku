import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/features/common/widgets.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
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
    final result = await Navigator.of(context).push<DraftEditResult>(
      MaterialPageRoute<DraftEditResult>(
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
