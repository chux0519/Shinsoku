// i18n-01 I3: defaults for a new install from the device's languages and
// region. Pure Dart (no storage, no plugins); applied once on first launch by
// `RegionDefaultsStore` (invariants R1–R3, docs/design/state_invariants.md).
//
// Provider coverage was checked 2026-11-19 (sources in
// docs/iterations/i18n-01/round-01/I3-implementation.md):
// * Fun-ASR realtime (`fun-asr-realtime`): `language_hints` in run-task
//   parameters, one value (only the first counts); Chinese incl. Cantonese and
//   other dialects is `zh`.
// * Soniox: `language_hints`, a list of ISO 639-1 codes that biases (does not
//   restrict) recognition.
import 'dart:ui' show Locale;

const speechProviderBailian = 'bailian';
const speechProviderSoniox = 'soniox';

/// `fun-asr-realtime` language_hints values (Model Studio, run-task).
const funAsrRealtimeLanguages = {
  'zh', 'en', 'ja', 'ko', 'vi', 'th', 'id', 'ms', 'tl', 'hi', //
  'ar', 'fr', 'de', 'es', 'pt', 'ru', 'it', 'nl', 'sv', 'da', //
  'fi', 'no', 'el', 'pl', 'cs', 'hu', 'ro', 'bg', 'hr', 'sk', //
};

/// Soniox language_hints values (supported-languages page).
const sonioxLanguages = {
  'af', 'sq', 'ar', 'az', 'eu', 'be', 'bn', 'bs', 'bg', 'ca', 'zh', 'hr', //
  'cs', 'da', 'nl', 'en', 'et', 'fi', 'fr', 'gl', 'de', 'el', 'gu', 'he', //
  'hi', 'hu', 'id', 'it', 'ja', 'kn', 'kk', 'ko', 'lv', 'lt', 'mk', 'ms', //
  'ml', 'mr', 'no', 'fa', 'pl', 'pt', 'pa', 'ro', 'ru', 'sr', 'sk', 'sl', //
  'es', 'sw', 'sv', 'tl', 'ta', 'te', 'th', 'tr', 'uk', 'ur', 'vi', 'cy', //
};

/// Source languages that have their own built-in translation profile
/// ("JA -> EN"); any other non-English language gets the generic
/// "Translate -> EN" profile. `zh` keeps the historic `zh_to_en` id.
const translationSourceLanguages = {
  'zh',
  'ja',
  'ko',
  'de',
  'es',
  'fr',
  'pt',
  'it',
};

/// Built-in profile ids for translation into English.
const zhToEnProfileId = 'zh_to_en';
const translateToEnProfileId = 'translate_to_en';

/// What a new install starts with.
class RegionDefaults {
  const RegionDefaults({
    required this.speechProvider,
    required this.sonioxLanguageHints,
    required this.bailianLanguageHint,
    required this.translationSource,
  });

  /// `bailian` (Fun-ASR realtime) or `soniox`.
  final String speechProvider;

  /// Soniox `language_hints` (bias, several allowed). Empty = auto.
  final List<String> sonioxLanguageHints;

  /// Fun-ASR `language_hints` (one value). Empty = auto-detect.
  final String bailianLanguageHint;

  /// Source language of the built-in translation profile: a code from
  /// [translationSourceLanguages], or null for the generic "Translate -> EN"
  /// (English devices and languages without their own profile).
  final String? translationSource;

  /// Id of the built-in translation profile.
  String get translationProfileId =>
      translationSource == 'zh' ? zhToEnProfileId : translateToEnProfileId;

  @override
  bool operator ==(Object other) =>
      other is RegionDefaults &&
      other.speechProvider == speechProvider &&
      other.sonioxLanguageHints.join(',') == sonioxLanguageHints.join(',') &&
      other.bailianLanguageHint == bailianLanguageHint &&
      other.translationSource == translationSource;

  @override
  int get hashCode => Object.hash(
    speechProvider,
    sonioxLanguageHints.join(','),
    bailianLanguageHint,
    translationSource,
  );

  @override
  String toString() =>
      'RegionDefaults($speechProvider, soniox=$sonioxLanguageHints, '
      'bailian="$bailianLanguageHint", translate=$translationSource)';
}

/// The ISO 639-1 language of [locale] as the providers name it: Cantonese
/// (`yue`) is Chinese (`zh`) for both; Norwegian Bokmål/Nynorsk are `no`;
/// Filipino is `tl`; Hebrew's old code `iw` is `he`.
String speechLanguageOf(Locale locale) {
  final code = locale.languageCode.toLowerCase();
  return switch (code) {
    'yue' || 'cmn' => 'zh',
    'nb' || 'nn' => 'no',
    'fil' => 'tl',
    'iw' => 'he',
    'in' => 'id',
    _ => code,
  };
}

/// Whether [locale] is Chinese speech: any script (Hans/Hant), Cantonese, any
/// region (CN, HK, MO, TW, SG, MY, …). `en-HK` or `en-SG` is not: the device
/// language decides, not the region.
bool isChineseLocale(Locale locale) => speechLanguageOf(locale) == 'zh';

/// Defaults for a device whose preferred languages are [locales] (first =
/// primary, as `PlatformDispatcher.locales`).
RegionDefaults regionDefaultsFor(List<Locale> locales) {
  if (locales.isEmpty) {
    return const RegionDefaults(
      speechProvider: speechProviderSoniox,
      sonioxLanguageHints: ['en'],
      bailianLanguageHint: '',
      translationSource: null,
    );
  }
  final primary = locales.first;
  final primaryLanguage = speechLanguageOf(primary);
  final chinese = isChineseLocale(primary);

  // Soniox: the first two preferred languages it knows, then English (most
  // users mix in English words). Hints only bias, so extra ones are cheap.
  final soniox = <String>[];
  for (final locale in locales) {
    final language = speechLanguageOf(locale);
    if (soniox.length < 2 &&
        sonioxLanguages.contains(language) &&
        !soniox.contains(language)) {
      soniox.add(language);
    }
  }
  if (!soniox.contains('en')) {
    soniox.add('en');
  }

  // Fun-ASR takes one hint and treats it as the audio's language. Only
  // Chinese devices default to it; elsewhere auto-detect is safer (a user who
  // switches to Bailian may well speak something other than the UI language).
  final bailian = chinese ? 'zh' : '';

  return RegionDefaults(
    speechProvider: chinese ? speechProviderBailian : speechProviderSoniox,
    sonioxLanguageHints: List.unmodifiable(soniox),
    bailianLanguageHint: bailian,
    translationSource: translationSourceLanguages.contains(primaryLanguage)
        ? primaryLanguage
        : null,
  );
}
