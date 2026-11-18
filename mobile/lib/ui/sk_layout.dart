import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sk_pressable.dart';
import 'tokens.dart';

/// Horizontal page insets from the constraints: DESIGN §3 margin (16, or 20
/// at ≥ 600), each side's own safe inset (iPhone Duo has a trailing-only
/// inset), and centring past [maxContentWidth].
EdgeInsets skPageInsets(
  BuildContext context,
  double width, {
  double maxContentWidth = SkLayout.maxContentWidth,
}) {
  final safe = MediaQuery.paddingOf(context);
  final margin = SkSpace.margin(width);
  final left = safe.left + margin;
  final right = safe.right + margin;
  final extra = math.max(0.0, (width - left - right - maxContentWidth) / 2);
  return EdgeInsets.only(left: left + extra, right: right + extra);
}

abstract final class SkLayout {
  /// Single-column reading width on wide windows (iPhone Duo unfolded).
  static const double maxContentWidth = 600;
}

/// Marks pages whose surrounding chrome already names them (the iPhone Duo
/// pane switcher). An [SkPage] with only a title then drops its header
/// instead of repeating the switcher's label.
class SkTitledByChrome extends InheritedWidget {
  const SkTitledByChrome({required super.child, super.key});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkTitledByChrome>() != null;

  @override
  bool updateShouldNotify(SkTitledByChrome oldWidget) => false;
}

/// A scrolling single-column page: header, then [children], laid out from the
/// constraints (no device-size guesses).
class SkPage extends StatelessWidget {
  const SkPage({
    required this.children,
    this.title,
    this.subtitle,
    this.trailing = const [],
    this.controller,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> trailing;
  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = skPageInsets(context, constraints.maxWidth);
        final safe = MediaQuery.paddingOf(context);
        final showHeader =
            title != null &&
            (subtitle != null ||
                trailing.isNotEmpty ||
                !SkTitledByChrome.of(context));
        return ListView(
          controller: controller,
          padding: insets.copyWith(
            top: safe.top + SkSpace.s,
            bottom: safe.bottom + SkSpace.xl,
          ),
          children: [
            if (showHeader)
              SkPageHeader(
                title: title!,
                subtitle: subtitle,
                trailing: trailing,
              ),
            ...children,
          ],
        );
      },
    );
  }
}

/// Page title (17/600) with an optional secondary line and trailing icons.
class SkPageHeader extends StatelessWidget {
  const SkPageHeader({
    required this.title,
    this.subtitle,
    this.trailing = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SkSpace.l),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SkShape.minTarget),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: SkType.pageTitle.copyWith(color: c.text),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: SkType.secondary.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

/// DESIGN §7 empty state: one line, secondary text, no illustration.
class SkEmptyLine extends StatelessWidget {
  const SkEmptyLine(this.text, {this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SkSpace.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: c.textTertiary),
            const SizedBox(width: SkSpace.s),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: SkType.body.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class SkTabItem {
  const SkTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// App navigation. Bottom bar on compact widths, a slim side bar otherwise.
/// Selection is an accent-subtle fill behind the icon plus accent colour.
class SkTabBar extends StatelessWidget {
  const SkTabBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.vertical = false,
    super.key,
  });

  final List<SkTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final safe = MediaQuery.paddingOf(context);
    Widget tab(int i) {
      final item = items[i];
      final selected = i == selectedIndex;
      final fg = selected ? c.accent : c.textSecondary;
      return SkPressable(
        onTap: () => onSelected(i),
        selected: selected,
        builder: (context, pressed) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkFill(
                radius: SkShape.pill,
                color: selected
                    ? c.accentSubtle
                    : pressed
                    ? c.pressed
                    : c.text.withValues(alpha: 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 3,
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SkType.caption.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tab labels stay legible but do not grow without bound (iOS caps tab bar
    // text the same way).
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final bar = vertical
        ? Padding(
            padding: EdgeInsets.only(
              top: safe.top + SkSpace.s,
              left: safe.left,
              bottom: safe.bottom,
            ),
            child: SizedBox(
              width: 84,
              child: Column(
                children: [for (var i = 0; i < items.length; i++) tab(i)],
              ),
            ),
          )
        : Padding(
            padding: EdgeInsets.only(
              left: safe.left,
              right: safe.right,
              bottom: safe.bottom,
              top: 2,
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) Expanded(child: tab(i)),
              ],
            ),
          );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.canvas,
          border: vertical
              ? Border(
                  right: BorderSide(color: c.hairline, width: SkShape.hairline),
                )
              : Border(
                  top: BorderSide(color: c.hairline, width: SkShape.hairline),
                ),
        ),
        child: bar,
      ),
    );
  }
}

/// Top bar for pushed screens: a leading control, a centred page title and
/// optional trailing controls. Respects the top and side safe insets.
class SkTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SkTopBar({
    required this.title,
    this.leading,
    this.trailing = const [],
    super.key,
  });

  final String title;
  final Widget? leading;
  final List<Widget> trailing;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final safe = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: c.canvas,
      child: Padding(
        padding: EdgeInsets.only(
          top: safe.top,
          left: safe.left + SkSpace.xs,
          right: safe.right + SkSpace.xs,
        ),
        child: SizedBox(
          height: 52,
          child: NavigationToolbar(
            leading: leading,
            middle: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SkType.pageTitle.copyWith(color: c.text),
              ),
            ),
            trailing: trailing.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: trailing),
          ),
        ),
      ),
    );
  }
}
