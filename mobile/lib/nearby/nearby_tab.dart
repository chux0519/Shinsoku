import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

import 'nearby_microphone_view.dart';

/// The Desktop tab: pairing with Shinsoku Pro, otherwise what Desktop is and
/// the way to the Pro sheet (pricing-01).
class NearbyTab extends StatelessWidget {
  const NearbyTab({required this.profiles, super.key});

  final List<NearbyProfileOption> profiles;

  @override
  Widget build(BuildContext context) {
    if (ProScope.ownedOf(context)) {
      return NearbyMicrophoneView(profiles: profiles);
    }
    final l = context.l10n;
    return SkPage(
      key: const ValueKey('nearby-locked'),
      title: l.nearbyTitle,
      subtitle: l.nearbySubtitle,
      children: [
        SkProLockedNote(text: l.proLockedDesktop, action: false),
        const SizedBox(height: SkSpace.l),
        SkButton(
          key: const ValueKey('nearby-unlock'),
          label: l.proBuy,
          expand: true,
          onPressed: () => showProSheet(context),
        ),
      ],
    );
  }
}
