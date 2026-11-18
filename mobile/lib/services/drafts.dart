class DraftEntry {
  const DraftEntry({
    required this.text,
    required this.profileName,
    required this.createdAt,
  });

  final String text;
  final String profileName;
  final DateTime createdAt;

  DraftEntry copyWith({String? text}) {
    return DraftEntry(
      text: text ?? this.text,
      profileName: profileName,
      createdAt: createdAt,
    );
  }
}
