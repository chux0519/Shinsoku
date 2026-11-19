import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/features/record/live_transcript.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// DESIGN §7 Record (home), live-01 "the transcript is the text field":
/// status line, one borderless transcript area that fills live while
/// listening and is edited in place afterwards, the profile selector, and a
/// bottom row Copy · Record/Stop · Done. Errors stay inline on the status
/// line with their fix.
class RecordView extends StatefulWidget {
  const RecordView({
    required this.profiles,
    required this.selectedProfileIndex,
    required this.captureState,
    required this.microphoneAllowed,
    required this.smokeTestStatus,
    required this.onProfileSelected,
    required this.onCapturePressed,
    this.transcript,
    this.onSaveText,
    this.onCopyText,
    this.onOpenMicrophoneSettings,
    this.onOpenSettings,
    this.profileReason,
    super.key,
  });

  final List<VoiceProfile> profiles;
  final int selectedProfileIndex;
  final CaptureState captureState;
  final bool microphoneAllowed;
  final SmokeTestStatus? smokeTestStatus;
  final ValueChanged<int> onProfileSelected;
  final VoidCallback onCapturePressed;

  /// Live words from the transcription service (T1). Without it (or while it
  /// is idle) the area follows [captureState] and the status's transcript.
  final ValueListenable<LiveTranscript>? transcript;

  /// Done, or a new recording over unsaved edits: the edited text goes into
  /// the draft this recording made (L3: never a second draft).
  final ValueChanged<String>? onSaveText;

  /// Copy: save like [onSaveText], then publish the text as the latest for
  /// the keyboard's Insert and the clipboard.
  final ValueChanged<String>? onCopyText;

  /// Fix for "Microphone access is off".
  final VoidCallback? onOpenMicrophoneSettings;

  /// Fix for missing provider settings (switches to the Settings tab).
  final VoidCallback? onOpenSettings;

  /// "Chat · set by you": which profile is active and why (profile-01).
  final String? profileReason;

  @override
  State<RecordView> createState() => _RecordViewState();
}

class _RecordViewState extends State<RecordView> {
  final _controller = SkTranscriptController();
  final _focus = FocusNode(debugLabel: 'transcript');

  /// The phase the area last showed.
  LivePhase _phase = LivePhase.idle;

  /// The text as last saved or loaded; edits are what differs from it.
  String _baseline = '';

  /// The result text last loaded into the area (a new result reloads).
  String? _loaded;

  @override
  void initState() {
    super.initState();
    widget.transcript?.addListener(_onLive);
    _controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
    _sync(duringBuild: false);
  }

  @override
  void didUpdateWidget(RecordView old) {
    super.didUpdateWidget(old);
    if (old.transcript != widget.transcript) {
      old.transcript?.removeListener(_onLive);
      widget.transcript?.addListener(_onLive);
    }
    _sync(duringBuild: true);
  }

