import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sk_pressable.dart';
import 'tokens.dart';

enum SkRecordState {
  /// Ready: accent fill, microphone.
  idle,

  /// Microphone live: danger fill (the recording indicator), stop square.
  listening,

  /// Waiting for text: neutral fill with the one indeterminate indicator.
  processing,

  /// Cannot record right now (not connected, no permission): neutral fill.
  unavailable,
}

/// DESIGN §5 "the one big control". Light haptic on start/stop (§4). While
/// listening, an optional [level] (0–1, from the microphone) widens the ring:
/// the level meter is the only loop DESIGN allows, and it is driven by audio,
/// not by a timer.
class SkRecordButton extends StatelessWidget {
  const SkRecordButton({
    required this.state,
    required this.onPressed,
    this.level,
    this.size = 88,
    this.semanticLabel,
    super.key,
  });

  final SkRecordState state;
  final VoidCallback? onPressed;
  final double? level;
  final double size;
  final String? semanticLabel;

  String get _defaultLabel => switch (state) {
    SkRecordState.idle => 'Start recording',
    SkRecordState.listening => 'Stop recording',
    SkRecordState.processing => 'Transcribing',
    SkRecordState.unavailable => 'Recording unavailable',
  };

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final enabled = onPressed != null && state != SkRecordState.processing;
    final (Color fill, Color fg, IconData? icon) = switch (state) {
      SkRecordState.idle => (c.accent, c.onAccent, Icons.mic_rounded),
      SkRecordState.listening => (c.danger, c.onAccent, Icons.stop_rounded),
      SkRecordState.processing => (c.frame, c.accent, null),
      SkRecordState.unavailable => (
        c.frame,
        enabled ? c.textSecondary : c.textTertiary,
        Icons.mic_off_rounded,
      ),
    };
    final ring = state == SkRecordState.listening
        ? 6 + 10 * (level ?? 0).clamp(0.0, 1.0)
        : 0.0;
    return SkPressable(
      onTap: enabled
          ? () {
              if (state == SkRecordState.idle ||
                  state == SkRecordState.listening) {
                HapticFeedback.lightImpact();
              }
              onPressed!();
            }
          : null,
      semanticLabel: semanticLabel ?? _defaultLabel,
      minSize: Size.square(size + 32),
      builder: (context, pressed) {
        final duration = SkMotion.of(context, SkMotion.fast);
        return Center(
          child: AnimatedContainer(
            duration: duration,
            curve: SkMotion.enter,
            width: size + ring * 2,
            height: size + ring * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ring > 0
                  ? c.danger.withValues(alpha: 0.18)
                  : c.danger.withValues(alpha: 0),
            ),
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: duration,
              curve: SkMotion.enter,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pressed
                    ? Color.alphaBlend(c.canvas.withValues(alpha: 0.18), fill)
                    : fill,
              ),
              alignment: Alignment.center,
              child: icon == null
                  ? SkActivityIndicator(size: size * 0.32, color: fg)
                  : Icon(icon, size: size * 0.42, color: fg),
            ),
          ),
        );
      },
    );
  }
}
