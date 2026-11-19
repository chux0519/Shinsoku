import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'strings.dart';
import 'tokens.dart';

/// The transcript's text. While a recording is live it holds committed +
/// pending words and paints the pending tail lighter ([showLive]); after the
/// recording it is plain editable text ([showText]).
class SkTranscriptController extends TextEditingController {
  SkTranscriptController({super.text});

  /// Where the pending (interim) words start; -1 when there are none.
  int _pendingFrom = -1;

  bool get hasPending => _pendingFrom >= 0 && _pendingFrom < text.length;

  /// Committed words in text colour, then [pending] in text-tertiary. The
  /// caret sits at the end so the live text stays in view.
  void showLive(String committed, String pending) {
    final all = committed + pending;
    _pendingFrom = pending.isEmpty ? -1 : committed.length;
    value = TextEditingValue(
      text: all,
      selection: TextSelection.collapsed(offset: all.length),
    );
  }

  /// Plain text, no pending tail (the result, a draft).
  void showText(String text) {
    _pendingFrom = -1;
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Ends an IME composition (marked text) so the text is final (L4).
  void commitComposing() {
    if (value.composing.isValid) {
      value = value.copyWith(composing: TextRange.empty);
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!hasPending) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final c = SkColors.of(context);
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, _pendingFrom)),
        TextSpan(
          text: text.substring(_pendingFrom),
          style: TextStyle(color: c.textTertiary),
        ),
      ],
    );
  }
}

/// DESIGN §3/§5: the transcript *is* the text field (live-01). Borderless,
/// transcript type, fills its parent. Read-only while a recording is live
/// ([readOnly]; selection and Copy still work), [dimmed] while the raw text
/// waits for post-processing, editable otherwise. Its context menu adds
/// Clear when there is text to clear.
class SkTranscriptArea extends StatefulWidget {
  const SkTranscriptArea({
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.dimmed = false,
    this.followEnd = false,
    this.placeholder,
    this.fieldKey,
    this.minHeight = 120,
    this.onClear,
    super.key,
  });

  final SkTranscriptController controller;
  final FocusNode? focusNode;
  final bool readOnly;

  /// Raw text waiting for post-processing: secondary text colour.
  final bool dimmed;

  /// Keep the last line in view as text arrives (live recording).
  final bool followEnd;
  final String? placeholder;

  /// Key for the inner TextField (tests drive it with enterText).
  final Key? fieldKey;

  /// The height the area asks for inside a scrolling page (intrinsic
  /// height); it takes whatever more its parent gives it.
  final double minHeight;

  /// Called after Clear empties the text (the default clears it).
  final VoidCallback? onClear;

  @override
  State<SkTranscriptArea> createState() => _SkTranscriptAreaState();
}

class _SkTranscriptAreaState extends State<SkTranscriptArea> {
  final _scroll = ScrollController();
  int _length = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _length = widget.controller.text.length;
  }

  @override
  void didUpdateWidget(SkTranscriptArea old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (widget.followEnd && !old.followEnd) _toEnd();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _scroll.dispose();
    super.dispose();
  }

  void _onText() {
    final length = widget.controller.text.length;
    if (length != _length && widget.followEnd) _toEnd();
    _length = length;
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _clear() {
    ContextMenuController.removeAny();
    widget.controller.showText('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final style = SkType.transcript.copyWith(
      color: widget.dimmed ? c.textSecondary : c.text,
    );
    return Semantics(
      container: true,
      label: SkStrings.transcriptLabel,
      child: _IntrinsicHeight(
        height: widget.minHeight,
        child: TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          showCursor: !widget.readOnly,
          scrollController: _scroll,
          expands: true,
          minLines: null,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          textAlignVertical: TextAlignVertical.top,
          style: style,
          cursorColor: c.accent,
          // Room under the caret so the line being typed clears the keyboard
          // and the controls beneath the area.
          scrollPadding: const EdgeInsets.all(SkSpace.xl),
          decoration: InputDecoration.collapsed(
            hintText: widget.placeholder,
            hintStyle: SkType.transcript.copyWith(color: c.textTertiary),
          ),
          contextMenuBuilder: (context, editable) {
            final items = [
              ...editable.contextMenuButtonItems,
              if (!widget.readOnly && widget.controller.text.isNotEmpty)
                ContextMenuButtonItem(
                  label: SkStrings.clear,
                  onPressed: _clear,
                ),
            ];
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editable.contextMenuAnchors,
              buttonItems: items,
            );
          },
        ),
      ),
    );
  }
}

/// Reports a fixed intrinsic height, so a page that sizes itself by its
/// content (SliverFillRemaining) gives the area [height] at least instead of
/// the full text height; the area scrolls its own text.
class _IntrinsicHeight extends SingleChildRenderObjectWidget {
  const _IntrinsicHeight({required this.height, super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderIntrinsicHeight(height);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderIntrinsicHeight renderObject,
  ) {
    renderObject.height = height;
  }
}

class _RenderIntrinsicHeight extends RenderProxyBox {
  _RenderIntrinsicHeight(this._height);

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;
}
