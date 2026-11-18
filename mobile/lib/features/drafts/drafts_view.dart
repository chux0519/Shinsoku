import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/features/common/widgets.dart';

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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppHeader(title: 'Drafts', subtitle: 'Captured mobile text'),
        const SizedBox(height: 20),
        if (drafts.isEmpty)
          const InfoPanel(child: EmptyState())
        else
          for (final draft in drafts) ...[
            DraftCard(
              draft: draft,
              onDelete: () => onDelete(draft),
              onEdit: () => onEdit(draft),
              onCopy: () => onCopy(draft),
            ),
            const SizedBox(height: 12),
          ],
      ],
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
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text('Edit draft'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Captured with ${widget.draft.profileName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('draft-editor-field'),
                  controller: _controller,
                  autofocus: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    labelText: 'Transcript',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const ValueKey('draft-save-button'),
                        onPressed: _hasText
                            ? () => _complete(copyToClipboard: false)
                            : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('draft-save-copy-button'),
                        onPressed: _hasText
                            ? () => _complete(copyToClipboard: true)
                            : null,
                        icon: const Icon(Icons.content_copy_outlined),
                        label: const Text('Save & Copy'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DraftCard extends StatelessWidget {
  const DraftCard({
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
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: StatusChip(
                    icon: Icons.person_search_outlined,
                    label: draft.profileName,
                  ),
                ),
                const Spacer(),
                Text(
                  _relativeTime(draft.createdAt),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(draft.text, style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit draft',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Copy draft',
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_outlined),
                ),
                IconButton(
                  tooltip: 'Delete draft',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} hr ago';
    }
    return '${diff.inDays} days ago';
  }
}
