import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Desktop (Windows, macOS, Linux)
  AppDatabase.initializeFfiIfNeeded();

  runApp(
    const ProviderScope(
      child: MovieRecommendApp(),
    ),
  );
}

class MovieRecommendApp extends ConsumerWidget {
  const MovieRecommendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = settings.isDarkMode;
    AppColors.isDark = isDarkMode;

    final baseLightTheme = AppTheme.lightTheme;
    final baseDarkTheme = AppTheme.darkTheme;

    final lightTheme = settings.isAnimationsEnabled
        ? baseLightTheme
        : baseLightTheme.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
              },
            ),
          );

    final darkTheme = settings.isAnimationsEnabled
        ? baseDarkTheme
        : baseDarkTheme.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
                TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
              },
            ),
          );

    return MaterialApp(
      title: 'CineAI - Movie Tracker & AI Recommendations',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const ShellScreen(),
    );
  }
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
