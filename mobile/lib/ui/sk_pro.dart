import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';

import 'sk_button.dart';
import 'sk_sheet.dart';
import 'sk_status.dart';
import 'tokens.dart';

/// The small "Pro" mark on rows and pages that need Shinsoku Pro
/// (pricing-01). Accent-subtle pill, like [SkBadge].
class SkProBadge extends StatelessWidget {
  const SkProBadge({super.key});

  @override
  Widget build(BuildContext context) => SkBadge(
    key: const ValueKey('pro-badge'),
    label: context.l10n.proBadge,
    icon: Icons.lock_outline_rounded,
  );
}

/// Opens the Shinsoku Pro sheet. It reads the [ProScope] above the
/// navigator, so it updates live while a purchase runs.
Future<void> showProSheet(BuildContext context) async {
  final entitlement = ProScope.of(context);
  if (!entitlement.value.owned && entitlement.value.productPrice == null) {
    // The price may have failed to load at launch; try again.
    entitlement.refresh();
  }
  await showSkSheet<void>(
    context: context,
    builder: (context) => const SkProSheet(),
  );
  entitlement.clearNotice();
}

/// DESIGN §5 sheet for Shinsoku Pro: what it adds, the StoreKit price on the
/// Buy button, Restore Purchases, the one-time note, and the outcome of the
/// last action as a status line (M10: coded, never raw).
class SkProSheet extends StatelessWidget {
  const SkProSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final entitlement = ProScope.of(context);
    final state = entitlement.value;
    final l = context.l10n;
    final c = SkColors.of(context);
    final status = _status(l, state);
    final price = state.productPrice;
    final loadingPrice = price == null && state.busy;
    return SkSheet(
      title: l.proName,
      actions: [
        if (state.owned)
          SkButton(
            key: const ValueKey('pro-done'),
            label: l.commonDone,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop(),
          )
        else
          SkButton(
            key: const ValueKey('pro-buy'),
            label: price != null
                ? l.proBuyWithPrice(price)
                : loadingPrice
                ? l.proPriceLoading
                : l.proBuy,
            expand: true,
            busy: state.busy,
            onPressed: state.notice == ProNotice.pending
                ? null
                : entitlement.purchase,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Feature(
            icon: Icons.tune_rounded,
            title: l.proFeatureProfilesTitle,
            body: l.proFeatureProfilesBody,
          ),
          _Feature(
            icon: Icons.apps_rounded,
            title: l.proFeatureAutoTitle,
            body: l.proFeatureAutoBody,
          ),
          _Feature(
            icon: Icons.desktop_mac_outlined,
            title: l.proFeatureDesktopTitle,
            body: l.proFeatureDesktopBody,
          ),
          const SizedBox(height: SkSpace.s),
          if (status != null) ...[status, const SizedBox(height: SkSpace.m)],
          if (!state.owned) ...[
            Text(
              l.proNote,
              textAlign: TextAlign.center,
              style: SkType.secondary.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: SkSpace.xs),
            Center(
              child: SkButton.text(
                key: const ValueKey('pro-restore'),
                label: l.proRestore,
                onPressed: state.busy ? null : entitlement.restore,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget? _status(AppLocalizations l, ProState state) {
    if (state.owned) {
      return SkStatusLine(
        key: const ValueKey('pro-status'),
        icon: Icons.check_circle_outline_rounded,
        tone: SkTone.success,
        text: state.notice == ProNotice.restored
            ? l.proNoticeRestored
            : l.proOwned,
      );
    }
    final notice = state.notice;
    if (notice == null) return null;
    final (IconData icon, SkTone tone, String text) = switch (notice) {
      ProNotice.pending => (
        Icons.hourglass_empty_rounded,
        SkTone.warning,
        l.proNoticePending,
      ),
      ProNotice.cancelled => (
        Icons.info_outline_rounded,
        SkTone.neutral,
        l.proNoticeCancelled,
      ),
      ProNotice.failed => (
        Icons.error_outline_rounded,
        SkTone.danger,
        l.proNoticeFailed,
      ),
      ProNotice.unavailable => (
        Icons.cloud_off_rounded,
        SkTone.warning,
        l.proNoticeUnavailable,
      ),
      ProNotice.nothingToRestore => (
        Icons.info_outline_rounded,
        SkTone.neutral,
        l.proNoticeNothingToRestore,
      ),
      ProNotice.restored => (
        Icons.check_circle_outline_rounded,
        SkTone.success,
        l.proNoticeRestored,
      ),
    };
    return SkStatusLine(
      key: const ValueKey('pro-status'),
      icon: icon,
      tone: tone,
      text: text,
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SkSpace.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: c.accent),
            const SizedBox(width: SkSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SkType.title.copyWith(color: c.text)),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: SkType.secondary.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A locked page's explanation: the Pro badge, one line of why, and the
/// action that opens the Pro sheet.
class SkProLockedNote extends StatelessWidget {
  const SkProLockedNote({required this.text, this.action = true, super.key});

  final String text;

  /// Show the "Unlock Shinsoku Pro" text button (off when the page's primary
  /// button already opens the sheet).
  final bool action;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    return Column(
      key: const ValueKey('pro-locked-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkProBadge(),
        const SizedBox(height: SkSpace.s),
        Text(text, style: SkType.body.copyWith(color: c.text)),
        if (action)
          Transform.translate(
            offset: const Offset(-12, 0),
            child: SkButton.text(
              key: const ValueKey('pro-locked-unlock'),
              label: context.l10n.proBuy,
              onPressed: () => showProSheet(context),
            ),
          ),
      ],
    );
  }
}
