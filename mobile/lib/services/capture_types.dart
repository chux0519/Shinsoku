enum CaptureState { idle, listening, processing }

enum CommitSuffix { none, space, newline }

/// [text], trimmed, with the profile's commit suffix: what the keyboard
/// inserts and the clipboard gets. Drafts store the plain text (live-01
/// decision 2026-11-19); the suffix is added only when publishing or copying.
String withCommitSuffix(String text, CommitSuffix suffix) {
  final trimmed = text.trim();
  return switch (suffix) {
    CommitSuffix.none => trimmed,
    CommitSuffix.space => '$trimmed ',
    CommitSuffix.newline => '$trimmed\n',
  };
}
