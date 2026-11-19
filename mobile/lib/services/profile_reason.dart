import 'package:shinsoku_mobile/services/active_profile.dart';

/// Secondary text under the Record status line: which profile is active and
/// why. The field-rule source shows only in the keyboard (the app can't see
/// the field), so it reads as the default here.
String activeProfileReason(String profileName, ProfileSource source) {
  final why = switch (source) {
    ProfileSource.manual => 'set by you',
    ProfileSource.automation => 'set by automation',
    ProfileSource.fieldRule || ProfileSource.byDefault => 'default',
  };
  return '$profileName · $why';
}
