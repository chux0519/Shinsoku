import 'package:flutter/material.dart';

import 'package:shinsoku_mobile/app/mobile_shell.dart';
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
      debugShowCheckedModeBanner: false,
      // DESIGN.md §2: the theme follows the system; dark is the reference.
      themeMode: ThemeMode.system,
      theme: buildSkTheme(Brightness.light),
      darkTheme: buildSkTheme(Brightness.dark),
      home: MobileShell(
        initialDrafts: initialDrafts,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}
