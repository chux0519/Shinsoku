// ThemeData built from DESIGN.md tokens (no seeded ColorScheme). The few
// Material widgets that remain (snack bars, dialogs, text selection) pick up
// these colours; Sk* components read SkColors directly.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildSkTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? SkColors.dark : SkColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.accentSubtle,
    onPrimaryContainer: c.text,
    secondary: c.accent,
    onSecondary: c.onAccent,
    secondaryContainer: c.accentSubtle,
    onSecondaryContainer: c.text,
    tertiary: c.accent,
    onTertiary: c.onAccent,
    error: c.danger,
    onError: c.onAccent,
    errorContainer: c.raised,
    onErrorContainer: c.danger,
    surface: c.canvas,
    onSurface: c.text,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.canvas,
    surfaceContainerLow: c.frame,
    surfaceContainer: c.frame,
    surfaceContainerHigh: c.raised,
    surfaceContainerHighest: c.raised,
    surfaceTint: Colors.transparent,
    outline: c.border,
    outlineVariant: c.border,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: c.text,
    onInverseSurface: c.canvas,
    inversePrimary: c.accentSubtle,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );
  final textTheme = base.textTheme.copyWith(
    titleLarge: SkType.pageTitle,
    titleMedium: SkType.title,
    titleSmall: SkType.title,
    bodyLarge: SkType.transcript,
    bodyMedium: SkType.body,
    bodySmall: SkType.secondary,
    labelLarge: SkType.title,
    labelMedium: SkType.secondary,
    labelSmall: SkType.caption,
  );

  return base.copyWith(
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    dividerColor: c.hairline,
    splashFactory: NoSplash.splashFactory,
    highlightColor: c.pressed,
    hoverColor: c.pressed,
    focusColor: c.accentSubtle,
    textTheme: textTheme.apply(bodyColor: c.text, displayColor: c.text),
    iconTheme: IconThemeData(color: c.textSecondary, size: 22),
    dividerTheme: DividerThemeData(
      color: c.hairline,
      thickness: SkShape.hairline,
      space: SkShape.hairline,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.3),
      selectionHandleColor: c.accent,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: c.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: SkType.body.copyWith(color: c.canvas),
      actionTextColor: c.canvas,
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(SkShape.control)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.raised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(SkShape.card)),
      ),
      titleTextStyle: SkType.pageTitle.copyWith(color: c.text),
      contentTextStyle: SkType.body.copyWith(color: c.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.raised,
      modalBackgroundColor: c.raised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SkShape.sheet),
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.frame,
      circularTrackColor: Colors.transparent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.text,
        borderRadius: BorderRadius.circular(SkShape.control),
      ),
      textStyle: SkType.secondary.copyWith(color: c.canvas),
    ),
    extensions: [c],
  );
}
