import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/app/bridges.dart';
import 'package:shinsoku_mobile/app/live_fixture_pipeline.dart';
import 'package:shinsoku_mobile/app/recording_pipeline.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/features/drafts/draft_editor_page.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/field_rules_view.dart';
import 'package:shinsoku_mobile/l10n/failure_text.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/features/settings/profile_editor_sheet.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/features/settings/use_in_apps_view.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/field_rules.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/services/profile_reason.dart';
import 'package:shinsoku_mobile/services/shortcuts.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

export 'package:shinsoku_mobile/app/recording_pipeline.dart'
    show DebugCapture, RecordingPipeline;

/// Owns everything that must survive a layout switch (DESIGN §6, invariant
/// D1): capture state, the recorder, the current transcript and status,
/// drafts and the selected pages. [ShellScaffold] below only arranges pages.
class MobileShell extends StatefulWidget {
  const MobileShell({
    this.initialDrafts = const [],
    this.initialTabIndex = 0,
    this.debugCapture,
    this.pipelineFactory,
    super.key,
  });

  final List<DraftEntry> initialDrafts;
  final int initialTabIndex;

  @visibleForTesting
  final DebugCapture? debugCapture;

  /// Makes each recording's pipeline instead of the microphone + provider
  /// (model tests drive live words through it).
  @visibleForTesting
  final RecordingPipeline Function()? pipelineFactory;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> with WidgetsBindingObserver {
  final ProviderSettingsStore _providerSettingsStore = ProviderSettingsStore();
  final VoiceProfileStore _voiceProfileStore = VoiceProfileStore();
  final ActiveProfileStore _activeProfileStore = ActiveProfileStore();
  final FieldRulesStore _fieldRulesStore = FieldRulesStore();
  FieldRules _fieldRules = const FieldRules();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<VoiceProfile> _profiles = List<VoiceProfile>.of(defaultVoiceProfiles);
  late final List<DraftEntry> _drafts;

  /// The draft the Record screen's text belongs to (L3).
  DraftEntry? _recordDraft;

  late int _tabIndex;

  /// The page in the second pane on regular widths (1–3); follows the last
  /// non-Record page picked anywhere.
  int _secondaryTab = 1;

  /// The profile resolved when the current recording started (PR1); used
  /// for the transcript even if the selection changes mid-recording.
  VoiceProfile? _recordingProfile;
  CaptureState _captureState = CaptureState.idle;
  bool _microphoneAllowed = false;
  bool _keyboardExtensionEnabled = false;
  bool _cloudProcessingEnabled = false;
  bool _providerSettingsLoading = true;
  bool _providerSettingsSaving = false;
  ProviderSettings _providerSettings = ProviderSettings.defaults();
  SmokeTestStatus? _smokeTestStatus;

  /// The current (or last) recording; one per recording.
  RecordingPipeline? _pipeline;

  /// Completes when [_pipeline] has started (or failed to).
  Future<void>? _pipelineStarted;

  /// What the Record area shows: the pipeline's live text, then the result
  /// or the words kept from a failed recording.
  final _live = ValueNotifier<LiveTranscript>(LiveTranscript.idle);

  final _recordKey = GlobalKey<RecordViewState>();

  /// Bumped when Drafts edits the Record screen's draft, so the area shows
  /// the new text (one source: the draft).
  RecordExternalEdit? _recordExternalEdit;

  /// DEBUG only: `-ShinsokuSceneLiveFixture <name>` replays this fixture
  /// instead of the microphone and provider.
  LiveFixture? _liveFixture;

  /// Active profile per the profile-01 precedence (the app has no field
  /// rule or keyboard session, so: stored selection, else default).
  VoiceProfile get _activeProfile =>
      resolveActive(_activeProfileStore.selection, _profiles).profile;

  /// Completes once the launch profile load (and field-rules sync) is done.
  Future<void> _profilesLoaded = Future<void>.value();

  /// The Settings sub-page a `shinsoku://settings/<page>` link pushed and that is still open.
  String? _linkedSettingsPage;

  int get _selectedProfileIndex {
    final id = _activeProfile.id;
    final index = _profiles.indexWhere((profile) => profile.id == id);
    return index < 0 ? 0 : index;
  }

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
    _profilesLoaded = _loadVoiceProfiles();
    unawaited(_refreshMicrophonePermission());
    if (kDebugMode) unawaited(_loadLiveFixture());
  }

