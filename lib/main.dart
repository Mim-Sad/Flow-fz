import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/planning_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/navigation_wrapper.dart';
import 'providers/theme_provider.dart';
import 'providers/task_provider.dart';
import 'services/midnight_task_updater.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FlowApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return NavigationWrapper(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/planning',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const PlanningScreen(),
          ),
        ),
        GoRoute(
          path: '/reports',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const ReportsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const SettingsScreen(),
      ),
    ),
  ],
);

class FlowApp extends ConsumerStatefulWidget {
  const FlowApp({super.key});

  @override
  ConsumerState<FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends ConsumerState<FlowApp> {
  @override
  void initState() {
    super.initState();
    // راه‌اندازی سرویس به‌روزرسانی نیمه‌شب
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMidnightUpdater();
    });
  }

  Future<void> _initializeMidnightUpdater() async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      await MidnightTaskUpdater().initialize(
        dbService,
        onUpdate: () {
          // به‌روزرسانی providers برای نمایش تغییرات در UI
          ref.invalidate(tasksProvider);
          ref.invalidate(allTasksIncludingDeletedProvider);
        },
      );
    } catch (e) {
      debugPrint('❌ خطا در راه‌اندازی MidnightTaskUpdater: $e');
    }
  }

  @override
  void dispose() {
    MidnightTaskUpdater().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    
    // With synchronous initialization, isInitialized should be true immediately.
    // But we keep the check just in case, though it shouldn't be needed if setup correctly.
    if (!themeState.isInitialized) {
      return const SizedBox.shrink(); // Render nothing instead of a scaffold if still initializing
    }

    return MaterialApp.router(
      title: 'Flow',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        PersianMaterialLocalizations.delegate,
        PersianCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      theme: AppTheme.getTheme(
        seedColor: themeState.seedColor,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.getTheme(
        seedColor: themeState.seedColor,
        brightness: Brightness.dark,
      ),
      themeMode: themeState.themeMode,
    );
  }
}
