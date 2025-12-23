import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

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
        toolbarHeight: 60, // Further increased height
        backgroundColor: navigationBarColor,
        surfaceTintColor: Colors.transparent,
        leadingWidth: showLogo ? 52 : 0,
        leading: showLogo 
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
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
                    height: 24, // Slightly larger logo
                    errorBuilder: (context, error, stackTrace) => HugeIcon(icon: HugeIcons.strokeRoundedAnalytics01, color: theme.colorScheme.primary),
                  ),
                ),
              )
            : const SizedBox.shrink(),
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16, // Even smaller font size
          ),
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedSettings03, color: Colors.grey),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 70, // Further reduced height
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 9, fontWeight: FontWeight.bold);
            }
            return const TextStyle(fontSize: 9);
          }),
        ),
        child: NavigationBar(
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
        destinations: [
          NavigationDestination(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedHome01, color: Colors.grey),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedHome01, color: theme.colorScheme.primary),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCalendarCheckIn01, color: Colors.grey),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedCalendarCheckIn01, color: theme.colorScheme.primary),
            label: 'برنامه‌ریزی',
          ),
          NavigationDestination(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedChartLineData01, color: Colors.grey),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedChartLineData01, color: theme.colorScheme.primary),
            label: 'گزارشات',
          ),
        ],
      ),
    ),
  );
}
}

