import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/settings_provider.dart';
import '../screens/shell_screen.dart';

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellNavigationProvider);
    final settings = ref.watch(settingsProvider);

    return Drawer(
      backgroundColor: AppColors.surface,
      elevation: 16,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Drawer Header (Branding & Close)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 14, 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAmber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.movie_filter_rounded, color: AppColors.primaryAmber, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CineAI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHigh,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Akıllı Film Rehberi & AI',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textMedium, size: 22),
                    tooltip: 'Menüyü Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'SEKMELER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLow,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // 2. Navigation Items (Sekmeler)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildDrawerItem(
                    context: context,
                    ref: ref,
                    index: 0,
                    currentIndex: currentIndex,
                    icon: Icons.chat_bubble_rounded,
                    title: 'AI Sohbet',
                    subtitle: 'Yapay Zeka Film Danışmanı',
                  ),
                  _buildDrawerItem(
                    context: context,
                    ref: ref,
                    index: 1,
                    currentIndex: currentIndex,
                    icon: Icons.explore_rounded,
                    title: 'Keşfet & Ara',
                    subtitle: 'Trend & Popüler Film Kataloğu',
                  ),
                  _buildDrawerItem(
                    context: context,
                    ref: ref,
                    index: 2,
                    currentIndex: currentIndex,
                    icon: Icons.video_library_rounded,
                    title: 'Film Kütüphanem',
                    subtitle: 'İzlenenler & İzleme Listesi',
                  ),
                  _buildDrawerItem(
                    context: context,
                    ref: ref,
                    index: 3,
                    currentIndex: currentIndex,
                    icon: Icons.settings_rounded,
                    title: 'Ayarlar & Eşitleme',
                    subtitle: 'Bulut Yedekleme & Tercihler',
                  ),
                ],
              ),
            ),

            // 3. Footer (Fast Theme Toggle & Cloud Badge)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  // Fast Theme Toggle Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              size: 18,
                              color: AppColors.primaryAmber,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              settings.isDarkMode ? 'Karanlık Tema' : 'Aydınlık Tema',
                              style: TextStyle(fontSize: 12, color: AppColors.textHigh, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Switch(
                          value: settings.isDarkMode,
                          activeThumbColor: AppColors.primaryAmber,
                          onChanged: (_) => ref.read(settingsProvider.notifier).toggleTheme(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'CineAI v2.0 • Hibrit Mimari',
                    style: TextStyle(fontSize: 11, color: AppColors.textLow),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required WidgetRef ref,
    required int index,
    required int currentIndex,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = index == currentIndex;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryAmber.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primaryAmber.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryAmber.withValues(alpha: 0.22)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? AppColors.primaryAmber : AppColors.textMedium,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppColors.primaryAmber : AppColors.textHigh,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? AppColors.textHigh.withValues(alpha: 0.75) : AppColors.textLow,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryAmber,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          ref.read(shellNavigationProvider.notifier).state = index;
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