  @override
  void dispose() {
    widget.transcript?.removeListener(_onLive);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onLive() => setState(() => _sync(duringBuild: false));

  void _onChanged() => setState(() {});

  /// What the area shows: the live transcript when the service has one,
  /// otherwise derived from the capture state and status (batch providers,
  /// smoke runs).
  LiveTranscript get _effective {
    final live = widget.transcript?.value;
    if (live != null && live.phase != LivePhase.idle) return live;
    final status = widget.smokeTestStatus;
    final text = status?.transcript ?? '';
    return switch (widget.captureState) {
      CaptureState.listening => const LiveTranscript(
        phase: LivePhase.listening,
      ),
      CaptureState.processing => const LiveTranscript(
        phase: LivePhase.processing,
      ),
      CaptureState.idle when status != null && status.failed => LiveTranscript(
        phase: LivePhase.failed,
        error: status.detail,
      ),
      CaptureState.idle when status != null && text.isNotEmpty =>
        LiveTranscript(committed: text, phase: LivePhase.done),
      CaptureState.idle => LiveTranscript.idle,
    };
  }

  static bool _isLive(LivePhase p) => switch (p) {
    LivePhase.connecting ||
    LivePhase.listening ||
    LivePhase.finishing ||
    LivePhase.processing => true,
    _ => false,
  };

  bool get _readOnly => _isLive(_phase);

  bool get _dirty =>
      !_readOnly &&
      _controller.text.trim().isNotEmpty &&
      _controller.text != _baseline;

  void _sync({required bool duringBuild}) {
    final t = _effective;
    final previous = _phase;
    switch (t.phase) {
      case LivePhase.connecting:
      case LivePhase.listening:
      case LivePhase.finishing:
      case LivePhase.processing:
        if (!_isLive(previous)) {
          // A new recording reuses the area: unsaved edits go to their draft
          // first, with any IME composition committed (L3, L4).
          _keepEdits(later: duringBuild);
          _focus.unfocus();
        }
        // Processing shows the raw words dimmed until the result swaps in.
        _controller.showLive(
          t.committed,
          t.phase == LivePhase.processing ? '' : t.pending,
        );
      case LivePhase.done:
        if (previous != LivePhase.done || t.committed != _loaded) {
          _controller.showText(t.committed);
          _baseline = t.committed;
          _loaded = t.committed;
        }
      case LivePhase.failed:
        if (previous != LivePhase.failed) {
          if (t.committed.isNotEmpty) {
            // Words heard before the failure: kept, not yet in any draft.
            _controller.showText(t.committed);
            _baseline = '';
          } else if (_controller.hasPending) {
            _controller.showText(_controller.text);
          }
        }
      case LivePhase.idle:
        if (_controller.hasPending) _controller.showText(_controller.text);
    }
    // Last: _keepEdits above judges edits by the phase the area showed.
    _phase = t.phase;
  }

  /// Saves unsaved edits into the current draft.
  void _keepEdits({bool later = false}) {
    _controller.commitComposing();
    if (!_dirty) return;
    final text = _controller.text;
    _baseline = text;
    final save = widget.onSaveText;
    if (save == null) return;
    if (later) {
      WidgetsBinding.instance.addPostFrameCallback((_) => save(text));
    } else {
      save(text);
    }
  }

  void _record() {
    if (!_readOnly) {
      _keepEdits();
      _focus.unfocus();
    }
    widget.onCapturePressed();
  }

  void _done() {
    _keepEdits();
    _focus.unfocus();
    setState(() {});
  }

  void _copy() {
    _controller.commitComposing();
    final text = _controller.text;
    _baseline = text;
    widget.onCopyText?.call(text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.smokeTestStatus;
    final microphoneBlocked =
        status != null &&
        status.failed &&
        status.fix == StatusFix.microphone &&
        !widget.microphoneAllowed;
    final c = SkColors.of(context);
    // Editing: the header and the profile selector step aside so the text
    // and the bottom row fit above the software keyboard.
    final editing = _focus.hasFocus && !_readOnly;
    final hasText = _controller.text.trim().isNotEmpty;
    final canCopy = !_readOnly && hasText && widget.onCopyText != null;
    final canDone = editing || _dirty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = skPageInsets(context, constraints.maxWidth);
        final safe = MediaQuery.paddingOf(context);
        // A short pane (iPhone Duo tabletop) drops the page title: the
        // status line already says where you are.
        final showHeader = !editing && constraints.maxHeight >= 560;
        return CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: insets.copyWith(
                  top: safe.top + SkSpace.s,
                  bottom: safe.bottom + (editing ? SkSpace.s : SkSpace.l),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeader) const SkPageHeader(title: 'Shinsoku'),
                    _statusLine(context, status),
                    if (widget.profileReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: SkSpace.xs),
                        child: Text(
                          widget.profileReason!,
                          key: const ValueKey('record-profile-reason'),
                          style: SkType.secondary.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: SkSpace.l),
                    // Keyed: the header and selector come and go with focus;
                    // the field must keep its element (and the IME link).
                    Expanded(
                      key: const ValueKey('record-transcript-slot'),
                      child: SkTranscriptArea(
                        key: const ValueKey('record-transcript'),
                        fieldKey: const ValueKey('record-transcript-field'),
                        controller: _controller,
                        focusNode: _focus,
                        readOnly: _readOnly,
                        dimmed: _phase == LivePhase.processing,
                        followEnd: _readOnly,
                        minHeight: 72,
                        placeholder: switch (_phase) {
                          LivePhase.connecting ||
                          LivePhase.listening => SkStrings.listeningPlaceholder,
                          LivePhase.idle => SkStrings.recordPlaceholder,
                          _ => null,
                        },
                      ),
                    ),
                    const SizedBox(height: SkSpace.m),
                    if (!editing) ...[
                      Center(
                        child: SkSegmented<int>(
                          semanticLabel: 'Profile',
                          scrollable: true,
                          segments: [
                            for (var i = 0; i < widget.profiles.length; i++)
                              SkSegment(
                                value: i,
                                label: widget.profiles[i].name,
                              ),
                          ],
                          selected: widget.selectedProfileIndex,
                          onChanged: widget.captureState == CaptureState.idle
                              ? widget.onProfileSelected
                              : null,
                        ),
                      ),
                      const SizedBox(height: SkSpace.l),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _Optional(
                              visible: canCopy,
                              child: SkIconButton(
                                key: const ValueKey('record-copy'),
                                icon: Icons.content_copy_outlined,
                                tooltip: SkStrings.copy,
                                onPressed: canCopy ? _copy : null,
                              ),
                            ),
                          ),
                        ),
                        SkRecordButton(
                          state: switch (widget.captureState) {
                            CaptureState.listening => SkRecordState.listening,
                            CaptureState.processing => SkRecordState.processing,
                            CaptureState.idle =>
                              microphoneBlocked
                                  ? SkRecordState.unavailable
                                  : SkRecordState.idle,
                          },
                          onPressed: _record,
                        ),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: _Optional(
                              visible: canDone,
                              child: SkButton.text(
                                key: const ValueKey('record-done'),
                                label: SkStrings.done,
                                onPressed: canDone ? _done : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusLine(BuildContext context, SmokeTestStatus? status) {
    if (status != null && status.failed) {
      final (String? label, VoidCallback? action) = switch (status.fix) {
        StatusFix.microphone => (
          'Open Settings',
          widget.onOpenMicrophoneSettings,
        ),
        StatusFix.providerSettings => ('Open Settings', widget.onOpenSettings),
        StatusFix.none => (null, null),
      };
      return SkStatusLine(
        icon: Icons.error_outline_rounded,
        tone: SkTone.danger,
        text: status.label,
        detail: status.detail,
        actionLabel: label,
        onAction: action,
        actionKey: const ValueKey('record-status-fix'),
      );
    }
    return switch (widget.captureState) {
      CaptureState.listening => const SkStatusLine(
        icon: Icons.fiber_manual_record_rounded,
        tone: SkTone.danger,
        text: 'Listening',
        detail: 'Tap stop when you are done speaking.',
      ),
      // The record button carries the one indeterminate indicator (DESIGN §4).
      CaptureState.processing => SkStatusLine(
        icon: Icons.hourglass_empty_rounded,
        tone: SkTone.accent,
        text: _phase == LivePhase.processing && _controller.text.isNotEmpty
            ? SkStrings.processing
            : status?.label ?? 'Transcribing',
        detail: status?.detail,
      ),
      CaptureState.idle when status != null && status.finished => SkStatusLine(
        icon: Icons.check_circle_outline_rounded,
        tone: SkTone.success,
        text: status.label,
        // Timing details are for smoke runs; people get the next step.
        detail: SmokeTestConfig.enabled
            ? status.detail
            : 'Copied. Paste it anywhere, or insert it from the keyboard.',
      ),
      CaptureState.idle => const SkStatusLine(
        icon: Icons.mic_none_rounded,
        text: 'Ready to record',
      ),
    };
  }
}

/// A bottom-row action that is only there when it applies: it keeps its
/// space (the record button stays centred) and leaves taps and VoiceOver
/// when hidden.
class _Optional extends StatelessWidget {
  const _Optional({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: SkMotion.of(context, SkMotion.fast),
          curve: visible ? SkMotion.enter : SkMotion.exit,
          child: child,
        ),
      ),
    );
  }
}
