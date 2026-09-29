import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

class NavItemData {
  final IconData icon;
  final String label;

  const NavItemData({
    required this.icon,
    required this.label,
  });
}

class FloatingIslandNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final double iconOpacity;
  final Offset iconOffset;
  final bool isAnimationsEnabled;

  static const List<NavItemData> items = [
    NavItemData(icon: Icons.chat_bubble_rounded, label: 'AI Sohbet'),
    NavItemData(icon: Icons.person_rounded, label: 'Profil'),
    NavItemData(icon: Icons.explore_rounded, label: 'Keşfet'),
    NavItemData(icon: Icons.video_library_rounded, label: 'Kütüphane'),
    NavItemData(icon: Icons.settings_rounded, label: 'Ayarlar'),
  ];

  const FloatingIslandNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.iconOpacity = 1.0,
    this.iconOffset = Offset.zero,
    this.isAnimationsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dockWidth = (screenWidth - 24).clamp(280.0, 460.0);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Container(
          width: dockWidth,
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(37),
            boxShadow: [
              // Subtle ambient shadow that doesn't darken the glass from behind
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 20,
                spreadRadius: -3,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
                blurRadius: 6,
                spreadRadius: -1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(37),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(37),
                  // Ultra-translucent Apple iOS Liquid Glass (High transparency!)
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.09), // 9% Faint White Glass Sheen
                            Colors.white.withValues(alpha: 0.02), // 2% Crystal-clear Glass Body
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.50), // 50% Light Glass
                            Colors.white.withValues(alpha: 0.25), // 25% Clear Light Glass
                          ],
                  ),
                  // Apple signature 0.75px hairline border
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.60),
                    width: 0.75,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Top hairline specular reflection (iOS light catch on curvature)
                    Positioned(
                      top: 1,
                      left: 32,
                      right: 32,
                      height: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: isDark ? 0.35 : 0.70),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Nav items in 1:1 Apple TV vertical layout (Icon on top, Label on bottom)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: Transform.translate(
                        offset: iconOffset,
                        child: Opacity(
                          opacity: iconOpacity.clamp(0.0, 1.0),
                          child: Row(
                            children: List.generate(items.length, (index) {
                              final item = items[index];
                              final isSelected = index == currentIndex;

                              return Expanded(
                                child: _buildNavItem(
                                  context: context,
                                  index: index,
                                  item: item,
                                  isSelected: isSelected,
                                  isDark: isDark,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required NavItemData item,
    required bool isSelected,
    required bool isDark,
  }) {
    // Apple TV Signature Electric Blue
    const appleBlue = Color(0xFF2997FF);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTabSelected(index);
      },
      child: Center(
        child: AnimatedContainer(
          duration: isAnimationsEnabled ? const Duration(milliseconds: 240) : Duration.zero,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            // Apple TV spotlight capsule behind active tab
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.10),
                    width: 0.75,
                  )
                : Border.all(color: Colors.transparent, width: 0.75),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                      blurRadius: 8,
                      spreadRadius: -1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isSelected
                    ? appleBlue
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.black.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? appleBlue
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.65)
                          : Colors.black.withValues(alpha: 0.60)),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
