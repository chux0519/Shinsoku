import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/field_rules.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

class _Pick {
  const _Pick(this.profileId);
  final String? profileId;
}

/// Settings › Profiles › Field rules: map a kind of text field to a profile.
/// A rule applies in the keyboard only when you haven't picked a profile and
/// no automation has set one (invariant PR2).
class FieldRulesView extends StatefulWidget {
  const FieldRulesView({
    required this.profiles,
    required this.rules,
    required this.onChanged,
    super.key,
  });

  final List<VoiceProfile> profiles;
  final FieldRules rules;
  final Future<void> Function(FieldRules rules) onChanged;

  @override
  State<FieldRulesView> createState() => _FieldRulesViewState();
}

class _FieldRulesViewState extends State<FieldRulesView> {
  late FieldRules _rules = widget.rules;

  String _nameOf(String? id) {
    for (final profile in widget.profiles) {
      if (profile.id == id) return profile.name;
    }
    return context.l10n.fieldRulesNone;
  }

  Future<void> _pick(FieldKind kind) async {
    final pick = await showSkSheet<_Pick>(
      context: context,
      builder: (context) => SkSheet(
        title: fieldKindLabel(context.l10n, kind),
        child: SkSection(
          children: [
            SkListRow(
              title: context.l10n.fieldRulesNone,
              selected: _rules[kind] == null,
              onTap: () => Navigator.of(context).pop(const _Pick(null)),
            ),
            for (final profile in widget.profiles)
              SkListRow(
                title: profile.name,
                selected: _rules[kind] == profile.id,
                onTap: () => Navigator.of(context).pop(_Pick(profile.id)),
              ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    final next = _rules.set(kind, pick.profileId);
    setState(() => _rules = next);
    await widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    // pricing-01: field rules need Pro. Without it the page stays readable,
    // the stored rules are kept (E3) and every row opens the Pro sheet.
    final locked = !ProScope.ownedOf(context);
    return Scaffold(
      appBar: SkTopBar(
        title: context.l10n.fieldRulesTitle,
        leading: SkIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final insets = skPageInsets(context, constraints.maxWidth);
          return ListView(
            padding: insets.copyWith(
              top: SkSpace.s,
              bottom: MediaQuery.paddingOf(context).bottom + SkSpace.xl,
            ),
            children: [
              Text(
                context.l10n.fieldRulesSummary,
                style: SkType.body.copyWith(color: c.textSecondary),
              ),
              if (locked) ...[
                const SizedBox(height: SkSpace.l),
                SkProLockedNote(text: context.l10n.proLockedFieldRules),
              ],
              const SizedBox(height: SkSpace.l),
              SkSection(
                children: [
                  for (final kind in FieldKind.values)
                    SkListRow(
                      title: fieldKindLabel(context.l10n, kind),
                      value: _nameOf(_rules[kind]),
                      chevron: true,
                      onTap: locked
                          ? () => showProSheet(context)
                          : () => _pick(kind),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The field kind's name as the list and the picker show it.
String fieldKindLabel(AppLocalizations l, FieldKind kind) => switch (kind) {
  FieldKind.search => l.fieldKindSearch,
  FieldKind.url => l.fieldKindUrl,
  FieldKind.email => l.fieldKindEmail,
  FieldKind.message => l.fieldKindMessage,
};
