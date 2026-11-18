import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// DESIGN §7 keyboard setup guide: numbered steps, one "Open Settings".
class KeyboardSetupView extends StatelessWidget {
  const KeyboardSetupView({this.onOpenSettings = openAppSettings, super.key});

  final Future<bool> Function() onOpenSettings;

  static const steps = [
    'Open Settings › General › Keyboard › Keyboards.',
    'Tap Add New Keyboard and choose Shinsoku.',
    'Tap Shinsoku and turn on Allow Full Access, so the keyboard can insert '
        'your latest text.',
  ];

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    return Scaffold(
      appBar: SkTopBar(
        title: 'Keyboard',
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
                      'Use Shinsoku from any text field.',
                      style: SkType.body.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: SkSpace.l),
                    SkSection(
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          _StepRow(number: i + 1, text: steps[i]),
                      ],
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
                  label: 'Open Settings',
                  icon: Icons.settings_outlined,
                  expand: true,
                  onPressed: onOpenSettings,
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
