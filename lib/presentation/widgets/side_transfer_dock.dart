import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SideTransferDockItem {
  final IconData icon;
  final String label;

  const SideTransferDockItem({
    required this.icon,
    required this.label,
  });
}

class SideTransferDock extends StatelessWidget {
  final int currentIndex;
  final Animation<double> itemAnimation;
  final ValueChanged<int>? onTabSelected;

  static const List<SideTransferDockItem> items = [
    SideTransferDockItem(icon: Icons.chat_bubble_rounded, label: 'AI Sohbet'),
    SideTransferDockItem(icon: Icons.person_rounded, label: 'Profil'),
    SideTransferDockItem(icon: Icons.explore_rounded, label: 'Keşfet'),
    SideTransferDockItem(icon: Icons.video_library_rounded, label: 'Kütüphane'),
    SideTransferDockItem(icon: Icons.settings_rounded, label: 'Ayarlar'),
  ];

  const SideTransferDock({
    super.key,
    required this.currentIndex,
    required this.itemAnimation,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const appleBlue = Color(0xFF2997FF);

    return Container(
      width: 78,
      height: 365,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.07),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(6, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.03),
            blurRadius: 8,
            spreadRadius: -1,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.09),
                        Colors.white.withValues(alpha: 0.02),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.50),
                        Colors.white.withValues(alpha: 0.25),
                      ],
              ),
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
                // Right-side specular highlight line (facing screen interior)
                Positioned(
                  right: 1,
                  top: 28,
                  bottom: 28,
                  width: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: isDark ? 0.35 : 0.70),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // 5 items with bottom-to-top cascading upward flow & labels
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AnimatedBuilder(
                    animation: itemAnimation,
                    builder: (context, child) {
                      final animVal = itemAnimation.value;

                      // Staggered intervals from BOTTOM (item 4: Ayarlar) to TOP (item 0: AI Sohbet)
                      const intervals = [
                        Interval(0.48, 0.95, curve: Curves.easeOutCubic), // 0: AI Sohbet (top)
                        Interval(0.36, 0.78, curve: Curves.easeOutCubic), // 1: Profil
                        Interval(0.24, 0.66, curve: Curves.easeOutCubic), // 2: Keşfet
                        Interval(0.12, 0.54, curve: Curves.easeOutCubic), // 3: Kütüphane
                        Interval(0.00, 0.42, curve: Curves.easeOutCubic), // 4: Ayarlar (bottom)
                      ];

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          final isSelected = index == currentIndex;
                          final progress = intervals[index].transform(animVal);

                          return Transform.translate(
                            // Ascends smoothly from +40px (downward) to 0px (resting slot)
                            offset: Offset(0, 40 * (1.0 - progress)),
                            child: Opacity(
                              opacity: progress.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: onTabSelected != null
                                        ? () => onTabSelected!(index)
                                        : null,
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      width: 66,
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark
                                                ? Colors.white.withValues(alpha: 0.12)
                                                : Colors.black.withValues(alpha: 0.08))
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
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
                                            size: 21,
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
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 9.5,
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
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
