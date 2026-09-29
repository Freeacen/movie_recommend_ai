import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/movie.dart';
import '../../data/models/user_taste_profile.dart';
import '../../data/repositories/movie_repository.dart';
import '../../data/repositories/user_taste_repository.dart';
import '../../domain/enums/filter_enums.dart';
import '../../domain/enums/movie_status.dart';
import 'settings_provider.dart';

enum LibrarySortOption {
  recent('🕒 En Son Eklenen'),
  userRatingDesc('🌟 Puanım (En Yüksek)'),
  userRatingAsc('📉 Puanım (En Düşük)'),
  yearDesc('📅 Yıl (En Yeni)'),
  yearAsc('⏳ Yıl (En Eski)'),
  tmdbRatingDesc('⭐ TMDB (En Yüksek)'),
  titleAsc('🔤 İsim (A - Z)');

  final String label;
  const LibrarySortOption(this.label);
}

class LibraryState {
  final List<Movie> watchlist;
  final List<Movie> watched;
  final List<Movie> rewatchCandidates;
  final UserTasteProfile? tasteProfile;
  final bool isLoading;
  final int selectedTabIndex;
  final LibrarySortOption sortOption;
  final String? selectedGenre;
  final double? minRating;
  final YearRangeFilter yearRange;
  final String searchQuery;

  const LibraryState({
    this.watchlist = const [],
    this.watched = const [],
    this.rewatchCandidates = const [],
    this.tasteProfile,
    this.isLoading = false,
    this.selectedTabIndex = 0,
    this.sortOption = LibrarySortOption.recent,
    this.selectedGenre,
    this.minRating,
    this.yearRange = YearRangeFilter.all,
    this.searchQuery = '',
  });

  int get activeFilterCount {
    int count = 0;
    if (selectedGenre != null && selectedGenre!.isNotEmpty) count++;
    if (minRating != null && minRating! > 0) count++;
    if (yearRange != YearRangeFilter.all) count++;
    if (sortOption != LibrarySortOption.recent) count++;
    return count;
  }

  bool get isFiltered => activeFilterCount > 0 || searchQuery.trim().isNotEmpty;

