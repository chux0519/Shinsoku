import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/features/common/widgets.dart';

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
