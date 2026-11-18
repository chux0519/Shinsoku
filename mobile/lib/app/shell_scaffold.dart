import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/features/common/widgets.dart';

/// App chrome around the tab bodies: a bottom bar on compact widths, a rail
/// on wide ones. Stateless, so host renders can wrap any screen in it.
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

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.mic_none),
        selectedIcon: Icon(Icons.mic),
        label: 'Record',
      ),
      NavigationDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description),
        label: 'Drafts',
      ),
      NavigationDestination(
        icon: Icon(Icons.wifi_tethering),
        selectedIcon: Icon(Icons.podcasts),
        label: 'Desktop',
      ),
      NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: tabIndex,
                    onDestinationSelected: onTabSelected,
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 18),
                      child: ShinsokuMark(),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.mic_none),
                        selectedIcon: Icon(Icons.mic),
                        label: Text('Record'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description),
                        label: Text('Drafts'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.wifi_tethering),
                        selectedIcon: Icon(Icons.podcasts),
                        label: Text('Desktop'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_outlined),
                        selectedIcon: Icon(Icons.tune),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(child: body),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tabIndex,
            onDestinationSelected: onTabSelected,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
