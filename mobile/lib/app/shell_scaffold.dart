import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// App chrome around the tab bodies: a bottom tab bar on compact widths, a
/// side bar on wide ones. Stateless, so host renders can wrap any screen in
/// it. (The iPhone Duo two-pane layout is U4.)
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({
    required this.tabIndex,
    required this.onTabSelected,
    required this.body,
    super.key,
  });

  final int tabIndex;
  final ValueChanged<int> onTabSelected;
  final Widget body;

  static const tabs = [
    SkTabItem(icon: Icons.mic_none, selectedIcon: Icons.mic, label: 'Record'),
    SkTabItem(
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      label: 'Drafts',
    ),
    SkTabItem(
      icon: Icons.wifi_tethering,
      selectedIcon: Icons.podcasts,
      label: 'Desktop',
    ),
    SkTabItem(
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Scaffold(
            body: Row(
              children: [
                SkTabBar(
                  items: tabs,
                  selectedIndex: tabIndex,
                  onSelected: onTabSelected,
                  vertical: true,
                ),
                Expanded(child: SafeArea(left: false, child: body)),
              ],
            ),
          );
        }
        return Scaffold(
          body: SafeArea(child: body),
          bottomNavigationBar: SkTabBar(
            items: tabs,
            selectedIndex: tabIndex,
            onSelected: onTabSelected,
          ),
        );
      },
    );
  }
}
