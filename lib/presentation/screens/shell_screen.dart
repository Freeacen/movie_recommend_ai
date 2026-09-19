import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tmdb_provider.dart';
import '../widgets/app_navigation_drawer.dart';
import 'chat/chat_screen.dart';
import 'discover/discover_screen.dart';
import 'library/library_screen.dart';
import 'settings/settings_screen.dart';

final shellNavigationProvider = StateProvider<int>((ref) => 0);
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  static const List<Widget> _screens = [
    ChatScreen(),
    DiscoverScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellNavigationProvider);

    return Scaffold(
      key: shellScaffoldKey,
      drawer: const AppNavigationDrawer(),
      appBar: _buildShellAppBar(context, ref, currentIndex),
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
    );
  }

  PreferredSizeWidget _buildShellAppBar(BuildContext context, WidgetRef ref, int currentIndex) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        children: [
          // 1. Menü Sembolü (En solda, minimalist - arka kutu yok)
          IconButton(
            onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: AppColors.primaryAmber, size: 24),
            tooltip: 'Menü',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),

          // 2. CineAI Logo ve Yazısı
          InkWell(
            onTap: () => shellScaffoldKey.currentState?.openDrawer(),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAmber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.movie_filter_rounded, color: AppColors.primaryAmber, size: 22),
                ),
                const SizedBox(width: 8),
                Text(
                  'CineAI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHigh,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),
          Container(
            height: 18,
            width: 1,
            color: AppColors.border,
          ),
          const SizedBox(width: 12),

          // Active Page Title
          Expanded(
            child: Text(
              _getScreenTitle(currentIndex),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        _buildScreenAction(context, ref, currentIndex),
        const SizedBox(width: 8),
      ],
    );
  }

  String _getScreenTitle(int index) {
    switch (index) {
      case 0:
        return 'AI Sohbet & Öneri';
      case 1:
        return 'Keşfet & Ara';
      case 2:
        return 'Film Kütüphanem';
      case 3:
        return 'Ayarlar & Eşitleme';
      default:
        return '';
    }
  }

  Widget _buildScreenAction(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0:
        return IconButton(
          tooltip: 'Sohbeti Temizle',
          icon: Icon(Icons.refresh_rounded, color: AppColors.textMedium),
          onPressed: () => ref.read(chatProvider.notifier).clearHistory(),
        );
      case 1:
        return IconButton(
          tooltip: 'Trendleri Yenile',
          icon: Icon(Icons.refresh_rounded, color: AppColors.textMedium),
          onPressed: () => ref.read(tmdbProvider.notifier).fetchTrending(),
        );
      case 2:
        return IconButton(
          tooltip: 'Kütüphaneyi Yenile',
          icon: Icon(Icons.refresh_rounded, color: AppColors.textMedium),
          onPressed: () => ref.read(libraryProvider.notifier).loadLibrary(),
        );
      case 3:
        return IconButton(
          tooltip: 'Bulut Eşitle',
          icon: const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryAmber),
          onPressed: () async {
            await ref.read(settingsProvider.notifier).triggerSync();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bulut senkronizasyonu tamamlandı! ☁️')),
              );
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
