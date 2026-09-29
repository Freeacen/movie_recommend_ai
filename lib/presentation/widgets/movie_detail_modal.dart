import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/platform_web_helper.dart';
import '../../data/models/movie.dart';
import '../../domain/enums/movie_status.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import 'rating_dialog.dart';
import 'trailer/trailer_player_view.dart';

class MovieDetailModal extends ConsumerStatefulWidget {
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
  ConsumerState<MovieDetailModal> createState() => _MovieDetailModalState();
}

class _MovieDetailModalState extends ConsumerState<MovieDetailModal> {
  bool _isPlayingTrailer = false;
  bool _isLoadingTrailer = false;
  String? _trailerKey;
  bool _hasTrailer = false;
  double _scrollOffset = 0.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkTrailer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkTrailer() async {
    try {
      final tmdbService = ref.read(tmdbServiceProvider);
      final key = await tmdbService.getMovieTrailer(widget.movie.id);
      if (!mounted) return;
      if (key != null && key.isNotEmpty) {
        setState(() {
          _trailerKey = key;
          _hasTrailer = true;
        });
      }
    } catch (_) {
      // If error or no trailer, _hasTrailer remains false
    }
  }

  Future<void> _playTrailer(Movie currentMovie) async {
    if (_trailerKey != null && _trailerKey!.isNotEmpty) {
      setState(() {
        _isPlayingTrailer = true;
      });
      return;
    }

    setState(() {
      _isLoadingTrailer = true;
    });

    try {
      final tmdbService = ref.read(tmdbServiceProvider);
      final key = await tmdbService.getMovieTrailer(currentMovie.id);

      if (!mounted) return;

      setState(() {
        _isLoadingTrailer = false;
        if (key != null && key.isNotEmpty) {
          _trailerKey = key;
          _hasTrailer = true;
          _isPlayingTrailer = true;
        } else {
          _hasTrailer = false;
        }
      });

      if (key == null || key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu film için fragman bulunamadı.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingTrailer = false;
        _hasTrailer = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final currentMovie = libraryState.watchlist.firstWhere(
      (m) => m.id == widget.movie.id,
      orElse: () => libraryState.watched.firstWhere(
        (m) => m.id == widget.movie.id,
        orElse: () => widget.movie,
      ),
    );

    final isWatchlist = currentMovie.status == MovieStatus.watchlist;
    final isWatched = currentMovie.status == MovieStatus.watched;
    final heroImageUrl = currentMovie.backdropUrl.isNotEmpty
        ? currentMovie.backdropUrl
        : currentMovie.posterUrl;
    final modalHeight = MediaQuery.of(context).size.height * 0.88;
    final heroHeight = (modalHeight * 0.52).clamp(300.0, 460.0);
    final darkProgress = (_scrollOffset / 180.0).clamp(0.0, 1.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          height: modalHeight,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1.5),
              left: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1),
              right: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                // 1. FIXED FULL-HEIGHT BACKGROUND HERO POSTER
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      heroImageUrl.isNotEmpty
                          ? Image.network(
                              heroImageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.surfaceElevated,
                                child: Center(
                                  child: Icon(Icons.movie_outlined, color: AppColors.textLow, size: 64),
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.surfaceElevated,
                              child: Center(
                                child: Icon(Icons.movie_outlined, color: AppColors.textLow, size: 64),
                              ),
                            ),
                      // Dynamic darkening overlay (minimal at start, deepens on scroll!)
                      Container(
                        color: Colors.black.withValues(alpha: (0.05 + 0.65 * darkProgress).clamp(0.05, 0.75)),
                      ),
                      // Smooth vertical gradient: crystal clear at top, gradual darkening downwards
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.45, 0.75, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.20 + 0.20 * darkProgress),
                              Colors.black.withValues(alpha: 0.55 + 0.25 * darkProgress),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. ACTIVE TRAILER PLAYER (IF PLAYING)
                if (_isPlayingTrailer && _trailerKey != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: heroHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                          color: AppColors.surfaceElevated,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.movie_filter_rounded, size: 16, color: AppColors.primaryBlue),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Fragman Oynatılıyor',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      PlatformWebHelper.openInNewTab(
                                        'https://www.youtube.com/watch?v=$_trailerKey',
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                    label: const Text('YouTube\'da Aç', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.textMedium,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isPlayingTrailer = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 14),
                                    label: const Text('Afişe Dön', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                                      foregroundColor: AppColors.primaryBlue,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.black,
                            child: TrailerPlayerView(youtubeKey: _trailerKey!),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. SCROLLABLE FOREGROUND CONTENT LAYER
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      setState(() {
                        _scrollOffset = notification.metrics.pixels;
                      });
                    }
                    return false;
                  },
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.zero,
                    children: [
                      // Transparent spacer so the hero poster is fully visible initially
                      SizedBox(height: (heroHeight + 75).clamp(360.0, 520.0)),

                      // Overlapping transparent content panel
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // "Fragmanı İzle" button if available and not currently playing
                            if (_hasTrailer && !_isPlayingTrailer)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoadingTrailer ? null : () => _playTrailer(currentMovie),
                                    icon: _isLoadingTrailer
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primaryBlue,
                                            ),
                                          )
                                        : const Icon(Icons.play_circle_fill_rounded, size: 20, color: AppColors.primaryBlue),
                                    label: Text(
                                      _isLoadingTrailer ? 'Fragman Yükleniyor...' : 'Fragmanı İzle 🎬',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.8), width: 1.2),
                                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                  ),
                                ),
                              ),

                const SizedBox(height: 8),

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
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 20,
                                  offset: Offset(0, 4),
                                ),
                              ],
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
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (currentMovie.voteAverage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.tmdbGold.withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.tmdbGold, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              currentMovie.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                          color: Colors.black.withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryIndigo.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
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
                                          color: AppColors.primaryBlue.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Değiştirmek İçin Dokun ✏️',
                                          style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    currentMovie.recommendedAt != null
                                        ? '${DateFormatter.formatFriendly(currentMovie.recommendedAt)} (${DateFormatter.formatRelative(currentMovie.recommendedAt)})'
                                        : 'Tarih seçilmedi (tıkla ve belirle)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_calendar_rounded, color: AppColors.primaryBlue, size: 20),
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
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.45)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.primaryBlue, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              'Puanın: ${currentMovie.userRating!.toStringAsFixed(1)} / 10.0',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            if (currentMovie.ratingSource == 'ai_inferred')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryIndigo.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primaryIndigo.withValues(alpha: 0.5)),
                                ),
                                child: const Text(
                                  'AI Sohbet Analizi 🤖',
                                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
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
                              color: Colors.white.withValues(alpha: 0.90),
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
                  const Text(
                    'Beğendiğin Yönleri',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentMovie.likedAspects.map((aspect) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accentNeon.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentNeon),
                            const SizedBox(width: 6),
                            Text(
                              aspect,
                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
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
                  const Text(
                    'Beğenmediğin / Sıkan Yönleri',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentMovie.dislikedAspects.map((aspect) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accentRose.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_circle_outline, size: 14, color: AppColors.accentRose),
                            const SizedBox(width: 6),
                            Text(
                              aspect,
                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Overview
                const Text(
                  'Özet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    currentMovie.overview ?? 'Açıklama bulunmuyor.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w400,
                    ),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                          backgroundColor: Colors.black.withValues(alpha: 0.50),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

                // Delete from library button
                if (isWatched || isWatchlist || currentMovie.status != MovieStatus.none) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentRose,
                        side: BorderSide(color: AppColors.accentRose.withValues(alpha: 0.6)),
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _confirmDeleteMovie(context, ref, currentMovie),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text(
                        'Kütüphaneden Sil',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),

    // 3. TOP FLOATING CONTROLS (Drag handle & Close Button)
    Positioned(
      top: 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 36),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          Material(
            color: Colors.black.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              tooltip: 'Kapat',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  ],
),
      ),
    ),
  ),
);
  }

  Future<void> _confirmDeleteMovie(BuildContext context, WidgetRef ref, Movie currentMovie) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accentRose, size: 24),
            const SizedBox(width: 8),
            Text(
              'Kütüphaneden Sil',
              style: TextStyle(color: AppColors.textHigh, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '"${currentMovie.title}" kütüphanenden tamamen silinecek. Emin misin?',
          style: TextStyle(color: AppColors.textMedium, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textLow)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(libraryProvider.notifier).removeMovieFromLibrary(currentMovie.id);
      ref.read(settingsProvider.notifier).triggerSync();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${currentMovie.title}" kütüphaneden silindi 🗑️'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
              primary: AppColors.primaryBlue,
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
