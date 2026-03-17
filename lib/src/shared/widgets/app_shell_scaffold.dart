import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  static final _destinations =
      <({String label, IconData icon, IconData selectedIcon, String path})>[
    (label: 'Dashboard', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, path: '/'),
    (label: 'Routines', icon: Icons.fitness_center_outlined, selectedIcon: Icons.fitness_center_rounded, path: '/routines'),
    (label: 'Exercises', icon: Icons.list_alt_outlined, selectedIcon: Icons.list_alt_rounded, path: '/exercises'),
    (label: 'Progress', icon: Icons.insights_outlined, selectedIcon: Icons.insights_rounded, path: '/progress'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final selectedIndex = _indexForLocation(currentLocation);

    if (width >= 1000) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                minWidth: 88,
                selectedIndex: selectedIndex,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (index) {
                  context.go(_destinations[index].path);
                },
                destinations: _destinations
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label.toUpperCase()),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          context.go(_destinations[index].path);
        },
        destinations: _destinations
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label.toUpperCase(),
              ),
            )
            .toList(),
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/routines')) {
      return 1;
    }
    if (location.startsWith('/exercises')) {
      return 2;
    }
    if (location.startsWith('/progress')) {
      return 3;
    }
    return 0;
  }
}
