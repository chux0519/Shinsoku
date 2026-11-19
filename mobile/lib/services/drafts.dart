import 'package:shinsoku_mobile/services/capture_types.dart';

class DraftEntry {
  const DraftEntry({
    required this.text,
    required this.profileName,
    required this.createdAt,
    this.commitSuffix = CommitSuffix.none,
  });

  final String text;
  final String profileName;
  final DateTime createdAt;

  /// The recording profile's suffix, added when the draft is published or
  /// copied; [text] itself is plain. Drafts from before live-01 T3 keep their
  /// text as it was (suffix none).
  final CommitSuffix commitSuffix;

  /// What Insert and the clipboard get: [text] + [commitSuffix].
  String get publishText => withCommitSuffix(text, commitSuffix);

  DraftEntry copyWith({String? text}) {
    return DraftEntry(
      text: text ?? this.text,
      profileName: profileName,
      createdAt: createdAt,
      commitSuffix: commitSuffix,
    );
  }
}
