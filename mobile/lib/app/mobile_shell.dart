import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/app/bridges.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/profile_editor_sheet.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// Stands in for the recorder and provider pipeline in widget tests, so
/// capture state can be driven without plugins or network.
@visibleForTesting
abstract interface class DebugCapture {
  Future<void> start();

  /// Returns the transcript.
  Future<String> stop();
}

/// Owns everything that must survive a layout switch (DESIGN §6, invariant
/// D1): capture state, the recorder, the current transcript and status,
/// drafts and the selected pages. [ShellScaffold] below only arranges pages.
class MobileShell extends StatefulWidget {
  const MobileShell({
    this.initialDrafts = const [],
    this.initialTabIndex = 0,
    this.debugCapture,
    super.key,
  });

  final List<DraftEntry> initialDrafts;
  final int initialTabIndex;

  @visibleForTesting
  final DebugCapture? debugCapture;

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

  /// The page in the second pane on regular widths (1–3); follows the last
  /// non-Record page picked anywhere.
  int _secondaryTab = 1;
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
    if (_tabIndex > 0) _secondaryTab = _tabIndex;

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
      if (index > 0) _secondaryTab = index;
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
    final debug = widget.debugCapture;
    if (debug != null) {
      await _toggleDebugCapture(debug);
      return;
    }
    if (_captureState == CaptureState.idle) {
      await _startRecording();
      return;
    }

    await _stopRecordingAndTranscribe();
  }

  Future<void> _toggleDebugCapture(DebugCapture debug) async {
    switch (_captureState) {
      case CaptureState.idle:
        await debug.start();
        if (!mounted) return;
        setState(() {
          _captureState = CaptureState.listening;
          _smokeTestStatus = null;
        });
      case CaptureState.listening:
        setState(() => _captureState = CaptureState.processing);
        final text = await debug.stop();
        if (!mounted) return;
        setState(() {
          _captureState = CaptureState.idle;
          _smokeTestStatus = SmokeTestStatus(
            label: 'Recording transcribed',
            detail: '',
            transcript: text,
            finished: true,
          );
        });
      case CaptureState.processing:
        return;
    }
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
        _smokeTestStatus = const SmokeTestStatus(
          label: 'Microphone access is off',
          detail:
              'Allow microphone access in iOS Settings, then try recording again.',
          failed: true,
          finished: true,
          fix: StatusFix.microphone,
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
        _smokeTestStatus = const SmokeTestStatus(
          label: 'Provider settings required',
          detail: 'Save a Bailian or Soniox API key before recording.',
          failed: true,
          finished: true,
          fix: StatusFix.providerSettings,
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
    final index = _drafts.indexOf(draft);
    if (index < 0) {
      return;
    }
    setState(() {
      _drafts.removeAt(index);
    });
    // DESIGN §7: swipe to delete with undo.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Draft deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted || _drafts.contains(draft)) {
                return;
              }
              setState(() {
                _drafts.insert(index.clamp(0, _drafts.length), draft);
              });
            },
          ),
        ),
      );
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
    final result = await showProfileEditor(
      context,
      profile: profile,
      canDelete: profile != null && _profiles.length > 1,
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.delete) {
      await _confirmDeleteVoiceProfile(profile!);
      return;
    }
    await _upsertVoiceProfile(result.profile!);
  }

  Future<void> _confirmDeleteVoiceProfile(VoiceProfile profile) async {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one profile')),
      );
      return;
    }
    final confirmed = await showSkConfirm(
      context: context,
      title: 'Delete profile',
      message: 'Delete "${profile.name}"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed) {
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
      final saved = await _providerSettingsStore.load();
      final result = await SonioxSmokeTestRunner(
        apiKey: saved.sonioxApiKey,
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
      final saved = await _providerSettingsStore.load();
      final result = await BailianSmokeTestRunner(
        apiBase: SmokeTestConfig.bailianApiBase,
        apiKey: saved.bailianApiKey,
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
    final pages = <Widget>[
      RecordView(
        profiles: _profiles,
        selectedProfileIndex: _selectedProfileIndex,
        captureState: _captureState,
        microphoneAllowed: _microphoneAllowed,
        smokeTestStatus: _smokeTestStatus,
        onProfileSelected: (index) {
          unawaited(_selectProfile(index));
        },
        onCapturePressed: _toggleCapture,
        onOpenMicrophoneSettings: _handleMicrophoneSettingsPressed,
        onOpenSettings: () => _selectTab(3),
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
        profiles: _profiles,
        onProfileAdded: () => _showVoiceProfileEditor(),
        onProfileOpened: (profile) => _showVoiceProfileEditor(profile: profile),
      ),
    ];

    return ShellScaffold(
      tabIndex: _tabIndex,
      secondaryIndex: _secondaryTab,
      onTabSelected: _selectTab,
      // Invariant D2: folding mid-capture lands on Record, with Stop.
      holdRecord: _captureState != CaptureState.idle,
      pages: pages,
    );
  }
}
