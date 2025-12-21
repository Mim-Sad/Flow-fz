import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/planning_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/navigation_wrapper.dart';
import 'providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: FlowApp(),
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
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/planning',
          builder: (context, state) => const PlanningScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class FlowApp extends ConsumerWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Flow',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeState.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'IRANSansX',
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeState.seedColor,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w900, fontSize: 32),
          displayMedium: TextStyle(fontWeight: FontWeight.w800, fontSize: 28),
          displaySmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
          headlineLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
          headlineMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          titleMedium: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
          labelLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'IRANSansX',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'IRANSansX',
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeState.seedColor,
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'IRANSansX',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

