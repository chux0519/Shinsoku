import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// DESIGN §7 Record (home): status line, transcript area, one record button
/// in the bottom third. Errors stay inline on the status line with their fix.
class RecordView extends StatelessWidget {
  const RecordView({
    required this.profiles,
    required this.selectedProfileIndex,
    required this.captureState,
    required this.microphoneAllowed,
    required this.smokeTestStatus,
    required this.onProfileSelected,
    required this.onCapturePressed,
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

  /// Fix for "Microphone access is off".
  final VoidCallback? onOpenMicrophoneSettings;

  /// Fix for missing provider settings (switches to the Settings tab).
  final VoidCallback? onOpenSettings;

  /// "Chat · set by you": which profile is active and why (profile-01).
  final String? profileReason;

  @override
  Widget build(BuildContext context) {
    final status = smokeTestStatus;
    final transcript = status?.transcript;
    final microphoneBlocked =
        status != null &&
        status.failed &&
        status.fix == StatusFix.microphone &&
        !microphoneAllowed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = skPageInsets(context, constraints.maxWidth);
        final safe = MediaQuery.paddingOf(context);
        return CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: insets.copyWith(
                  top: safe.top + SkSpace.s,
                  bottom: safe.bottom + SkSpace.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SkPageHeader(title: 'Shinsoku'),
                    _statusLine(context, status),
                    if (profileReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: SkSpace.xs),
                        child: Text(
                          profileReason!,
                          key: const ValueKey('record-profile-reason'),
                          style: SkType.secondary.copyWith(
                            color: SkColors.of(context).textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: SkSpace.l),
                    Expanded(
                      child: transcript != null && transcript.isNotEmpty
                          ? Align(
                              alignment: Alignment.topLeft,
                              child: SelectableText(
                                transcript,
                                key: const ValueKey('soniox-smoke-transcript'),
                                style: SkType.transcript.copyWith(
                                  color: SkColors.of(context).text,
                                ),
                              ),
                            )
                          : captureState == CaptureState.idle && status == null
                          ? const Center(
                              child: SkEmptyLine(
                                'Tap the microphone and start speaking.',
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: SkSpace.l),
                    Center(
                      child: SkSegmented<int>(
                        semanticLabel: 'Profile',
                        scrollable: true,
                        segments: [
                          for (var i = 0; i < profiles.length; i++)
                            SkSegment(value: i, label: profiles[i].name),
                        ],
                        selected: selectedProfileIndex,
                        onChanged: captureState == CaptureState.idle
                            ? onProfileSelected
                            : null,
                      ),
                    ),
                    const SizedBox(height: SkSpace.l),
                    Center(
                      child: SkRecordButton(
                        state: switch (captureState) {
                          CaptureState.listening => SkRecordState.listening,
                          CaptureState.processing => SkRecordState.processing,
                          CaptureState.idle =>
                            microphoneBlocked
                                ? SkRecordState.unavailable
                                : SkRecordState.idle,
                        },
                        onPressed: onCapturePressed,
                      ),
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
        StatusFix.microphone => ('Open Settings', onOpenMicrophoneSettings),
        StatusFix.providerSettings => ('Open Settings', onOpenSettings),
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
    return switch (captureState) {
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
        text: status?.label ?? 'Transcribing',
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
