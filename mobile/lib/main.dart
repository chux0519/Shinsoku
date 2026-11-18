import 'package:flutter/material.dart';

import 'package:shinsoku_mobile/app/mobile_shell.dart';
import 'package:shinsoku_mobile/services/drafts.dart';

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
    const seed = Color(0xFF256D7B);

    return MaterialApp(
      title: 'Shinsoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: MobileShell(
        initialDrafts: initialDrafts,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}
