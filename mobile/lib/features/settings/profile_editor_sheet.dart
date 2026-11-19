import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// What the profile sheet decided: a profile to save, or a delete request.
class ProfileEditResult {
  const ProfileEditResult.save(VoiceProfile this.profile) : delete = false;
  const ProfileEditResult.delete() : profile = null, delete = true;

  final VoiceProfile? profile;
  final bool delete;
}

/// Shows the new/edit profile sheet. [canDelete] offers Delete for an
/// existing profile (never the last one).
Future<ProfileEditResult?> showProfileEditor(
  BuildContext context, {
  VoiceProfile? profile,
  bool canDelete = false,
}) {
  return showSkSheet<ProfileEditResult>(
    context: context,
    builder: (context) =>
        ProfileEditorSheet(profile: profile, canDelete: canDelete),
  );
}

class ProfileEditorSheet extends StatefulWidget {
  const ProfileEditorSheet({this.profile, this.canDelete = false, super.key});

  final VoiceProfile? profile;
  final bool canDelete;

  @override
  State<ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<ProfileEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile?.name ?? '',
  );
  late final TextEditingController _intent = TextEditingController(
    text: widget.profile?.intent ?? '',
  );
  bool _intentSeeded = false;
  late CommitSuffix _suffix =
      widget.profile?.commitSuffix ?? CommitSuffix.space;
  late bool _autoCommit = widget.profile?.autoCommit ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A new profile starts with the default prompt in the app's language.
    if (!_intentSeeded && widget.profile == null) {
      _intent.text = context.l10n.profileDefaultIntent;
    }
    _intentSeeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _intent.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final intent = _intent.text.trim();
    Navigator.of(context).pop(
      ProfileEditResult.save(
        VoiceProfile(
          id:
              widget.profile?.id ??
              'profile_${DateTime.now().microsecondsSinceEpoch}',
          name: name.isEmpty ? context.l10n.profileUntitled : name,
          intent: intent.isEmpty ? context.l10n.profileDefaultIntent : intent,
          commitSuffix: _suffix,
          autoCommit: _autoCommit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.profile != null;
    final l = context.l10n;
    return SkSheet(
      title: editing ? l.profileEditTitle : l.profileNewTitle,
      actions: [
        SkButton.secondary(
          label: l.commonCancel,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SkButton(label: l.commonSave, expand: true, onPressed: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkTextArea.field(
            controller: _name,
            label: l.profileNameLabel,
            autocorrect: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: SkSpace.l),
          SkTextArea(
            controller: _intent,
            label: l.profilePromptLabel,
            helper: l.profilePromptHelper,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: SkSpace.l),
          Text(
            l.profileAfterText,
            style: SkType.secondary.copyWith(
              color: SkColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SkSegmented<CommitSuffix>(
            semanticLabel: l.profileAfterText,
            segments: [
              SkSegment(
                value: CommitSuffix.none,
                label: l.profileSuffixNothing,
              ),
              SkSegment(value: CommitSuffix.space, label: l.profileSuffixSpace),
              SkSegment(
                value: CommitSuffix.newline,
                label: l.profileSuffixNewLine,
              ),
            ],
            selected: _suffix,
            onChanged: (value) => setState(() => _suffix = value),
          ),
          const SizedBox(height: SkSpace.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(SkShape.control),
            child: ColoredBox(
              color: SkColors.of(context).frame,
              child: SkListRow.toggle(
                title: l.profileAutoCommit,
                subtitle: l.profileAutoCommitSubtitle,
                value: _autoCommit,
                onChanged: (value) => setState(() => _autoCommit = value),
              ),
            ),
          ),
          if (editing && widget.canDelete) ...[
            const SizedBox(height: SkSpace.m),
            Center(
              child: SkButton.text(
                label: l.profileDelete,
                destructive: true,
                onPressed: () =>
                    Navigator.of(context).pop(const ProfileEditResult.delete()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
