import 'package:flutter/material.dart';

import 'sk_button.dart';
import 'sk_pressable.dart';
import 'tokens.dart';

/// DESIGN §5 status line: state icon + text. Status colour only on the icon,
/// the text stays readable. Errors carry their fix as [actionLabel].
class SkStatusLine extends StatelessWidget {
  const SkStatusLine({
    required this.text,
    this.icon,
    this.tone = SkTone.neutral,
    this.detail,
    this.busy = false,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.detailMaxLines = 3,
    super.key,
  });

  final String text;
  final IconData? icon;
  final SkTone tone;
  final String? detail;

  /// Shows the indeterminate indicator instead of [icon].
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  final int detailMaxLines;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final iconColor = c.tone(tone);
    final leading = busy
        ? const Padding(
            padding: EdgeInsets.all(2),
            child: SkActivityIndicator(size: 18),
          )
        : icon == null
        ? null
        : Icon(icon, size: 22, color: iconColor);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(padding: const EdgeInsets.only(top: 1), child: leading),
            const SizedBox(width: SkSpace.s + 2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, style: SkType.title.copyWith(color: c.text)),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    maxLines: detailMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: SkType.secondary.copyWith(color: c.textSecondary),
                  ),
                ],
                if (actionLabel != null && onAction != null)
                  Transform.translate(
                    offset: const Offset(-12, 0),
                    child: SkButton.text(
                      key: actionKey,
                      label: actionLabel!,
                      onPressed: onAction,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// DESIGN §5 badge: a small pill with a caption, accent-subtle fill.
class SkBadge extends StatelessWidget {
  const SkBadge({
    required this.label,
    this.icon,
    this.tone = SkTone.accent,
    super.key,
  });

  final String label;
  final IconData? icon;
  final SkTone tone;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final fill = tone == SkTone.accent ? c.accentSubtle : c.frame;
    final fg = tone == SkTone.accent || tone == SkTone.neutral
        ? c.text
        : c.tone(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(SkShape.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SkType.caption.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
