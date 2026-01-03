import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/notification_service.dart';
import '../providers/task_provider.dart';
import '../widgets/task_sheets.dart';
import '../models/task.dart';

class NavigationWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const NavigationWrapper({super.key, required this.child});

  @override
  ConsumerState<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends ConsumerState<NavigationWrapper> {
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = NotificationService().onNotificationClick
        .listen((payload) {
          if (payload != null) {
            _handleNotificationClick(payload);
          }
        });

    // Check for initial payload if app was launched from notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialPayload = NotificationService().consumeInitialPayload();
      if (initialPayload != null) {
        debugPrint('🔔 Handling initial notification payload: $initialPayload');
        _handleNotificationClick(initialPayload);
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleNotificationClick(String payload) async {
    final taskId = int.tryParse(payload);
    if (taskId == null) return;

    // Wait if tasks are still loading
    if (ref.read(tasksLoadingProvider)) {
      debugPrint(
        '⏳ Tasks still loading, waiting before handling notification...',
      );
      int attempts = 0;
      while (ref.read(tasksLoadingProvider) && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    // Use ref.read to get the current list of tasks
    final allTasks = ref.read(tasksProvider);
    final task = allTasks.cast<Task?>().firstWhere(
      (t) => t?.id == taskId,
      orElse: () => null,
    );

    if (task != null && mounted) {
      // If a bottom sheet is already open, close it first
      if (Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => TaskOptionsSheet(task: task, date: task.dueDate),
      );
    }
  }

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
      title = 'برنامه';
      showLogo = true;
    } else if (location == '/mood') {
      currentIndex = 2;
      title = 'مود';
      showLogo = true;
    } else if (location == '/reports') {
      currentIndex = 3;
      title = 'گزارش';
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
        centerTitle: true,
        leadingWidth: showLogo ? 52 : 0,
        leading: showLogo
            ? Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
                child: SvgPicture.asset(
                  'assets/images/flow-prm.svg',
                  height: 10,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                  placeholderBuilder: (context) => HugeIcon(
                    icon: HugeIcons.strokeRoundedLoading03,
                    color: theme.colorScheme.primary,
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
          if (location.startsWith('/search'))
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedHome01),
              onPressed: () => context.go('/'),
              tooltip: 'خانه',
            )
          else
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedSearch01),
              onPressed: () => context.push('/search'),
              tooltip: 'جستجو',
            ),
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedSettings03),
            onPressed: () => context.push('/settings'),
            tooltip: 'تنظیمات',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.child,
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
          backgroundColor: navigationBarColor,
          surfaceTintColor: Colors.transparent,
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
                context.go('/mood');
                break;
              case 3:
                context.go('/reports');
                break;
            }
          },
          destinations: [
            NavigationDestination(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedHome01),
              selectedIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedHome01,
                color: theme.colorScheme.primary,
              ),
              label: 'خانه',
            ),
            NavigationDestination(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCalendarCheckIn01,
              ),
              selectedIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedCalendarCheckIn01,
                color: theme.colorScheme.primary,
              ),
              label: 'برنامه',
            ),
            NavigationDestination(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedSmileDizzy),
              selectedIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSmileDizzy,
                color: theme.colorScheme.primary,
              ),
              label: 'مود',
            ),
            NavigationDestination(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedChartLineData01,
              ),
              selectedIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedChartLineData01,
                color: theme.colorScheme.primary,
              ),
              label: 'گزارش',
            ),
          ],
        ),
      ),
    );
  }
}
