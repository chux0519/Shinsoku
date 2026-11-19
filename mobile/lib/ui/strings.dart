/// User-facing text added since live-01, in one place so i18n-01 can
/// translate it without hunting through widgets.
abstract final class SkStrings {
  // Record screen.
  static const recordPlaceholder = 'Tap the microphone and start speaking.';
  static const listeningPlaceholder = 'Listening…';
  static const processing = 'Processing…';
  static const transcriptLabel = 'Transcript';
  static const copy = 'Copy';
  static const done = 'Done';
  static const save = 'Save';
  static const clear = 'Clear';
  static const back = 'Back';
  static const copied = 'Copied. Insert it from the keyboard or paste it.';
  static const saved = 'Saved.';

  // Drafts editor.
  static const draftEditorTitle = 'Draft';
  static String capturedWith(String time, String profile) => '$time · $profile';
}
