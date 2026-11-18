// DESIGN.md §2–§4 as code. The only place in lib/ that spells out colours
// (review rule R03); everything else reads them through SkColors.of(context).
import 'package:flutter/material.dart';

/// DESIGN.md §2 colour tokens. Carried on the theme as an extension so every
/// widget reads the current (light or dark) set.
@immutable
class SkColors extends ThemeExtension<SkColors> {
  const SkColors({
    required this.brightness,
    required this.canvas,
    required this.frame,
    required this.raised,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.hairline,
    required this.border,
    required this.accent,
    required this.accentSubtle,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Brightness brightness;
  final Color canvas;
  final Color frame;
  final Color raised;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color hairline;
  final Color border;
  final Color accent;
  final Color accentSubtle;

  /// Text and icons on an accent fill: canvas (dark) / white (light).
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;

  /// Pressed / selected fill on neutral surfaces: text at 8 % (DESIGN §2).
  Color get pressed => text.withValues(alpha: 0.08);

  static const dark = SkColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF101314),
    frame: Color(0xFF161A1B),
    raised: Color(0xFF1D2224),
    text: Color(0xFFE3E9EA),
    textSecondary: Color(0xFFAEB9BB),
    textTertiary: Color(0xFF848E90),
    hairline: Color.fromRGBO(227, 233, 234, 0.08),
    border: Color(0xFF2E3739),
    accent: Color(0xFF6CC3CF),
    accentSubtle: Color(0xFF23464C),
    onAccent: Color(0xFF101314),
    success: Color(0xFFA6D189),
    warning: Color(0xFFE5C890),
    danger: Color(0xFFE78284),
  );

  static const light = SkColors(
    brightness: Brightness.light,
    canvas: Color(0xFFF7F8F8),
    frame: Color(0xFFEEF1F1),
    raised: Color(0xFFFFFFFF),
    text: Color(0xFF1C2426),
    textSecondary: Color(0xFF4A5659),
    textTertiary: Color(0xFF5F6A6D),
    hairline: Color.fromRGBO(28, 36, 38, 0.12),
    border: Color(0xFFD5DBDC),
    accent: Color(0xFF1F6470),
    accentSubtle: Color(0xFFD6ECEF),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF4F7A1F),
    warning: Color(0xFF8A6400),
    danger: Color(0xFFB3261E),
  );

  static SkColors of(BuildContext context) =>
      Theme.of(context).extension<SkColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// Status colour for a tone; neutral falls back to secondary text.
  Color tone(SkTone tone) => switch (tone) {
    SkTone.neutral => textSecondary,
    SkTone.accent => accent,
    SkTone.success => success,
    SkTone.warning => warning,
    SkTone.danger => danger,
  };

  @override
  SkColors copyWith() => this;

  @override
  SkColors lerp(ThemeExtension<SkColors>? other, double t) =>
      t < 0.5 || other is! SkColors ? this : other;
}

/// Meaning of a status colour. Always shown with text or an icon (DESIGN §2).
enum SkTone { neutral, accent, success, warning, danger }

/// DESIGN.md §3 type scale. No font family: the platform default is SF Pro.
abstract final class SkType {
  static const pageTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.33,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const secondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.38,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
  );
  static const sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    height: 1.3,
  );
  static const transcript = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Pairing codes and fingerprints. Menlo is on every iOS device; the
  /// fallback keeps other hosts monospaced.
  static const mono = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: ['Courier', 'monospace'],
  );
}

/// DESIGN.md §3 spacing scale.
abstract final class SkSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;

  /// Screen margin: 16, or 20 on widths ≥ 600.
  static double margin(double width) => width >= 600 ? 20 : 16;
}

/// DESIGN.md §3 radii, hairline and touch target.
abstract final class SkShape {
  static const double control = 10;
  static const double card = 14;
  static const double sheet = 28;
  static const double pill = 999;
  static const double hairline = 0.5;
  static const double minTarget = 44;
}

/// DESIGN.md §4 motion: 150–250 ms, nothing when Reduce Motion is on.
abstract final class SkMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);
  static const enter = Curves.easeOut;
  static const exit = Curves.easeIn;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [base], or zero under Reduce Motion.
  static Duration of(BuildContext context, [Duration base = normal]) =>
      reduced(context) ? Duration.zero : base;
}
