import 'package:flutter/material.dart';

import 'sk_pressable.dart';
import 'tokens.dart';

class SkSegment<T> {
  const SkSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// DESIGN §5 segmented choice. Track = frame; the selected segment is an
/// accent-subtle fill (never an outline). Every segment is ≥ 44 tall.
///
/// [scrollable]: segments take their natural width in a horizontal scroll
/// (open-ended lists such as voice profiles); otherwise they share the width.
class SkSegmented<T> extends StatelessWidget {
  const SkSegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.scrollable = false,
    this.semanticLabel,
    super.key,
  });

  final List<SkSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final bool scrollable;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    Widget segment(SkSegment<T> s) {
      final isSelected = s.value == selected;
      final enabled = onChanged != null;
      final fg = !enabled
          ? c.textTertiary
          : isSelected
          ? c.text
          : c.textSecondary;
      return SkPressable(
        onTap: enabled
            ? () {
                if (!isSelected) onChanged!(s.value);
              }
            : null,
        selected: isSelected,
        builder: (context, pressed) => SkFill(
          radius: SkShape.control - 3,
          color: isSelected
              ? c.accentSubtle
              : pressed
              ? c.pressed
              : c.text.withValues(alpha: 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.icon != null) ...[
                Icon(s.icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (isSelected ? SkType.title : SkType.body).copyWith(
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final track = DecoratedBox(
      decoration: BoxDecoration(
        color: c.frame,
        borderRadius: BorderRadius.circular(SkShape.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: scrollable
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final s in segments) segment(s)],
              )
            : Row(
                children: [
                  for (final s in segments) Expanded(child: segment(s)),
                ],
              ),
      ),
    );

    final body = scrollable
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: track)
        : track;
    return Semantics(
      container: true,
      label: semanticLabel,
      explicitChildNodes: true,
      child: body,
    );
  }
}
