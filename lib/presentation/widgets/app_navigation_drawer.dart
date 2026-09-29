import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/settings_provider.dart';
import '../screens/shell_screen.dart';
import 'user_avatar_widget.dart';

class AppNavigationDrawer extends StatelessWidget {
  final ValueChanged<int>? onTabSelected;
  final Animation<double>? itemAnimation;

  const AppNavigationDrawer({
    super.key,
    this.onTabSelected,
    this.itemAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 600
        ? 265.0
        : (screenWidth * 0.76).clamp(240.0, 275.0);

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 0, 16),
          child: AppNavigationDrawerContent(
            onTabSelected: onTabSelected,
            itemAnimation: itemAnimation,
          ),
        ),
      ),
    );
  }
}

class AppNavigationDrawerContent extends ConsumerWidget {
  final VoidCallback? onClose;
  final ValueChanged<int>? onTabSelected;
  final Animation<double>? itemAnimation;

  const AppNavigationDrawerContent({
    super.key,
    this.onClose,
    this.onTabSelected,
    this.itemAnimation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellNavigationProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = AppColors.isDark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            // High-transparency Apple Frosted Glass (Buzlu Cam)
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0x38FFFFFF), // 22% white specular top highlight
                      const Color(0x33222C3E), // 20% translucent slate glass body
                      const Color(0x38121622), // 22% translucent deep smoke
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.65),
                      Colors.white.withValues(alpha: 0.40),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.65),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(4, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (CineAI + Cyan Circular Close Button)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CineAI',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2997FF),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (onClose != null) {
                            onClose!();
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2997FF).withValues(alpha: 0.15),
                            border: Border.all(
                              color: const Color(0xFF2997FF),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF2997FF),
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // 2. Navigation Items (Sade, temiz ve kullanıcının istediği sırada)
              Expanded(
                child: AnimatedBuilder(
                  animation: itemAnimation ?? kAlwaysCompleteAnimation,
                  builder: (context, child) {
                    final animVal = (itemAnimation ?? kAlwaysCompleteAnimation).value;
                    const intervals = [
                      Interval(0.00, 0.60, curve: Curves.easeOutCubic),
                      Interval(0.10, 0.70, curve: Curves.easeOutCubic),
                      Interval(0.20, 0.80, curve: Curves.easeOutCubic),
                      Interval(0.30, 0.90, curve: Curves.easeOutCubic),
                      Interval(0.40, 1.00, curve: Curves.easeOutCubic),
                    ];

                    double getProgress(int idx) {
                      if (itemAnimation == null || animVal >= 1.0) return 1.0;
                      return intervals[idx.clamp(0, intervals.length - 1)].transform(animVal);
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        // Tab 0: AI Sohbet
                        _buildNavItem(
                          context: context,
                          ref: ref,
                          icon: Icons.chat_bubble_rounded,
                          title: 'AI Sohbet',
                          isSelected: currentIndex == 0,
                          onTap: () => _handleTabTap(context, ref, 0),
                          progress: getProgress(0),
                        ),
                        const SizedBox(height: 4),

                        // Tab 1: Profil (Sürekli 2. sırada)
                        _buildNavItem(
                          context: context,
                          ref: ref,
                          icon: Icons.person_rounded,
                          title: 'Profil',
                          isSelected: currentIndex == 1,
                          onTap: () => _handleTabTap(context, ref, 1),
                          progress: getProgress(1),
                        ),
                        const SizedBox(height: 4),

                        // Tab 2: Keşfet (Sadece 'Keşfet')
                        _buildNavItem(
                          context: context,
                          ref: ref,
                          icon: Icons.explore_rounded,
                          title: 'Keşfet',
                          isSelected: currentIndex == 2,
                          onTap: () => _handleTabTap(context, ref, 2),
                          progress: getProgress(2),
                        ),
                        const SizedBox(height: 4),

                        // Tab 3: Kütüphane (Sadece 'Kütüphane')
                        _buildNavItem(
                          context: context,
                          ref: ref,
                          icon: Icons.video_library_rounded,
                          title: 'Kütüphane',
                          isSelected: currentIndex == 3,
                          onTap: () => _handleTabTap(context, ref, 3),
                          progress: getProgress(3),
                        ),
                        const SizedBox(height: 4),

                        // Tab 4: Ayarlar (Her zaman son sırada)
                        _buildNavItem(
                          context: context,
                          ref: ref,
                          icon: Icons.settings_rounded,
                          title: 'Ayarlar',
                          isSelected: currentIndex == 4,
                          onTap: () => _handleTabTap(context, ref, 4),
                          progress: getProgress(4),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // 3. Footer Divider
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.1),
                  height: 1,
                  thickness: 0.8,
                ),
              ),

              // 4. Footer Section: Sadece Profil Detayı (Ayarlar butonu yukarıda olduğu için kaldırıldı)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleTabTap(context, ref, 1), // Doğrudan Profil sekmesine gider
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        children: [
                          UserAvatarWidget(
                            avatarUrl: settings.avatarUrl,
                            size: 38,
                            defaultGradient: const [
                              Color(0xFF2997FF),
                              Color(0xFF007AFF),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  settings.effectiveDisplayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppColors.textHigh,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  settings.isLoggedIn
                                      ? (settings.userEmail ?? 'Bağlı Hesap')
                                      : 'Film Tutkunu • v2.0',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textMedium,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTabTap(BuildContext context, WidgetRef ref, int index) {
    if (onTabSelected != null) {
      onTabSelected!(index);
    } else {
      ref.read(shellNavigationProvider.notifier).state = index;
    }

    if (onClose != null) {
      onClose!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildNavItem({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required double progress,
  }) {
    final slideY = (1.0 - progress) * 50.0;
    final opacity = (progress * progress).clamp(0.0, 1.0);
    final isDark = AppColors.isDark;

    return Transform.translate(
      offset: Offset(0, slideY),
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF007AFF) // Solid Apple Blue
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textHigh),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.92)
                                : AppColors.textHigh),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
