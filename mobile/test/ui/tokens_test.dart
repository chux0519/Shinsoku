import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/ui/theme.dart';
import 'package:shinsoku_mobile/ui/tokens.dart';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final c in [SkColors.dark, SkColors.light]) {
    group('DESIGN §2 contrast (${c.brightness.name})', () {
      for (final (name, bg) in [
        ('canvas', c.canvas),
        ('frame', c.frame),
        ('raised', c.raised),
      ]) {
        test('body text ≥ 4.5 on $name', () {
          expect(contrast(c.text, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.textSecondary, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.textTertiary, bg), greaterThanOrEqualTo(4.5));
        });
        test('status and accent ≥ 3 on $name', () {
          for (final s in [c.accent, c.success, c.warning, c.danger]) {
            expect(contrast(s, bg), greaterThanOrEqualTo(3));
          }
        });
      }
      test('text on accent ≥ 4.5', () {
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
      });
      test('text on accent-subtle ≥ 4.5', () {
        expect(contrast(c.text, c.accentSubtle), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('theme is built from tokens, not a seed', () {
    for (final b in Brightness.values) {
      final theme = buildSkTheme(b);
      final c = theme.extension<SkColors>()!;
      expect(theme.colorScheme.primary, c.accent);
      expect(theme.scaffoldBackgroundColor, c.canvas);
      expect(c.brightness, b);
    }
  });
}
