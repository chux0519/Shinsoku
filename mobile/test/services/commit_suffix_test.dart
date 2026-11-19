import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/drafts.dart';

void main() {
  test('withCommitSuffix trims, then adds the suffix', () {
    expect(withCommitSuffix(' Example. ', CommitSuffix.none), 'Example.');
    expect(withCommitSuffix(' Example. ', CommitSuffix.space), 'Example. ');
    expect(withCommitSuffix('Example.', CommitSuffix.newline), 'Example.\n');
  });

  test('a draft publishes text + its suffix; copyWith keeps the suffix; '
      'old drafts (no suffix) publish what they have', () {
    final draft = DraftEntry(
      text: 'Example.',
      profileName: 'Chat',
      createdAt: DateTime(2026),
      commitSuffix: CommitSuffix.newline,
    );
    expect(draft.publishText, 'Example.\n');
    expect(draft.copyWith(text: 'Edited.').publishText, 'Edited.\n');
    final old = DraftEntry(
      text: 'Old draft with its suffix ',
      profileName: 'Bailian',
      createdAt: DateTime(2025),
    );
    expect(old.commitSuffix, CommitSuffix.none);
    expect(old.publishText, 'Old draft with its suffix');
  });
}
