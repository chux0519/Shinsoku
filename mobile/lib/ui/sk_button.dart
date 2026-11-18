import 'package:flutter/material.dart';

import 'sk_pressable.dart';
import 'tokens.dart';

enum SkButtonVariant { primary, secondary, text }

/// DESIGN §5 button. One primary per screen; secondary is a neutral fill;
/// text is an accent label with a pressed fill.
class SkButton extends StatelessWidget {
  const SkButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = SkButtonVariant.primary,
    this.expand = false,
    this.busy = false,
    this.destructive = false,
    super.key,
  });

  const SkButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.destructive = false,
    super.key,
  }) : variant = SkButtonVariant.secondary;

  const SkButton.text({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.destructive = false,
    super.key,
  }) : variant = SkButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SkButtonVariant variant;

  /// Fill the available width.
  final bool expand;

  /// Shows the activity indicator instead of the icon and ignores taps.
  final bool busy;

  /// Danger colour for the label (destructive actions).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final enabled = onPressed != null && !busy;
    return SkPressable(
      onTap: enabled ? onPressed : null,
      minSize: Size(
        SkShape.minTarget,
        variant == SkButtonVariant.text ? SkShape.minTarget : 48,
      ),
      builder: (context, pressed) {
        final (Color fill, Color fg) = switch (variant) {
          SkButtonVariant.primary =>
            enabled
                ? (destructive ? c.danger : c.accent, c.onAccent)
                : (c.frame, c.textTertiary),
          SkButtonVariant.secondary => (
            c.text.withValues(alpha: pressed ? 0.14 : 0.08),
            !enabled
                ? c.textTertiary
                : destructive
                ? c.danger
                : c.text,
          ),
          SkButtonVariant.text => (
            pressed ? c.pressed : c.text.withValues(alpha: 0),
            !enabled
                ? c.textTertiary
                : destructive
                ? c.danger
                : c.accent,
          ),
        };
        final pressedFill = variant == SkButtonVariant.primary && pressed
            ? Color.alphaBlend(c.canvas.withValues(alpha: 0.18), fill)
            : fill;
        final leading = busy
            ? SkActivityIndicator(size: 18, color: fg)
            : icon == null
            ? null
            : Icon(icon, size: 20, color: fg);
        return SkFill(
          color: pressedFill,
          padding: EdgeInsets.symmetric(
            horizontal: variant == SkButtonVariant.text ? 12 : 18,
            vertical: 10,
          ),
          alignment: expand ? Alignment.center : null,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: SkType.title.copyWith(color: fg),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// DESIGN §5 icon-only control. [tooltip] is also the VoiceOver label.
class SkIconButton extends StatelessWidget {
  const SkIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.filled = false,
    this.size = 22,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  /// A neutral round fill behind the icon (toolbar-style buttons).
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final enabled = onPressed != null;
    final fg = enabled
        ? (color ?? c.textSecondary)
        : c.textTertiary.withValues(alpha: 0.5);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: SkPressable(
        onTap: onPressed,
        semanticLabel: tooltip,
        builder: (context, pressed) => SizedBox.square(
          dimension: SkShape.minTarget,
          child: Center(
            child: SkFill(
              radius: SkShape.pill,
              color: pressed
                  ? c.text.withValues(alpha: filled ? 0.16 : 0.08)
                  : filled
                  ? c.text.withValues(alpha: 0.08)
                  : c.text.withValues(alpha: 0),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(icon, size: size, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
