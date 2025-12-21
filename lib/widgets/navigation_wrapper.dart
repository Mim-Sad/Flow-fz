import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class NavigationWrapper extends StatelessWidget {
  final Widget child;

  const NavigationWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    int currentIndex = 0;
    String title = '';
    bool showLogo = true;

    if (location == '/') {
      currentIndex = 0;
      title = 'جریان';
      showLogo = true;
    } else if (location == '/planning') {
      currentIndex = 1;
      title = 'برنامه‌ریزی';
      showLogo = true;
    } else if (location == '/reports') {
      currentIndex = 2;
      title = 'گزارشات';
      showLogo = true;
    }

    final theme = Theme.of(context);
    final navigationBarColor = theme.brightness == Brightness.light
        ? ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          )
        : ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: navigationBarColor,
        surfaceTintColor: Colors.transparent,
        leadingWidth: showLogo ? 48 : 0,
        leading: showLogo 
            ? Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ColorFiltered(
                  colorFilter: theme.brightness == Brightness.light
                      ? const ColorFilter.matrix([
                          -1, 0, 0, 0, 255,
                          0, -1, 0, 0, 255,
                          0, 0, -1, 0, 255,
                          0, 0, 0, 1, 0,
                        ])
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: Image.asset(
                    'assets/images/flow-logo.png',
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.auto_graph),
                  ),
                ),
              )
            : const SizedBox.shrink(),
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/planning');
              break;
            case 2:
              context.go('/reports');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.house),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.calendarCheck),
            label: 'برنامه‌ریزی',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.chartLine),
            label: 'گزارشات',
          ),
        ],
      ),
    );
  }
}

