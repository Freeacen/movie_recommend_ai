import 'dart:ui';
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
    final ratingValue = movie.userRating ?? movie.voteAverage;
    final year = movie.releaseDate != null ? DateFormatter.formatYear(movie.releaseDate) : null;
    final firstGenre = (movie.genres != null && movie.genres!.isNotEmpty)
        ? movie.genres!.split(',').first.trim()
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: AppColors.isDark ? 0.12 : 0.20),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full Poster Image (covers entire card)
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
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  )
                : _buildPlaceholder(),

            // 2. Top-left Status Badge (if watched/watchlist)
            if (movie.status != MovieStatus.none)
              Positioned(
                top: 8,
                left: 8,
                child: _buildStatusBadge(),
              ),

            // 3. Top-right Rating Chip
            if (ratingValue != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: movie.userRating != null
                          ? AppColors.primaryBlue.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.20),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: movie.userRating != null
                            ? AppColors.primaryBlue
                            : AppColors.tmdbGold,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ratingValue.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: movie.userRating != null
                              ? const Color(0xFF93C5FD)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Bottom Smooth Gradient Scrim Overlay (Afiş net, geçiş pürüzsüz)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 36, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.35, 0.70, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Movie Title
                    Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Minimal info: Year • Genre
                    Row(
                      children: [
                        if (year != null) ...[
                          Text(
                            year,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (firstGenre != null) ...[
                            Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.50),
                              ),
                            ),
                          ],
                        ],
                        if (firstGenre != null)
                          Expanded(
                            child: Text(
                              firstGenre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.70),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
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
        bg = AppColors.accentNeon.withValues(alpha: 0.25);
        border = AppColors.accentNeon;
        break;
      case MovieStatus.watchlist:
        label = 'Listede 📌';
        bg = AppColors.primaryBlue.withValues(alpha: 0.25);
        border = AppColors.primaryBlue;
        break;
      case MovieStatus.recommended:
        label = 'Öneri ⭐';
        bg = AppColors.secondaryBlue.withValues(alpha: 0.25);
        border = AppColors.secondaryBlue;
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
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
