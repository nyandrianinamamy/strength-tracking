import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShellScaffold extends StatefulWidget {
  const AppShellScaffold({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  @override
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  String _lastLocation = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.value = 1.0;
    _lastLocation = widget.currentLocation;
  }

  @override
  void didUpdateWidget(AppShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTab = _indexForLocation(widget.currentLocation);
    final oldTab = _indexForLocation(_lastLocation);
    if (newTab != oldTab) {
      _lastLocation = widget.currentLocation;
      _fadeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

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
    final selectedIndex = _indexForLocation(widget.currentLocation);

    final animatedChild = FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );

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
                    child: animatedChild,
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
            child: animatedChild,
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
