import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/user_avatar_widget.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final settings = ref.watch(settingsProvider);
    final watchedMovies = libraryState.watched;
    final watchlist = libraryState.watchlist;
    final isDark = AppColors.isDark;

    // Calculate real dynamic stats
    final totalWatched = watchedMovies.length;
    final totalWatchlist = watchlist.length;
    final topRatedCount = watchedMovies.where((m) {
      final rating = m.userRating ?? m.voteAverage ?? 0;
      return rating >= 8.0;
    }).length;
    final totalHours = (totalWatched * 1.9).round(); // ~114 mins average

    // Calculate genre distribution for chart
    final Map<String, int> genreCounts = {};
    for (final movie in watchedMovies) {
      if (movie.genres != null && movie.genres!.isNotEmpty) {
        final genres = movie.genres!.split(',').map((g) => g.trim());
        for (final g in genres) {
          if (g.isNotEmpty) {
            genreCounts[g] = (genreCounts[g] ?? 0) + 1;
          }
        }
      }
    }

    // Sort genres by frequency
    final sortedGenres = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(5).toList();
    final int maxGenreCount = topGenres.isNotEmpty ? topGenres.first.value : 1;

    // Colors for genre chart bars
    final barGradients = [
      [const Color(0xFF2997FF), const Color(0xFF007AFF)],
      [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
      [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC),
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textHigh,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Profil & İstatistikler',
                style: TextStyle(
                  color: AppColors.textHigh,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            )
          : null,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. User Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1E2536),
                          const Color(0xFF121622),
                        ]
                      : [
                          Colors.white,
                          const Color(0xFFF1F5F9),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  UserAvatarWidget(
                    avatarUrl: settings.avatarUrl,
                    size: 68,
                    showCameraBadge: true,
                    defaultGradient: const [
                      Color(0xFF2997FF),
                      Color(0xFF007AFF),
                    ],
                    onTap: () => UserAvatarWidget.showAvatarSelectionSheet(context, ref),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                settings.effectiveDisplayName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textHigh,
                                  letterSpacing: -0.4,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Kullanıcı Adını Değiştir',
                              icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryAmber),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => UserAvatarWidget.showEditUserNameDialog(context, ref, settings.effectiveDisplayName),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2997FF).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF2997FF).withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2997FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          settings.userEmail != null && settings.userEmail!.isNotEmpty
                              ? settings.userEmail!
                              : 'CineAI Film Tutkunu & Kaşif',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Üyelik: Aktif • Taslak Modeli',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Quick Stats Counters Grid (Kaç film izlemiş?)
            Text(
              'İZLEME ÖZETİ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textLow,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatTile(
                  icon: Icons.movie_filter_rounded,
                  iconColor: const Color(0xFF2997FF),
                  value: '$totalWatched',
                  label: 'İzlenen Film',
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildStatTile(
                  icon: Icons.bookmark_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  value: '$totalWatchlist',
                  label: 'İzleme Listesi',
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatTile(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  value: '$topRatedCount',
                  label: 'Favori / 8.0+',
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildStatTile(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: const Color(0xFF10B981),
                  value: '$totalHours sa',
                  label: 'İzleme Süresi',
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // 3. Genre Distribution Chart (Hangi türleri izlemiş grafik şeklinde)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TÜR DAĞILIMI (GRAFİK)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLow,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Toplam $totalWatched Film',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF2997FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161C28) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: topGenres.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Henüz yeterli izleme verisi bulunmuyor.',
                          style: TextStyle(color: AppColors.textMedium, fontSize: 13),
                        ),
                      ),
                    )
                  : Column(
                      children: List.generate(topGenres.length, (index) {
                        final entry = topGenres[index];
                        final genre = entry.key;
                        final count = entry.value;
                        final percentage = totalWatched > 0
                            ? ((count / totalWatched) * 100).round()
                            : 0;
                        final fraction = (count / maxGenreCount).clamp(0.05, 1.0);
                        final gradient = barGradients[index % barGradients.length];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: gradient.first,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        genre,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textHigh,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$count film (%$percentage)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: gradient.first,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Frosted Progress Bar
                              Container(
                                height: 10,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: fraction,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradient,
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: gradient.first.withValues(alpha: 0.35),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
            ),

            const SizedBox(height: 20),

            // 4. Draft Notice Card (Taslak Bilgisi)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2997FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF2997FF).withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.design_services_rounded,
                    color: Color(0xFF2997FF),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bu profil & grafik sayfası taslak olarak hazırlandı. İstediğin zaman grafikleri pasta dilimi veya zaman çizelgesi gibi yeni görselleştirmelerle genişletebiliriz.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161C28) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHigh,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLow,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
