import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'sk_pressable.dart';
import 'tokens.dart';

/// DESIGN §5 card: raised surface, radius 14, no shadow.
class SkCard extends StatelessWidget {
  const SkCard({
    required this.child,
    this.padding = const EdgeInsets.all(SkSpace.l),
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: c.raised,
          borderRadius: BorderRadius.circular(SkShape.card),
        ),
        child: Padding(padding: padding, child: child),
      );
    }
    return SkPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => SkFill(
        radius: SkShape.card,
        color: pressed ? Color.alphaBlend(c.pressed, c.raised) : c.raised,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Section label: 11/600, tracking 0.6, upper case, secondary text.
class SkSectionLabel extends StatelessWidget {
  const SkSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(SkSpace.l, 0, SkSpace.l, SkSpace.s),
        child: Text(
          text.toUpperCase(),
          style: SkType.sectionLabel.copyWith(
            color: SkColors.of(context).textSecondary,
          ),
        ),
      ),
    );
  }
}

/// DESIGN §5 grouped section: an optional label, rows on a raised surface
/// separated by inset hairlines, an optional footer note.
class SkSection extends StatelessWidget {
  const SkSection({required this.children, this.label, this.footer, super.key});

  final String? label;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(start: SkSpace.l),
            child: Container(height: SkShape.hairline, color: c.hairline),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) SkSectionLabel(label!),
        ClipRRect(
          borderRadius: BorderRadius.circular(SkShape.card),
          child: ColoredBox(
            color: c.raised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SkSpace.l,
              SkSpace.s,
              SkSpace.l,
              0,
            ),
            child: Text(
              footer!,
              style: SkType.caption.copyWith(color: c.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// Padding for free content (fields, buttons) inside an [SkSection].
class SkSectionBody extends StatelessWidget {
  const SkSectionBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SkSpace.l,
        vertical: SkSpace.m,
      ),
      child: child,
    );
  }
}

/// DESIGN §5 list row: one detail per row, ≥ 44 tall, pressed = fill.
class SkListRow extends StatelessWidget {
  const SkListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.chevron = false,
    this.selected = false,
    this.destructive = false,
    this.accentTitle = false,
    this.subtitleMaxLines = 2,
    this.customSemanticsActions,
    super.key,
  }) : toggleValue = null,
       onToggle = null;

  /// A row whose trailing control is a switch; the whole row toggles it.
  const SkListRow.toggle({
    required this.title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.subtitle,
    this.leading,
    this.subtitleMaxLines = 2,
    super.key,
  }) : toggleValue = value,
       onToggle = onChanged,
       trailing = null,
       value = null,
       onTap = null,
       chevron = false,
       selected = false,
       destructive = false,
       accentTitle = false,
       customSemanticsActions = null;

  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;

  /// Trailing value text (secondary).
  final String? value;
  final VoidCallback? onTap;
  final bool chevron;

  /// Selection is a fill (DESIGN §2) plus a check for VoiceOver and clarity.
  final bool selected;
  final bool destructive;

  /// Accent title for action rows ("Add profile").
  final bool accentTitle;
  final int subtitleMaxLines;
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final isToggle = toggleValue != null;
    final tap = isToggle
        ? (onToggle == null ? null : () => onToggle!(!toggleValue!))
        : onTap;
    final titleColor = destructive
        ? c.danger
        : accentTitle
        ? c.accent
        : c.text;
    return SkPressable(
      onTap: tap,
      selected: selected ? true : null,
      toggled: toggleValue,
      customSemanticsActions: customSemanticsActions,
      builder: (context, pressed) {
        final fill = selected
            ? c.accentSubtle
            : pressed
            ? c.pressed
            : c.text.withValues(alpha: 0);
        return AnimatedContainer(
          duration: SkMotion.of(context, SkMotion.fast),
          color: fill,
          padding: const EdgeInsets.symmetric(
            horizontal: SkSpace.l,
            vertical: 11,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(
                  leading,
                  size: 22,
                  color: destructive
                      ? c.danger
                      : accentTitle
                      ? c.accent
                      : c.textSecondary,
                ),
                const SizedBox(width: SkSpace.m),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: SkType.body.copyWith(color: titleColor)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: subtitleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: SkType.secondary.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: SkSpace.s),
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: SkType.body.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: SkSpace.s),
                trailing!,
              ],
              if (isToggle) ...[
                const SizedBox(width: SkSpace.s),
                ExcludeSemantics(
                  child: SkSwitch(value: toggleValue!, onChanged: onToggle),
                ),
              ],
              if (selected) ...[
                const SizedBox(width: SkSpace.s),
                Icon(Icons.check_rounded, size: 20, color: c.accent),
              ],
              if (chevron) ...[
                const SizedBox(width: SkSpace.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: c.textTertiary,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// iOS switch in the accent colour.
class SkSwitch extends StatelessWidget {
  const SkSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: c.accent,
      inactiveTrackColor: c.text.withValues(alpha: 0.16),
    );
  }
}