  LibraryState copyWith({
    List<Movie>? watchlist,
    List<Movie>? watched,
    List<Movie>? rewatchCandidates,
    UserTasteProfile? tasteProfile,
    bool? isLoading,
    int? selectedTabIndex,
    LibrarySortOption? sortOption,
    String? selectedGenre,
    bool clearGenre = false,
    double? minRating,
    bool clearMinRating = false,
    YearRangeFilter? yearRange,
    String? searchQuery,
  }) {
    return LibraryState(
      watchlist: watchlist ?? this.watchlist,
      watched: watched ?? this.watched,
      rewatchCandidates: rewatchCandidates ?? this.rewatchCandidates,
      tasteProfile: tasteProfile ?? this.tasteProfile,
      isLoading: isLoading ?? this.isLoading,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      sortOption: sortOption ?? this.sortOption,
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      yearRange: yearRange ?? this.yearRange,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Movie> filterAndSort(List<Movie> source) {
    var list = source;

    // 1. Text Search Filter
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((m) {
        final title = m.title.toLowerCase();
        final genres = (m.genres ?? '').toLowerCase();
        return title.contains(q) || genres.contains(q);
      }).toList();
    }

    // 2. Genre Filter
    if (selectedGenre != null && selectedGenre!.isNotEmpty) {
      list = list.where((m) => (m.genres ?? '').contains(selectedGenre!)).toList();
    }

    // 3. Min Rating Filter
    if (minRating != null && minRating! > 0) {
      list = list.where((m) {
        final score = m.userRating ?? m.voteAverage ?? 0.0;
        return score >= minRating!;
      }).toList();
    }

    // 4. Year Range Filter
    if (yearRange != YearRangeFilter.all) {
      list = list.where((m) {
        if (m.releaseDate == null || m.releaseDate!.isEmpty) return false;
        final year = int.tryParse(m.releaseDate!.substring(0, 4));
        if (year == null) return false;
        if (yearRange.minYear != null && year < yearRange.minYear!) return false;
        if (yearRange.maxYear != null && year > yearRange.maxYear!) return false;
        return true;
      }).toList();
    }

    // 5. Sorting
    final sorted = List<Movie>.from(list);
    switch (sortOption) {
      case LibrarySortOption.recent:
        // Keep original DB order
        break;
      case LibrarySortOption.userRatingDesc:
        sorted.sort((a, b) {
          final ra = a.userRating ?? 0.0;
          final rb = b.userRating ?? 0.0;
          final cmp = rb.compareTo(ra);
          if (cmp != 0) return cmp;
          return (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0);
        });
        break;
      case LibrarySortOption.userRatingAsc:
        sorted.sort((a, b) {
          final ra = a.userRating ?? 999.0;
          final rb = b.userRating ?? 999.0;
          final cmp = ra.compareTo(rb);
          if (cmp != 0) return cmp;
          return (a.voteAverage ?? 0.0).compareTo(b.voteAverage ?? 0.0);
        });
        break;
      case LibrarySortOption.yearDesc:
        sorted.sort((a, b) {
          final ya = a.releaseDate ?? '';
          final yb = b.releaseDate ?? '';
          return yb.compareTo(ya);
        });
        break;
      case LibrarySortOption.yearAsc:
        sorted.sort((a, b) {
          final ya = a.releaseDate ?? '';
          final yb = b.releaseDate ?? '';
          if (ya.isEmpty) return 1;
          if (yb.isEmpty) return -1;
          return ya.compareTo(yb);
        });
        break;
      case LibrarySortOption.tmdbRatingDesc:
        sorted.sort((a, b) {
          final ra = a.voteAverage ?? 0.0;
          final rb = b.voteAverage ?? 0.0;
          return rb.compareTo(ra);
        });
        break;
      case LibrarySortOption.titleAsc:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return sorted;
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final MovieRepository _movieRepo;
  final UserTasteRepository _tasteRepo;

  LibraryNotifier({
    required MovieRepository movieRepo,
    required UserTasteRepository tasteRepo,
  })  : _movieRepo = movieRepo,
        _tasteRepo = tasteRepo,
        super(const LibraryState()) {
    loadLibrary();
  }

  Future<void> loadLibrary() async {
    state = state.copyWith(isLoading: true);
    try {
      final watched = await _movieRepo.getWatchedMovies();
      final watchlist = await _movieRepo.getWatchlist();
      final rewatch = await _movieRepo.getRewatchCandidates();
      final profile = await _tasteRepo.getUserTasteProfile();

      state = state.copyWith(
        watchlist: watchlist,
        watched: watched,
        rewatchCandidates: rewatch,
        tasteProfile: profile,
        isLoading: false,
      );
    } catch (e) {
      // Fallback guarantees state is updated
      state = state.copyWith(
        selectedTabIndex: 1,
        isLoading: false,
      );
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void setTab(int index) {
    state = state.copyWith(selectedTabIndex: index);
  }

  void setSortOption(LibrarySortOption option) {
    state = state.copyWith(sortOption: option);
  }

  void selectGenre(String? genre) {
    if (state.selectedGenre == genre) {
      state = state.copyWith(clearGenre: true);
    } else {
      state = state.copyWith(selectedGenre: genre);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void applyFilters({
    LibrarySortOption? sortOption,
    String? genre,
    bool clearGenre = false,
    double? minRating,
    bool clearMinRating = false,
    YearRangeFilter? yearRange,
  }) {
    state = state.copyWith(
      sortOption: sortOption ?? state.sortOption,
      selectedGenre: clearGenre ? null : (genre ?? state.selectedGenre),
      clearGenre: clearGenre,
      minRating: clearMinRating ? null : (minRating ?? state.minRating),
      clearMinRating: clearMinRating,
      yearRange: yearRange ?? state.yearRange,
    );
  }

  void clearFilters() {
    state = state.copyWith(
      clearGenre: true,
      clearMinRating: true,
      yearRange: YearRangeFilter.all,
      searchQuery: '',
      sortOption: LibrarySortOption.recent,
    );
  }

  Future<void> toggleWatchlist(Movie movie) async {
    final existing = await _movieRepo.getMovieById(movie.id);
    if (existing != null && existing.status == MovieStatus.watchlist) {
      await _movieRepo.updateMovieStatus(movie.id, MovieStatus.none);
    } else {
      final updated = (existing ?? movie).copyWith(status: MovieStatus.watchlist);
      await _movieRepo.saveMovie(updated);
    }
    await loadLibrary();
  }

  /// Completely remove movie from library (both watched and watchlist)
  Future<void> removeMovieFromLibrary(int movieId) async {
    await _movieRepo.deleteMovie(movieId);
    await loadLibrary();
  }

  /// Mark movie as watched directly from UI with optional rating and optional custom watch date
  Future<void> markAsWatched({
    required Movie movie,
    double? rating,
    String? review,
    DateTime? watchDate,
  }) async {
    // Ensure movie exists in DB first
    final existing = await _movieRepo.getMovieById(movie.id);
    if (existing == null) {
      await _movieRepo.recordRecommendationProposal(movie);
    }

    await _movieRepo.confirmWatchedAndPreserveDate(
      movieId: movie.id,
      rating: rating,
      ratingSource: rating != null ? 'manual' : null,
      userReview: review,
      explicitWatchDate: watchDate,
    );

    await loadLibrary();
  }

  /// Manually update the watch date of an existing movie
  Future<void> updateWatchDate({
    required int movieId,
    required DateTime newWatchDate,
  }) async {
    await _movieRepo.updateWatchDate(
      movieId: movieId,
      newWatchDate: newWatchDate,
    );
    await loadLibrary();
  }

  /// Save movie evaluation completed through the conversational AI modal
  Future<void> saveAiReview({
    required Movie movie,
    required double rating,
    required List<String> likedAspects,
    required List<String> dislikedAspects,
    required String reviewSummary,
  }) async {
    final existing = await _movieRepo.getMovieById(movie.id);
    if (existing == null) {
      await _movieRepo.recordRecommendationProposal(movie);
    }

    await _movieRepo.confirmWatchedAndPreserveDate(
      movieId: movie.id,
      rating: rating,
      ratingSource: 'ai_inferred',
      likedAspects: likedAspects,
      dislikedAspects: dislikedAspects,
      userReview: reviewSummary,
    );

    if (likedAspects.isNotEmpty || dislikedAspects.isNotEmpty) {
      await _tasteRepo.appendPreferences(
        newLiked: likedAspects,
        newDisliked: dislikedAspects,
      );
    }

    await loadLibrary();
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(
    movieRepo: ref.watch(movieRepositoryProvider),
    tasteRepo: ref.watch(userTasteRepositoryProvider),
  );
});
