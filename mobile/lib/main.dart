import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';

import 'package:shinsoku_mobile/app/mobile_shell.dart';
import 'package:shinsoku_mobile/platform/division_regions.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';
import 'package:shinsoku_mobile/ui/theme.dart';

void main() {
  runApp(const ShinsokuMobileApp());
}

class ShinsokuMobileApp extends StatefulWidget {
  const ShinsokuMobileApp({
    this.initialDrafts = const [],
    this.initialTabIndex = 0,
    this.proEntitlement,
    super.key,
  });

  final List<DraftEntry> initialDrafts;
  final int initialTabIndex;

  /// Shinsoku Pro; null → the StoreKit channel (or the DEBUG fixture).
  final ProEntitlement? proEntitlement;

  @override
  State<ShinsokuMobileApp> createState() => _ShinsokuMobileAppState();
}

class _ShinsokuMobileAppState extends State<ShinsokuMobileApp> {
  /// Owned here when not passed in.
  ProEntitlement? _ownEntitlement;

  ProEntitlement get _entitlement =>
      widget.proEntitlement ?? (_ownEntitlement ??= ChannelProEntitlement());

  @override
  void initState() {
    super.initState();
    if (kDebugMode && widget.proEntitlement == null) {
      unawaited(_loadProFixture());
    }
  }

  /// DEBUG: `-ShinsokuSceneProFixture owned|locked` replaces the store.
  Future<void> _loadProFixture() async {
    final fixture = await debugProFixtureFromLaunchArgument();
    if (fixture == null || !mounted) return;
    debugPrint('SHINSOKU_PRO_FIXTURE owned=${fixture.value.owned}');
    final previous = _ownEntitlement;
    setState(() => _ownEntitlement = fixture);
    previous?.dispose();
  }

  @override
  void dispose() {
    _ownEntitlement?.dispose();
    super.dispose();
  }

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
      // Shinsoku Pro above the navigator: pages, pushed routes and sheets
      // share one state (pricing-01, E4).
      builder: (context, child) => ProScope(
        entitlement: _entitlement,
        child: DivisionRegions(child: child!),
      ),
      home: MobileShell(
        initialDrafts: widget.initialDrafts,
        initialTabIndex: widget.initialTabIndex,
      ),
    );
  }
}
