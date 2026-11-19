import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';
import 'package:shinsoku_mobile/services/shortcuts.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// Settings › Profiles › Use in apps: how to switch profile per app with a
/// Shortcuts personal automation (profile-01). Numbered steps, one primary
/// action.
class UseInAppsView extends StatelessWidget {
  const UseInAppsView({
    this.onOpenShortcuts = openShortcutsApp,
    this.iosMajorVersion,
    super.key,
  });

  /// Reads the version from the host (null off-device) and builds the view.
  static Widget withSystemVersion({
    Future<bool> Function() onOpenShortcuts = openShortcutsApp,
  }) => FutureBuilder<int?>(
    future: systemMajorVersion(),
    builder: (context, snapshot) => UseInAppsView(
      onOpenShortcuts: onOpenShortcuts,
      iosMajorVersion: snapshot.data,
    ),
  );

  final Future<bool> Function() onOpenShortcuts;

  /// Null: unknown / not iOS, so the iOS 16 note is not shown.
  final int? iosMajorVersion;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final l = context.l10n;
    final openSteps = [
      l.useInAppsOpenStep1,
      l.useInAppsOpenStep2,
      l.useInAppsOpenStep3,
    ];
    final closeSteps = [l.useInAppsCloseStep1, l.useInAppsCloseStep2];
    final oldIos = iosMajorVersion != null && iosMajorVersion! < 16;
    // pricing-01: Shortcuts profile switching needs Pro; the steps stay
    // readable and the primary action opens the Pro sheet.
    final locked = !ProScope.ownedOf(context);
    return Scaffold(
      appBar: SkTopBar(
        title: l.settingsUseInApps,
        leading: SkIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: l.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final insets = skPageInsets(context, constraints.maxWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: insets.copyWith(top: SkSpace.s, bottom: SkSpace.xl),
                  children: [
                    Text(
                      l.useInAppsSummary,
                      style: SkType.body.copyWith(color: c.textSecondary),
                    ),
                    if (locked) ...[
                      const SizedBox(height: SkSpace.l),
                      SkProLockedNote(
                        text: l.proLockedUseInApps,
                        action: false,
                      ),
                    ],
                    if (oldIos) ...[
                      const SizedBox(height: SkSpace.m),
                      SkStatusLine(
                        icon: Icons.info_outline_rounded,
                        tone: SkTone.warning,
                        text: l.useInAppsIosNote,
                      ),
                    ],
                    const SizedBox(height: SkSpace.l),
                    SkSection(
                      label: l.useInAppsWhenOpened,
                      children: [
                        for (var i = 0; i < openSteps.length; i++)
                          _StepRow(number: i + 1, text: openSteps[i]),
                      ],
                    ),
                    const SizedBox(height: SkSpace.l),
                    SkSection(
                      label: l.useInAppsWhenClosed,
                      children: [
                        for (var i = 0; i < closeSteps.length; i++)
                          _StepRow(number: i + 1, text: closeSteps[i]),
                      ],
                    ),
                    const SizedBox(height: SkSpace.l),
                    Text(
                      l.useInAppsKeyboardNote,
                      style: SkType.secondary.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: SkSpace.s),
                    Text(
                      l.useInAppsReadyMade,
                      style: SkType.secondary.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: insets.copyWith(
                  top: SkSpace.s,
                  bottom: MediaQuery.paddingOf(context).bottom + SkSpace.l,
                ),
                child: locked
                    ? SkButton(
                        key: const ValueKey('use-in-apps-unlock'),
                        label: l.proBuy,
                        expand: true,
                        onPressed: () => showProSheet(context),
                      )
                    : SkButton(
                        label: l.useInAppsOpenShortcuts,
                        icon: Icons.open_in_new_rounded,
                        expand: true,
                        onPressed: onOpenShortcuts,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SkSpace.l,
          vertical: SkSpace.m,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accentSubtle,
                borderRadius: BorderRadius.circular(SkShape.pill),
              ),
              child: Text(
                '$number',
                style: SkType.secondary.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: SkSpace.m),
            Expanded(
              child: Text(text, style: SkType.body.copyWith(color: c.text)),
            ),
          ],
        ),
      ),
    );
  }
}
