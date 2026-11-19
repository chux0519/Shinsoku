import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';

/// Secondary text under the Record status line: which profile is active and
/// why. The field-rule source shows only in the keyboard (the app can't see
/// the field), so it reads as the default here.
String activeProfileReason(
  AppLocalizations l,
  String profileName,
  ProfileSource source,
) {
  final why = switch (source) {
    ProfileSource.manual => l.profileReasonManual,
    ProfileSource.automation => l.profileReasonAutomation,
    ProfileSource.fieldRule ||
    ProfileSource.byDefault => l.profileReasonDefault,
  };
  return l.profileReasonLine(profileName, why);
}
