import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';

import 'package:shinsoku_mobile/app/mobile_shell.dart';
import 'package:shinsoku_mobile/platform/division_regions.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/ui/theme.dart';

void main() {
  runApp(const ShinsokuMobileApp());
}

class ShinsokuMobileApp extends StatelessWidget {
  const ShinsokuMobileApp({
    this.initialDrafts = const [],
    this.initialTabIndex = 0,
    super.key,
  });

  final List<DraftEntry> initialDrafts;
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shinsoku',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: appSupportedLocales,
      debugShowCheckedModeBanner: false,
      // DESIGN.md §2: the theme follows the system; dark is the reference.
      themeMode: ThemeMode.system,
      theme: buildSkTheme(Brightness.light),
      darkTheme: buildSkTheme(Brightness.dark),
      // iPhone Duo fold → MediaQuery.displayFeatures for every route.
      builder: (context, child) => DivisionRegions(child: child!),
      home: MobileShell(
        initialDrafts: initialDrafts,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}
