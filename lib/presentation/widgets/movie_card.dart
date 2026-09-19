import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/movie.dart';
import '../../domain/enums/movie_status.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback? onTap;
  final VoidCallback? onWatchlistToggle;
  final VoidCallback? onMarkWatched;
  final bool showAspectTags;

  const MovieCard({
    super.key,
    required this.movie,
    this.onTap,
    this.onWatchlistToggle,
    this.onMarkWatched,
    this.showAspectTags = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster image with rating overlay
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  movie.posterUrl.isNotEmpty
                      ? Image.network(
                          movie.posterUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: AppColors.surfaceElevated,
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                        )
                      : _buildPlaceholder(),

                  // Gradient scrim
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.surface.withValues(alpha: 0.9),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Rating chip
                  if (movie.userRating != null || movie.voteAverage != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: movie.userRating != null ? AppColors.primaryAmber : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: movie.userRating != null ? AppColors.primaryAmber : AppColors.primaryBlue.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              movie.userRating != null
                                  ? '${movie.userRating!.toStringAsFixed(1)}${movie.userRating! > 5.0 ? " / 10" : " / 5"}'
                                  : (movie.voteAverage?.toStringAsFixed(1) ?? ''),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHigh,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Status badge
                  if (movie.status != MovieStatus.none)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _buildStatusBadge(),
                    ),
                ],
              ),
            ),

            // Details section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (movie.status == MovieStatus.watched && movie.recommendedAt != null) ...[
                        const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.primaryAmber),
                        const SizedBox(width: 4),
                        Text(
                          DateFormatter.formatFriendly(movie.recommendedAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.primaryAmber, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                      ] else if (movie.releaseDate != null) ...[
                        Text(
                          DateFormatter.formatYear(movie.releaseDate),
                          style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (movie.genres != null && movie.genres!.isNotEmpty)
                        Expanded(
                          child: Text(
                            movie.genres!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: AppColors.textLow),
                          ),
                        ),
                    ],
                  ),

                  // Liked aspect tags if present
                  if (showAspectTags && movie.likedAspects.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: movie.likedAspects.take(2).map((aspect) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryIndigo.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primaryIndigo.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            aspect,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textAccentBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_outlined, size: 40, color: AppColors.textLow.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Text('Afiş Yok', style: TextStyle(fontSize: 11, color: AppColors.textLow)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    String label = '';
    Color bg = AppColors.badgeBg;
    Color border = AppColors.border;

    switch (movie.status) {
      case MovieStatus.watched:
        label = 'İzlendi ✓';
        bg = AppColors.accentNeon.withValues(alpha: 0.2);
        border = AppColors.accentNeon;
        break;
      case MovieStatus.watchlist:
        label = 'Listede 📌';
        bg = AppColors.primaryAmber.withValues(alpha: 0.2);
        border = AppColors.primaryAmber;
        break;
      case MovieStatus.recommended:
        label = 'Öneri ⭐';
        bg = AppColors.primaryIndigo.withValues(alpha: 0.2);
        border = AppColors.primaryIndigo;
        break;
      case MovieStatus.none:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textHigh,
        ),
      ),
    );
  }
}
