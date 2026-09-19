import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/movie.dart';
import '../../domain/enums/movie_status.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import 'rating_dialog.dart';

class MovieDetailModal extends ConsumerWidget {
  final Movie movie;

  const MovieDetailModal({super.key, required this.movie});

  static void show(BuildContext context, Movie movie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MovieDetailModal(movie: movie),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final currentMovie = libraryState.watchlist.firstWhere(
      (m) => m.id == movie.id,
      orElse: () => libraryState.watched.firstWhere(
        (m) => m.id == movie.id,
        orElse: () => movie,
      ),
    );

    final isWatchlist = currentMovie.status == MovieStatus.watchlist;
    final isWatched = currentMovie.status == MovieStatus.watched;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textLow.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // Backdrop image or header
                if (currentMovie.backdropUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        currentMovie.backdropUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Title and release year
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentMovie.title,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textHigh,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              DateFormatter.formatYear(currentMovie.releaseDate),
                              if (currentMovie.genres != null) currentMovie.genres,
                            ].where((s) => s != null && s.isNotEmpty).join(' • '),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (currentMovie.voteAverage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryAmber.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.primaryAmber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              currentMovie.voteAverage!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textHigh,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Watch / Recommendation Date Info Banner (Editable)
                if (currentMovie.recommendedAt != null || isWatched)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _pickWatchDate(context, ref, currentMovie),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryIndigo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryIndigo.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history_toggle_off_rounded, color: AppColors.primaryIndigo, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'İzlenme & Öneri Tarihi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textAccentBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryAmber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Değiştirmek İçin Dokun ✏️',
                                          style: TextStyle(fontSize: 9, color: AppColors.primaryAmber, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    currentMovie.recommendedAt != null
                                        ? '${DateFormatter.formatFriendly(currentMovie.recommendedAt)} (${DateFormatter.formatRelative(currentMovie.recommendedAt)})'
                                        : 'Tarih seçilmedi (tıkla ve belirle)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textHigh,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_calendar_rounded, color: AppColors.primaryAmber, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                // User Rating & Review if available
                if (currentMovie.userRating != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.primaryAmber, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              'Puanın: ${currentMovie.userRating!.toStringAsFixed(1)} / 10.0',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textHigh,
                              ),
                            ),
                            const Spacer(),
                            if (currentMovie.ratingSource == 'ai_inferred')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryIndigo.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'AI Sohbet Analizi 🤖',
                                  style: TextStyle(fontSize: 10, color: AppColors.textAccentBlue, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        if (currentMovie.userReview != null && currentMovie.userReview!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '"${currentMovie.userReview!}"',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Liked Aspects tags
                if (currentMovie.likedAspects.isNotEmpty) ...[
                  Text(
                    'Beğendiğin Yönleri',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textHigh),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentMovie.likedAspects.map((aspect) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentNeon.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accentNeon.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentNeon),
                            const SizedBox(width: 6),
                            Text(
                              aspect,
                              style: TextStyle(fontSize: 12, color: AppColors.textHigh, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Disliked Aspects tags
                if (currentMovie.dislikedAspects.isNotEmpty) ...[
                  Text(
                    'Beğenmediğin / Sıkan Yönleri',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textHigh),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentMovie.dislikedAspects.map((aspect) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accentRose.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_circle_outline, size: 14, color: AppColors.accentRose),
                            const SizedBox(width: 6),
                            Text(
                              aspect,
                              style: TextStyle(fontSize: 12, color: AppColors.textHigh, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Overview
                Text(
                  'Özet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textHigh),
                ),
                const SizedBox(height: 8),
                Text(
                  currentMovie.overview ?? 'Açıklama bulunmuyor.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMedium,
                  ),
                ),

                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(libraryProvider.notifier).toggleWatchlist(currentMovie);
                          Navigator.pop(context);
                        },
                        icon: Icon(isWatchlist ? Icons.bookmark_remove : Icons.bookmark_add_outlined),
                        label: Text(isWatchlist ? 'Listeden Çıkar' : 'İzleme Listesi'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          RatingDialog.show(context, currentMovie);
                        },
                        icon: Icon(isWatched ? Icons.check_circle : Icons.star_border_rounded),
                        label: Text(isWatched ? 'Puanı Düzenle' : 'İzledim & Puan Ver'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWatchDate(BuildContext context, WidgetRef ref, Movie currentMovie) async {
    DateTime initialDate = DateTime.now();
    if (currentMovie.recommendedAt != null) {
      initialDate = DateTime.tryParse(currentMovie.recommendedAt!) ?? DateTime.now();
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'İzlenme Tarihini Seçin',
      cancelText: 'Vazgeç',
      confirmText: 'Tarihi Kaydet',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: Theme.of(context).brightness,
              primary: AppColors.primaryAmber,
              onPrimary: Colors.white,
              secondary: AppColors.primaryBlue,
              onSecondary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textHigh,
              error: AppColors.accentRose,
              onError: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      await ref.read(libraryProvider.notifier).updateWatchDate(
        movieId: currentMovie.id,
        newWatchDate: pickedDate,
      );
      ref.read(settingsProvider.notifier).triggerSync();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İzlenme tarihi güncellendi: ${DateFormatter.formatFriendly(pickedDate.toIso8601String())} 📅'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
