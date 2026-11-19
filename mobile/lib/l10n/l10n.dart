import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// The pseudo-locale (accented, longer text) exists for tests and host
/// renders only; the app never offers it.
const pseudoLocale = Locale('en', 'XA');

/// Languages the app ships: the generated list without the pseudo-locale.
final List<Locale> appSupportedLocales = [
  for (final locale in AppLocalizations.supportedLocales)
    if (locale != pseudoLocale) locale,
];

/// The ten languages of i18n-01, in rollout order. Each has an
/// `app_<tag>.arb` (`zh_Hans`, `zh_Hant`, `pt_BR`); `app_zh.arb` and
/// `app_pt.arb` are the plain-language fallbacks gen-l10n needs (copies of
/// zh-Hans and pt-BR).
const plannedLocaleTags = [
  'en',
  'ja',
  'zh-Hant',
  'ko',
  'de',
  'es',
  'zh-Hans',
  'fr',
  'pt-BR',
  'it',
];

/// The strings for the system language, for code that has no [BuildContext]
/// (creating the built-in profiles on first launch).
Future<AppLocalizations> systemAppLocalizations() {
  final locale = basicLocaleListResolution(
    ui.PlatformDispatcher.instance.locales,
    appSupportedLocales,
  );
  return AppLocalizations.delegate.load(locale);
}

/// `context.l10n.recordStatusReady`: the strings in `lib/l10n/app_en.arb`.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