  Future<void> _loadLiveFixture() async {
    final fixture = await LiveFixture.fromLaunchArgument();
    if (fixture == null || !mounted) return;
    debugPrint('SHINSOKU_LIVE_FIXTURE ${fixture.name}');
    setState(() => _liveFixture = fixture);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkBridge.channel.setMethodCallHandler(null);
    _pipeline?.live.removeListener(_onPipelineLive);
    unawaited(_pipeline?.dispose());
    _live.dispose();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshActiveProfile());
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
      // PR1: the keyboard passes the profile it showed.
      await _handleKeyboardRecordRequest(uri.queryParameters['profile']);
    } else if (uri.host == 'settings' && uri.pathSegments.length == 1) {
      await _openSettingsPage(uri.pathSegments.single);
    }
  }

  /// Sub-pages reachable by `shinsoku://settings/<page>`. Unknown pages are ignored.
  static const settingsLinkPages = {'field-rules', 'use-in-apps'};

  /// `shinsoku://settings/field-rules` and `shinsoku://settings/use-in-apps`: select the Settings tab and push
  /// the page, as tapping its row does. The host can deliver one link more than once (openURL, its retry,
  /// consumeInitialURL), so a link for the page already open is ignored.
  Future<void> _openSettingsPage(String page) async {
    if (!settingsLinkPages.contains(page) || _linkedSettingsPage == page) {
      return;
    }
    await _profilesLoaded;
    if (!mounted || _linkedSettingsPage == page) {
      return;
    }
    final navigator = Navigator.of(context);
    if (_linkedSettingsPage != null) {
      navigator.popUntil((route) => route.isFirst);
    }
    _selectTab(3);
    _linkedSettingsPage = page;
    // Not awaited: the host's openURL call returns now, not when the page closes.
    unawaited(
      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (context) => switch (page) {
                'field-rules' => FieldRulesView(
                  profiles: _profiles,
                  rules: _fieldRules,
                  onChanged: _saveFieldRules,
                ),
                _ => UseInAppsView.withSystemVersion(
                  onOpenShortcuts: openShortcutsApp,
                ),
              },
            ),
          )
          .whenComplete(() {
            if (_linkedSettingsPage == page) _linkedSettingsPage = null;
          }),
    );
  }

  Future<void> _handleKeyboardRecordRequest(String? profileId) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _tabIndex = 0;
    });

    if (_captureState != CaptureState.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shellAlreadyRecording)),
      );
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || _captureState != CaptureState.idle) {
      return;
    }
    await _startRecording(requestedProfileId: profileId);
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
    final pick = _activeProfileStore.selectManually(profile.id);
    setState(() {});
    await pick;
    await _ensurePostProcessingForProfile(profile);
  }

  /// The keyboard or an App Intent may have changed the selection.
  Future<void> _refreshActiveProfile() async {
    await _activeProfileStore.refresh();
    if (mounted) setState(() {});
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
          content: Text(context.l10n.shellPostProcessingEnabled(profile.name)),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.shellPostProcessingNotSaved(
              describeFailure(context.l10n, error),
            ),
          ),
        ),
      );
    }
  }

  /// Publishes [text] as the keyboard's latest (App Group) and the
  /// clipboard; [message] (if any) confirms it in a snack bar.
  Future<void> _publishTextWithFeedback(String text, {String? message}) async {
    try {
      await KeyboardBridge.publishText(text);
      if (!mounted || message == null) {
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
        SnackBar(
          content: Text(
            context.l10n.shellClipboardFailed(
              describeFailure(context.l10n, error),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleCapture() async {
    switch (_captureState) {
      case CaptureState.idle:
        await _startRecording();
      case CaptureState.listening:
        await _stopRecording();
      case CaptureState.processing:
        // The result is on its way; the button shows progress.
        return;
    }
  }

  /// A stand-in for the microphone and provider (widget tests, the DEBUG
  /// live fixture): no permission or key checks.
  bool get _simulatedCapture =>
      widget.debugCapture != null ||
      widget.pipelineFactory != null ||
      _liveFixture != null;

  RecordingPipeline _newPipeline() {
    final debug = widget.debugCapture;
    if (debug != null) return DebugCapturePipeline(debug);
    final factory = widget.pipelineFactory;
    if (factory != null) return factory();
    final fixture = _liveFixture;
    if (kDebugMode && fixture != null) return LiveFixturePipeline(fixture);
    return MicrophonePipeline(
      settings: _providerSettings,
      recorder: _audioRecorder,
    );
  }

  void _onPipelineLive() {
    final pipeline = _pipeline;
    if (pipeline == null) return;
    final value = pipeline.live.value;
    _live.value = value;
    // The provider dropped while the user is still talking: stop now, keep
    // what was heard (L2).
    if (value.phase == LivePhase.failed &&
        _captureState == CaptureState.listening) {
      unawaited(_stopRecording());
    }
  }

  Future<void> _releasePipeline() async {
    final old = _pipeline;
    _pipeline = null;
    old?.live.removeListener(_onPipelineLive);
    await old?.dispose();
  }

  Future<void> _startRecording({String? requestedProfileId}) async {
    if (_captureState != CaptureState.idle) return;
    // L3/L4: unsaved Record edits (IME composition committed) go into their
    // draft before the area is reused, however the recording was started.
    _recordKey.currentState?.keepEdits();
    // PR1: resolve once, at the tap: the profile the keyboard showed, else
    // the shared selection. (DebugCapture widget tests have no host.)
    if (widget.debugCapture == null) await _refreshActiveProfile();
    if (!mounted || _captureState != CaptureState.idle) return;
    final profile = profileForRecordStart(
      _activeProfileStore.selection,
      _profiles,
      requestedProfileId: requestedProfileId,
    );
    if (!_simulatedCapture && !await _microphoneAndProviderReady()) return;
    if (!mounted || _captureState != CaptureState.idle) return;

    await _releasePipeline();
    final pipeline = _newPipeline();
    _pipeline = pipeline;
    pipeline.live.addListener(_onPipelineLive);
    setState(() {
      _captureState = CaptureState.listening;
      _recordingProfile = profile;
      _smokeTestStatus = null;
    });
    final started = pipeline.start();
    _pipelineStarted = started.then((_) {}, onError: (_) {});
    try {
      await started;
    } catch (error) {
      if (!mounted || !identical(_pipeline, pipeline)) return;
      // Nothing was recorded yet; the area keeps nothing new.
      await _finishFailed(
        pipeline,
        error,
        label: context.l10n.recordFailed,
        profile: profile,
      );
      return;
    }
    if (mounted && !_simulatedCapture) {
      setState(() => _microphoneAllowed = true);
    }
  }

  Future<bool> _microphoneAndProviderReady() async {
    final permission = await Permission.microphone.request();
    final hasPermission = permission.isGranted || permission.isLimited;
    if (!hasPermission) {
      if (!mounted) return false;
      setState(() {
        _microphoneAllowed = false;
        _smokeTestStatus = SmokeTestStatus(
          label: context.l10n.recordMicOffLabel,
          detail: context.l10n.recordMicOffDetail,
          failed: true,
          finished: true,
          fix: StatusFix.microphone,
        );
      });
      return false;
    }

    final recorderReady = await _audioRecorder.hasPermission(request: false);
    if (!recorderReady) {
      if (!mounted) return false;
      setState(() {
        _microphoneAllowed = false;
        _smokeTestStatus = SmokeTestStatus(
          label: context.l10n.recordFailed,
          detail: context.l10n.recordRecorderNotReady,
          failed: true,
          finished: true,
        );
      });
      return false;
    }

    if (!_providerSettings.activeProviderConfigured) {
      if (!mounted) return false;
      setState(() {
        _microphoneAllowed = true;
        _smokeTestStatus = SmokeTestStatus(
          label: context.l10n.recordKeyRequiredLabel,
          detail: context.l10n.recordKeyRequiredDetail,
          failed: true,
          finished: true,
          fix: StatusFix.providerSettings,
        );
      });
      return false;
    }
    return true;
  }

  Future<void> _stopRecording() async {
    final pipeline = _pipeline;
    if (pipeline == null || _captureState != CaptureState.listening) return;
    final profile = _recordingProfile ?? _activeProfile;
    _recordingProfile = null;
    setState(() {
      _captureState = CaptureState.processing;
      _smokeTestStatus = SmokeTestStatus(
        label: context.l10n.recordStatusTranscribing,
        detail: context.l10n.recordTranscribingDetail,
      );
    });

    // Stop tapped while the provider is still connecting: let it finish.
    await _pipelineStarted;
    if (!mounted ||
        !identical(_pipeline, pipeline) ||
        _captureState != CaptureState.processing) {
      return;
    }
    final RealTranscriptionResult result;
    try {
      result = await pipeline.stop(profile);
    } catch (error) {
      if (!mounted || !identical(_pipeline, pipeline)) return;
      await _finishFailed(
        pipeline,
        error,
        label: context.l10n.recordStopped,
        profile: profile,
      );
      return;
    }
    if (!mounted || !identical(_pipeline, pipeline)) return;
    debugPrint('SHINSOKU_RECORDING_E2E ${result.detail}');
    // The draft holds the plain text; the profile's suffix is added when it
    // is published or copied (decision 2026-11-19).
    final draft = DraftEntry(
      text: result.text.trim(),
      profileName: result.provider,
      createdAt: DateTime.now(),
      commitSuffix: profile.commitSuffix,
    );
    pipeline.live.removeListener(_onPipelineLive);
    setState(() {
      _captureState = CaptureState.idle;
      _drafts.insert(0, draft);
      _recordDraft = draft;
      _live.value = pipeline.live.value.phase == LivePhase.done
          ? pipeline.live.value
          : LiveTranscript(committed: draft.text, phase: LivePhase.done);
      _smokeTestStatus = SmokeTestStatus(
        label: context.l10n.recordTranscribed,
        detail: result.detail,
        transcript: draft.text,
        finished: true,
      );
    });
    // Coordinator decision 2026-11-19: each new result is still published
    // to the keyboard and the clipboard. The status line says so; a snack
    // bar would cover Copy and Done.
    await _publishTextWithFeedback(draft.publishText);
  }

  /// A failed recording: whatever was heard (committed + pending) becomes
  /// this recording's draft, shown editable in the area; nothing is lost
  /// (L2/L3). The status line says why and offers to record again.
  Future<void> _finishFailed(
    RecordingPipeline pipeline,
    Object error, {
    required String label,
    required VoiceProfile profile,
  }) async {
    pipeline.live.removeListener(_onPipelineLive);
    final heard = pipeline.live.value.text.trim();
    final draft = heard.isEmpty
        ? null
        : DraftEntry(
            text: heard,
            profileName: profile.name,
            createdAt: DateTime.now(),
            commitSuffix: profile.commitSuffix,
          );
    setState(() {
      _captureState = CaptureState.idle;
      _tabIndex = 0;
      if (draft != null) {
        _drafts.insert(0, draft);
        _recordDraft = draft;
      }
      _live.value = LiveTranscript(
        committed: heard,
        phase: LivePhase.failed,
        error: error.toString(),
      );
      final reason = describeFailure(context.l10n, error);
      _smokeTestStatus = SmokeTestStatus(
        label: label,
        detail: draft == null
            ? reason
            : '${context.l10n.recordHeardTextKept} $reason',
        failed: true,
        finished: true,
        fix: StatusFix.retry,
      );
    });
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
          content: Text(context.l10n.draftsDeleted),
          action: SnackBarAction(
            label: context.l10n.commonUndo,
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

  /// Replaces [draft] in place (same slot, L3) and returns the new entry,
  /// or null when it is gone.
  DraftEntry? _replaceDraft(DraftEntry draft, String text) {
    final index = _drafts.indexOf(draft);
    if (index < 0) return null;
    final updated = draft.copyWith(text: text);
    setState(() {
      _drafts[index] = updated;
      if (identical(_recordDraft, draft)) _recordDraft = updated;
    });
    return updated;
  }

  /// Record › Done: the edit goes into this recording's draft (L3); text
  /// typed without a recording, or into a deleted draft, makes one.
  void _saveRecordText(String text) {
    final current = _recordDraft;
    if (current != null && _replaceDraft(current, text) != null) return;
    final draft = DraftEntry(
      text: text,
      profileName: _activeProfile.name,
      createdAt: DateTime.now(),
      commitSuffix: _activeProfile.commitSuffix,
    );
    setState(() {
      _drafts.insert(0, draft);
      _recordDraft = draft;
    });
  }

  /// The Record text as Insert and the clipboard get it: with the suffix of
  /// the profile its draft was recorded with.
  String _recordPublishText(String text) =>
      withCommitSuffix(text, _recordDraft?.commitSuffix ?? CommitSuffix.none);

  void _copyRecordText(String text) {
    _saveRecordText(text);
    unawaited(
      _publishTextWithFeedback(
        _recordPublishText(text),
        message: context.l10n.recordCopied,
      ),
    );
  }

  /// Record › Done after an edit: saved into the same draft and republished
  /// as the keyboard's latest and the clipboard (coordinator decision
  /// 2026-11-19); the status line says so.
  void _doneRecordText(String text) {
    _saveRecordText(text);
    setState(() {
      _smokeTestStatus = SmokeTestStatus(
        label: context.l10n.recordSavedInsert,
        detail: '',
        finished: true,
      );
    });
    unawaited(_publishTextWithFeedback(_recordPublishText(text)));
  }

  Future<void> _showDraftEditor(DraftEntry tapped) async {
    var draft = tapped;
    if (identical(draft, _recordDraft)) {
      // Unsaved Record edits first, so the editor opens on the newest text.
      _recordKey.currentState?.keepEdits();
      draft = _recordDraft ?? draft;
    }
    var current = draft;
    void save(String text) {
      final isRecordDraft = identical(current, _recordDraft);
      final updated = _replaceDraft(current, text);
      if (updated == null) return;
      current = updated;
      // One source: the Record area follows its draft (decision 2026-11-19).
      if (isRecordDraft) {
        setState(() {
          _recordExternalEdit = RecordExternalEdit(
            (_recordExternalEdit?.revision ?? 0) + 1,
            text,
          );
        });
      }
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DraftEditorPage(
          draft: draft,
          onSave: save,
          onCopy: (text) {
            save(text);
            unawaited(
              _publishTextWithFeedback(
                withCommitSuffix(text, current.commitSuffix),
                message: context.l10n.recordCopied,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadVoiceProfiles() async {
    final profiles = await _voiceProfileStore.load();
    // Migration + launch sync: publish ids/names, keep or create the shared
    // selection (idempotent).
    await _activeProfileStore.sync(profiles);
    final rules = await _fieldRulesStore.pruneTo(profiles.map((p) => p.id));
    await _fieldRulesStore.mirror(rules);
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _fieldRules = rules;
    });
  }

  Future<void> _saveFieldRules(FieldRules rules) async {
    await _fieldRulesStore.save(rules);
    if (mounted) setState(() => _fieldRules = rules);
  }

  Future<void> _saveVoiceProfiles(List<VoiceProfile> profiles) async {
    await _voiceProfileStore.save(profiles);
    // PR3: republish and repair a selection that points at a deleted id.
    await _activeProfileStore.sync(profiles);
    // Deleting a profile removes the field rules that point to it.
    final rules = await _fieldRulesStore.pruneTo(profiles.map((p) => p.id));
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _fieldRules = rules;
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
    await _activeProfileStore.selectManually(profile.id);
    if (!mounted) {
      return;
    }
    setState(() {});
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.profileKeepOne)));
      return;
    }
    final confirmed = await showSkConfirm(
      context: context,
      title: context.l10n.profileDelete,
      message: context.l10n.profileDeleteConfirm(profile.name),
      confirmLabel: context.l10n.commonDelete,
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

  // i18n-ignore-start: developer smoke tests (SHINSOKU_SMOKE_TEST), English only.
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
  // i18n-ignore-end

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      RecordView(
        key: _recordKey,
        transcript: _live,
        externalEdit: _recordExternalEdit,
        onDoneText: _doneRecordText,
        profiles: _profiles,
        selectedProfileIndex: _selectedProfileIndex,
        captureState: _captureState,
        microphoneAllowed: _microphoneAllowed,
        smokeTestStatus: _smokeTestStatus,
        onProfileSelected: (index) {
          unawaited(_selectProfile(index));
        },
        onCapturePressed: _toggleCapture,
        onSaveText: _saveRecordText,
        onCopyText: _copyRecordText,
        onOpenMicrophoneSettings: _handleMicrophoneSettingsPressed,
        onOpenSettings: () => _selectTab(3),
        profileReason: activeProfileReason(
          context.l10n,
          _activeProfile.name,
          resolveActive(_activeProfileStore.selection, _profiles).source,
        ),
      ),
      DraftsView(
        drafts: _drafts,
        onDelete: _deleteDraft,
        onEdit: _showDraftEditor,
        onCopy: (draft) => _publishTextWithFeedback(
          draft.publishText,
          message: context.l10n.draftsCopied,
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
        fieldRules: _fieldRules,
        onFieldRulesChanged: _saveFieldRules,
        onOpenShortcuts: openShortcutsApp,
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
