import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movie_recommend_ai/main.dart';
import 'package:movie_recommend_ai/core/database/app_database.dart';
import 'package:movie_recommend_ai/core/constants/app_colors.dart';
import 'package:movie_recommend_ai/presentation/providers/settings_provider.dart';

void main() {
  testWidgets('App launches with ProviderScope and displays title', (WidgetTester tester) async {
    AppDatabase.initializeFfiIfNeeded();
    await tester.pumpWidget(
      const ProviderScope(
        child: MovieRecommendApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.byType(MovieRecommendApp), findsOneWidget);
  });

  testWidgets('Theme toggle switches dynamically between Dark and Light mode', (WidgetTester tester) async {
    AppDatabase.initializeFfiIfNeeded();
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MovieRecommendApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Initially in Dark Mode
    expect(container.read(settingsProvider).isDarkMode, isTrue);
    expect(AppColors.isDark, isTrue);
    MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    // Toggle theme to Light Mode
    container.read(settingsProvider.notifier).toggleTheme();
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(container.read(settingsProvider).isDarkMode, isFalse);
    expect(AppColors.isDark, isFalse);
    app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    // Verify Light Mode colors
    expect(AppColors.background, AppColors.lightBackground);
    expect(AppColors.surface, AppColors.lightSurface);
    expect(AppColors.textHigh, AppColors.lightTextHigh);

    // Toggle back to Dark Mode
    container.read(settingsProvider.notifier).toggleTheme();
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(container.read(settingsProvider).isDarkMode, isTrue);
    expect(AppColors.isDark, isTrue);
    app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(AppColors.background, AppColors.darkBackground);
  });
}
