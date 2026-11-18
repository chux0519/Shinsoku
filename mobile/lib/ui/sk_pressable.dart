import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'tokens.dart';

/// Shared tap behaviour for Sk controls: pressed state is a fill change
/// (DESIGN §2), the target is at least 44×44 (§3), and the fill animates only
/// when Reduce Motion is off (§4).
class SkPressable extends StatefulWidget {
  const SkPressable({
    required this.onTap,
    required this.builder,
    this.semanticLabel,
    this.selected,
    this.toggled,
    this.customSemanticsActions,
    this.minSize = const Size(SkShape.minTarget, SkShape.minTarget),
    super.key,
  });

  final VoidCallback? onTap;

  /// Builds the control for the current pressed state.
  final Widget Function(BuildContext context, bool pressed) builder;

  /// Replaces the children's semantics (icon-only controls).
  final String? semanticLabel;
  final bool? selected;
  final bool? toggled;
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;
  final Size minSize;

  @override
  State<SkPressable> createState() => _SkPressableState();
}

class _SkPressableState extends State<SkPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minSize.width,
        minHeight: widget.minSize.height,
      ),
      child: widget.builder(context, enabled && _pressed),
    );
    if (widget.semanticLabel != null) {
      child = ExcludeSemantics(child: child);
    }
    return Semantics(
      container: true,
      button: widget.toggled == null,
      enabled: enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      customSemanticsActions: widget.customSemanticsActions,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: enabled ? () => _set(false) : null,
          onTap: widget.onTap,
          child: child,
        ),
      ),
    );
  }
}

/// A fill that follows the pressed state with DESIGN §4 timing.
class SkFill extends StatelessWidget {
  const SkFill({
    required this.color,
    required this.child,
    this.radius = SkShape.control,
    this.padding,
    this.alignment,
    super.key,
  });

  final Color color;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: SkMotion.of(context, SkMotion.fast),
      curve: SkMotion.enter,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// The single indeterminate indicator DESIGN §4 allows. Under Reduce Motion
/// (and in host renders, which set it) it is a still arc.
class SkActivityIndicator extends StatelessWidget {
  const SkActivityIndicator({this.size = 18, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SkColors.of(context).accent;
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: c,
        value: SkMotion.reduced(context) ? 0.7 : null,
      ),
    );
  }
}
