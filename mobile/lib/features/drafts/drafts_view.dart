import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// DESIGN §7 Drafts: date-grouped list; a row is the text, time and source;
/// tap to edit, swipe to delete (the shell offers Undo), copy from the row.
class DraftsView extends StatelessWidget {
  const DraftsView({
    required this.drafts,
    required this.onDelete,
    required this.onEdit,
    required this.onCopy,
    super.key,
  });

  final List<DraftEntry> drafts;
  final ValueChanged<DraftEntry> onDelete;
  final ValueChanged<DraftEntry> onEdit;
  final ValueChanged<DraftEntry> onCopy;

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) {
      return const SkPage(
        title: 'Drafts',
        children: [
          SizedBox(height: SkSpace.xl),
          SkEmptyLine('Your transcripts appear here after you record.'),
        ],
      );
    }
    final groups = <DateTime, List<DraftEntry>>{};
    for (final draft in drafts) {
      final d = draft.createdAt;
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(draft);
    }
    return SkPage(
      title: 'Drafts',
      children: [
        for (final MapEntry(key: day, value: items) in groups.entries) ...[
          SkSection(
            label: _dayLabel(context, day),
            children: [
              for (final draft in items)
                DraftRow(
                  key: ObjectKey(draft),
                  draft: draft,
                  onDelete: () => onDelete(draft),
                  onEdit: () => onEdit(draft),
                  onCopy: () => onCopy(draft),
                ),
            ],
          ),
          const SizedBox(height: SkSpace.xl),
        ],
      ],
    );
  }

  String _dayLabel(BuildContext context, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }
}

class DraftRow extends StatelessWidget {
  const DraftRow({
    required this.draft,
    required this.onDelete,
    required this.onEdit,
    required this.onCopy,
    super.key,
  });

  final DraftEntry draft;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(draft.createdAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Dismissible(
      key: ObjectKey(draft),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: ColoredBox(
        color: c.danger,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: SkSpace.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: c.onAccent),
                const SizedBox(width: SkSpace.s),
                Text('Delete', style: SkType.title.copyWith(color: c.onAccent)),
              ],
            ),
          ),
        ),
      ),
      child: SkPressable(
        onTap: onEdit,
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Copy'): onCopy,
          const CustomSemanticsAction(label: 'Delete'): onDelete,
        },
        builder: (context, pressed) => AnimatedContainer(
          duration: SkMotion.of(context, SkMotion.fast),
          color: pressed ? c.pressed : c.raised,
          padding: const EdgeInsetsDirectional.only(
            start: SkSpace.l,
            end: SkSpace.xs,
            top: SkSpace.m,
            bottom: SkSpace.m,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SkType.body.copyWith(color: c.text),
                    ),
                    const SizedBox(height: SkSpace.xs),
                    Text(
                      '$time · ${draft.profileName}',
                      style: SkType.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              SkIconButton(
                icon: Icons.content_copy_outlined,
                tooltip: 'Copy draft',
                size: 20,
                onPressed: onCopy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DraftEditResult {
  const DraftEditResult({required this.text, required this.copyToClipboard});

  final String text;
  final bool copyToClipboard;
}

class DraftEditorScreen extends StatefulWidget {
  const DraftEditorScreen({required this.draft, super.key});

  final DraftEntry draft;

  @override
  State<DraftEditorScreen> createState() => _DraftEditorScreenState();
}

class _DraftEditorScreenState extends State<DraftEditorScreen> {
  late final TextEditingController _controller;
  bool _hasText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft.text);
    _hasText = widget.draft.text.trim().isNotEmpty;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText == _hasText) {
      return;
    }
    setState(() {
      _hasText = hasText;
    });
  }

  void _complete({required bool copyToClipboard}) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    Navigator.of(
      context,
    ).pop(DraftEditResult(text: text, copyToClipboard: copyToClipboard));
  }

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    return Scaffold(
      appBar: SkTopBar(
        title: 'Edit draft',
        leading: SkIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final insets = skPageInsets(context, constraints.maxWidth);
          final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          return Padding(
            padding: insets.copyWith(
              top: SkSpace.s,
              bottom:
                  SkSpace.l +
                  (keyboardOpen ? 0 : MediaQuery.paddingOf(context).bottom),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Captured with ${widget.draft.profileName}',
                  style: SkType.secondary.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: SkSpace.m),
                Expanded(
                  child: SkTextArea(
                    fieldKey: const ValueKey('draft-editor-field'),
                    controller: _controller,
                    autofocus: true,
                    expands: true,
                    style: SkType.transcript,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: SkSpace.m),
                Row(
                  children: [
                    Expanded(
                      child: SkButton.secondary(
                        key: const ValueKey('draft-save-button'),
                        label: 'Save',
                        expand: true,
                        onPressed: _hasText
                            ? () => _complete(copyToClipboard: false)
                            : null,
                      ),
                    ),
                    const SizedBox(width: SkSpace.m),
                    Expanded(
                      child: SkButton(
                        key: const ValueKey('draft-save-copy-button'),
                        label: 'Save & Copy',
                        icon: Icons.content_copy_outlined,
                        expand: true,
                        onPressed: _hasText
                            ? () => _complete(copyToClipboard: true)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
