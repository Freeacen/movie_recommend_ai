import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movie_recommend_ai/main.dart';
import 'package:movie_recommend_ai/core/database/app_database.dart';
import 'package:movie_recommend_ai/core/constants/app_colors.dart';
import 'package:movie_recommend_ai/presentation/providers/settings_provider.dart';
import 'package:movie_recommend_ai/presentation/screens/shell_screen.dart';
import 'package:movie_recommend_ai/presentation/widgets/floating_island_navigation_bar.dart';
import 'package:movie_recommend_ai/presentation/widgets/user_avatar_widget.dart';

void main() {
  testWidgets('App launches with ProviderScope and displays title', (WidgetTester tester) async {
    AppDatabase.initializeFfiIfNeeded();
    await tester.pumpWidget(
      const ProviderScope(
        child: MovieRecommendApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1600));
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

  testWidgets('FloatingIslandNavigationBar renders and navigates between tabs', (WidgetTester tester) async {
    AppDatabase.initializeFfiIfNeeded();
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MovieRecommendApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 1200));

    // Initially on Tab 0 (Chat)
    expect(container.read(shellNavigationProvider), 0);

    // Switch to Tab 1 (Profil)
    container.read(shellNavigationProvider.notifier).state = 1;
    await tester.pumpAndSettle(const Duration(milliseconds: 1200));

    expect(container.read(shellNavigationProvider), 1);
    expect(find.byType(FloatingIslandNavigationBar), findsOneWidget);
    expect(find.text('Profil'), findsWidgets);
    expect(find.text('Keşfet'), findsWidgets);

    // Switch to Tab 2 (Keşfet)
    container.read(shellNavigationProvider.notifier).state = 2;
    await tester.pumpAndSettle(const Duration(milliseconds: 1200));

    expect(container.read(shellNavigationProvider), 2);
    expect(find.text('Kütüphane'), findsWidgets);
  });

  testWidgets('UserAvatarWidget renders default icon and preset cinematic avatar', (WidgetTester tester) async {
    // 1. Default avatar
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatarWidget(
            avatarUrl: null,
            size: 60,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // 2. Cinematic preset avatar
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatarWidget(
            avatarUrl: 'avatar:popcorn',
            size: 60,
          ),
        ),
      ),
    );
    expect(find.text('🍿'), findsOneWidget);
  });

  test('SettingsNotifier updates avatar and username correctly', () async {
    final container = ProviderContainer();
    final notifier = container.read(settingsProvider.notifier);

    // Initial state
    expect(container.read(settingsProvider).effectiveDisplayName, 'Sinefil');

    // Update username
    await notifier.updateUserName('CineMaster');
    expect(container.read(settingsProvider).userName, 'CineMaster');
    expect(container.read(settingsProvider).effectiveDisplayName, 'CineMaster');

    // Update avatar with preset
    await notifier.updateAvatar('avatar:robot');
    expect(container.read(settingsProvider).avatarUrl, 'avatar:robot');

    // Clear/reset avatar
    await notifier.updateAvatar(null);
    expect(container.read(settingsProvider).avatarUrl, isNull);
  });
}
