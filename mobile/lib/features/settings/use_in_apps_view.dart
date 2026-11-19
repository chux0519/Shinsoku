import 'package:flutter/material.dart';
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

  final Future<bool> Function() onOpenShortcuts;

  /// Null: unknown / not iOS, so the iOS 16 note is not shown.
  final int? iosMajorVersion;

  static const summary =
      'Shinsoku can switch profile by itself when you open an app. '
      'Shortcuts watches for the app; Shinsoku sets the profile.';

  static const openSteps = [
    'In Shortcuts, open Automation and tap New Automation.',
    'Choose App, pick the app, and select Is Opened. Turn on Run Immediately.',
    'Add the action Set Shinsoku Profile and choose the profile for that app.',
  ];

  static const closeSteps = [
    'Add a second automation for the same app and select Is Closed. Turn on '
        'Run Immediately.',
    'Add Set Shinsoku Profile and choose your default profile, so other apps '
        'go back to it.',
  ];

  static const keyboardNote =
      'You can also tap the profile name in the keyboard to switch. A choice '
      'you make there wins over an automation.';

  static const iosNote = 'The Shortcuts actions need iOS 16 or later.';

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final oldIos = iosMajorVersion != null && iosMajorVersion! < 16;
    return Scaffold(
      appBar: SkTopBar(
        title: 'Use in apps',
        leading: SkIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Back',
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
                      summary,
                      style: SkType.body.copyWith(color: c.textSecondary),
                    ),
                    if (oldIos) ...[
                      const SizedBox(height: SkSpace.m),
                      const SkStatusLine(
                        icon: Icons.info_outline_rounded,
                        tone: SkTone.warning,
                        text: iosNote,
                      ),
                    ],
                    const SizedBox(height: SkSpace.l),
                    SkSection(
                      label: 'When the app is opened',
                      children: [
                        for (var i = 0; i < openSteps.length; i++)
                          _StepRow(number: i + 1, text: openSteps[i]),
                      ],
                    ),
                    const SizedBox(height: SkSpace.l),
                    SkSection(
                      label: 'When the app is closed',
                      children: [
                        for (var i = 0; i < closeSteps.length; i++)
                          _StepRow(number: i + 1, text: closeSteps[i]),
                      ],
                    ),
                    const SizedBox(height: SkSpace.l),
                    Text(
                      keyboardNote,
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
                child: SkButton(
                  label: 'Open Shortcuts',
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
