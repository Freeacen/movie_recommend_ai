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
    final isDarkMode = ref.watch(settingsProvider).isDarkMode;
    AppColors.isDark = isDarkMode;

    return MaterialApp(
      title: 'CineAI - Movie Tracker & AI Recommendations',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const ShellScreen(),
    );
  }
}
