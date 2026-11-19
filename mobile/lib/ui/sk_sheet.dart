import 'package:flutter/material.dart';

import 'sk_button.dart';
import 'tokens.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';

/// DESIGN §5 sheet: raised surface, top radius 28, a grabber, a title, and the
/// only shadow DESIGN allows (floating sheets). Content scrolls and stays above
/// the keyboard.
class SkSheet extends StatelessWidget {
  const SkSheet({
    required this.child,
    this.title,
    this.actions = const [],
    super.key,
  });

  final String? title;
  final Widget child;

  /// Bottom actions, primary last (thumb reach).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final margin = SkSpace.margin(width);
    final insets = MediaQuery.viewInsetsOf(context);
    final safe = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: SkSpace.s),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: c.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(SkShape.pill),
              ),
            ),
          ),
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                margin,
                SkSpace.m,
                margin,
                SkSpace.s,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: SkType.pageTitle.copyWith(color: c.text),
                ),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                margin + safe.left,
                SkSpace.s,
                margin + safe.right,
                SkSpace.l,
              ),
              child: child,
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                margin + safe.left,
                0,
                margin + safe.right,
                SkSpace.l + (insets.bottom > 0 ? 0 : safe.bottom),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: SkSpace.m),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows [builder]'s [SkSheet] as a modal bottom sheet.
Future<T?> showSkSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final c = SkColors.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.raised,
    elevation: 8,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(SkShape.sheet)),
    ),
    builder: builder,
  );
}

/// A confirmation sheet; resolves to true only on [confirmLabel].
Future<bool> showSkConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showSkSheet<bool>(
    context: context,
    builder: (context) => SkSheet(
      title: title,
      actions: [
        SkButton.secondary(
          label: context.l10n.commonCancel,
          expand: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SkButton(
          label: confirmLabel,
          expand: true,
          destructive: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      child: Text(
        message,
        style: SkType.body.copyWith(color: SkColors.of(context).textSecondary),
      ),
    ),
  );
  return result ?? false;
}
