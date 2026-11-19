import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// DESIGN §7 Drafts: date-grouped list; a row is the text, time and source;
/// tap to open it in [DraftEditorPage], swipe to delete (the shell offers Undo), copy from the row.
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
      return SkPage(
        title: context.l10n.draftsTitle,
        children: [
          const SizedBox(height: SkSpace.xl),
          SkEmptyLine(context.l10n.draftsEmpty),
        ],
      );
    }
    final groups = <DateTime, List<DraftEntry>>{};
    for (final draft in drafts) {
      final d = draft.createdAt;
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(draft);
    }
    return SkPage(
      title: context.l10n.draftsTitle,
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
    final l = context.l10n;
    if (diff == 0) return l.draftsToday;
    if (diff == 1) return l.draftsYesterday;
    return DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    ).format(day);
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
                Text(
                  context.l10n.commonDelete,
                  style: SkType.title.copyWith(color: c.onAccent),
                ),
              ],
            ),
          ),
        ),
      ),
      child: SkPressable(
        onTap: onEdit,
        customSemanticsActions: {
          CustomSemanticsAction(label: context.l10n.commonCopy): onCopy,
          CustomSemanticsAction(label: context.l10n.commonDelete): onDelete,
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
                tooltip: context.l10n.draftsCopyDraft,
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
