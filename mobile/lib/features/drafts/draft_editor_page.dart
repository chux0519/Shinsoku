import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// A draft opened from Drafts, in the same borderless transcript editor as
/// the Record screen (live-01). Top bar: back, Copy, Save. Leaving with
/// unsaved edits keeps them (back and the swipe-back gesture save too);
/// emptying the text never empties the draft.
class DraftEditorPage extends StatefulWidget {
  const DraftEditorPage({
    required this.draft,
    required this.onSave,
    required this.onCopy,
    super.key,
  });

  final DraftEntry draft;

  /// The edited text for this same draft (L3: never a second draft).
  final ValueChanged<String> onSave;

  /// Save, then publish as the latest text for the keyboard and clipboard.
  final ValueChanged<String> onCopy;

  @override
  State<DraftEditorPage> createState() => _DraftEditorPageState();
}

class _DraftEditorPageState extends State<DraftEditorPage> {
  late final SkTranscriptController _controller;
  final _focus = FocusNode(debugLabel: 'draft');
  late String _baseline;

  @override
  void initState() {
    super.initState();
    _baseline = widget.draft.text;
    _controller = SkTranscriptController(text: _baseline)
      ..addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _hasText => _controller.text.trim().isNotEmpty;

  void _keepEdits() {
    _controller.commitComposing();
    final text = _controller.text;
    if (!_hasText || text == _baseline) return;
    _baseline = text;
    widget.onSave(text);
  }

  void _save() {
    _keepEdits();
    Navigator.of(context).maybePop();
  }

  void _copy() {
    _controller.commitComposing();
    final text = _controller.text;
    _baseline = text;
    widget.onCopy(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final draft = widget.draft;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(draft.createdAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _keepEdits();
      },
      child: Scaffold(
        appBar: SkTopBar(
          title: SkStrings.draftEditorTitle,
          leading: SkIconButton(
            key: const ValueKey('draft-editor-back'),
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: SkStrings.back,
            size: 20,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          trailing: [
            SkIconButton(
              key: const ValueKey('draft-editor-copy'),
              icon: Icons.content_copy_outlined,
              tooltip: SkStrings.copy,
              onPressed: _hasText ? _copy : null,
            ),
            SkButton.text(
              key: const ValueKey('draft-editor-save'),
              label: SkStrings.save,
              onPressed: _hasText ? _save : null,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final insets = skPageInsets(context, constraints.maxWidth);
            return Padding(
              padding: insets.copyWith(
                top: SkSpace.s,
                // The safe inset shrinks to 0 under the software keyboard.
                bottom: SkSpace.l + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    SkStrings.capturedWith(time, draft.profileName),
                    style: SkType.caption.copyWith(color: c.textTertiary),
                  ),
                  const SizedBox(height: SkSpace.m),
                  Expanded(
                    child: SkTranscriptArea(
                      fieldKey: const ValueKey('draft-editor-field'),
                      semanticsIdentifier: 'draft-editor-area',
                      controller: _controller,
                      focusNode: _focus,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
