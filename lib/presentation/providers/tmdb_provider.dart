import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/movie.dart';
import '../../data/services/tmdb_service.dart';
import '../../domain/enums/filter_enums.dart';
import 'settings_provider.dart';

enum DiscoverCategory {
  trending('🔥 Trendler'),
  popular('🌟 Popüler'),
  topRated('⭐ En İyiler'),
  nowPlaying('🎬 Vizyonda');

  final String label;
  const DiscoverCategory(this.label);
}

class TmdbState {
  final List<Movie> trendingMovies;
  final List<Movie> searchResults;
  final List<Movie> categoryMovies;
  final String searchQuery;
  final String? selectedGenre;
  final DiscoverCategory selectedCategory;
  final DiscoverSortOption discoverSort;
  final double? minRating;
  final YearRangeFilter yearRange;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;

  const TmdbState({
    this.trendingMovies = const [],
    this.searchResults = const [],
    this.categoryMovies = const [],
    this.searchQuery = '',
    this.selectedGenre,
    this.selectedCategory = DiscoverCategory.trending,
    this.discoverSort = DiscoverSortOption.popularityDesc,
    this.minRating,
    this.yearRange = YearRangeFilter.all,
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
  });

  bool get isCustomFilterActive =>
      selectedGenre != null ||
      minRating != null ||
      yearRange != YearRangeFilter.all ||
      discoverSort != DiscoverSortOption.popularityDesc;

  int get activeFilterCount {
    int count = 0;
    if (selectedGenre != null) count++;
    if (minRating != null && minRating! > 0) count++;
    if (yearRange != YearRangeFilter.all) count++;
    if (discoverSort != DiscoverSortOption.popularityDesc) count++;
    return count;
  }

  TmdbState copyWith({
    List<Movie>? trendingMovies,
    List<Movie>? searchResults,
    List<Movie>? categoryMovies,
    String? searchQuery,
    String? selectedGenre,
    bool clearGenre = false,
    DiscoverCategory? selectedCategory,
    DiscoverSortOption? discoverSort,
    double? minRating,
    bool clearMinRating = false,
    YearRangeFilter? yearRange,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
  }) {
    return TmdbState(
      trendingMovies: trendingMovies ?? this.trendingMovies,
      searchResults: searchResults ?? this.searchResults,
      categoryMovies: categoryMovies ?? this.categoryMovies,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      selectedCategory: selectedCategory ?? this.selectedCategory,
      discoverSort: discoverSort ?? this.discoverSort,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      yearRange: yearRange ?? this.yearRange,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  List<Movie> get displayedMovies {
    if (searchQuery.isNotEmpty) {
      var list = searchResults;
      if (selectedGenre != null && selectedGenre!.isNotEmpty) {
        list = list.where((m) => (m.genres ?? '').contains(selectedGenre!)).toList();
      }
      if (minRating != null && minRating! > 0) {
        list = list.where((m) => (m.voteAverage ?? 0.0) >= minRating!).toList();
      }
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
      return list;
    }
    return categoryMovies.isNotEmpty ? categoryMovies : trendingMovies;
  }
}

class TmdbNotifier extends StateNotifier<TmdbState> {
  final TmdbService _tmdbService;

  TmdbNotifier({required TmdbService tmdbService})
      : _tmdbService = tmdbService,
        super(const TmdbState()) {
    fetchTrending();
  }

  Future<void> fetchTrending() async {
    state = state.copyWith(isLoading: true, currentPage: 1, hasMore: true);
    final movies = await _tmdbService.getTrendingMovies(page: 1);
    state = state.copyWith(
      trendingMovies: movies,
      categoryMovies: movies,
      isLoading: false,
      hasMore: movies.length >= 10,
    );
  }

  Future<void> setCategory(DiscoverCategory category) async {
    if (state.selectedCategory == category && state.selectedGenre == null && state.categoryMovies.isNotEmpty) {
      return;
    }

    state = state.copyWith(
      selectedCategory: category,
      selectedGenre: null,
      currentPage: 1,
      hasMore: true,
      isLoading: true,
    );

    List<Movie> movies;
    switch (category) {
      case DiscoverCategory.trending:
        movies = await _tmdbService.getTrendingMovies(page: 1);
        break;
      case DiscoverCategory.popular:
        movies = await _tmdbService.getPopularMovies(page: 1);
        break;
      case DiscoverCategory.topRated:
        movies = await _tmdbService.getTopRatedMovies(page: 1);
        break;
      case DiscoverCategory.nowPlaying:
        movies = await _tmdbService.getNowPlayingMovies(page: 1);
        break;
    }

    state = state.copyWith(
      categoryMovies: movies,
      isLoading: false,
      hasMore: movies.length >= 10,
    );
  }

  Future<void> selectGenre(String? genre) async {
    if (state.selectedGenre == genre) {
      // Deselect genre, return to active category
      await setCategory(state.selectedCategory);
      return;
    }

    if (genre == null) {
      await setCategory(state.selectedCategory);
      return;
    }

    state = state.copyWith(
      selectedGenre: genre,
      currentPage: 1,
      hasMore: true,
      isLoading: true,
    );

    final genreId = TmdbService.genreNameToId[genre.toLowerCase()];
    List<Movie> movies;
    if (genreId != null) {
      movies = await _tmdbService.discoverMoviesByGenre(genreId: genreId, page: 1);
    } else {
      movies = state.categoryMovies.where((m) => (m.genres ?? '').contains(genre)).toList();
    }

    state = state.copyWith(
      categoryMovies: movies,
      isLoading: false,
      hasMore: movies.length >= 10,
    );
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query, currentPage: 1, hasMore: true);
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }

    state = state.copyWith(isLoading: true);
    final results = await _tmdbService.searchMovies(query, page: 1);
    state = state.copyWith(
      searchResults: results,
      isLoading: false,
      hasMore: results.length >= 10,
    );
  }

  Future<void> searchWithAi(String query) async {
    state = state.copyWith(searchQuery: query);
    if (query.trim().isEmpty) return;

    state = state.copyWith(isLoading: true);
    final results = await _tmdbService.searchMoviesWithAi(query);
    state = state.copyWith(
      searchResults: results,
      isLoading: false,
      hasMore: false,
    );
  }

  Future<void> applyFilters({
    DiscoverSortOption? sortOption,
    String? genre,
    bool clearGenre = false,
    double? minRating,
    bool clearMinRating = false,
    YearRangeFilter? yearRange,
  }) async {
    final nextSort = sortOption ?? state.discoverSort;
    final nextGenre = clearGenre ? null : (genre ?? state.selectedGenre);
    final nextRating = clearMinRating ? null : (minRating ?? state.minRating);
    final nextYear = yearRange ?? state.yearRange;

    state = state.copyWith(
      discoverSort: nextSort,
      selectedGenre: nextGenre,
      clearGenre: clearGenre,
      minRating: nextRating,
      clearMinRating: clearMinRating,
      yearRange: nextYear,
      currentPage: 1,
      hasMore: true,
      isLoading: true,
    );

    final genreId = nextGenre != null ? TmdbService.genreNameToId[nextGenre.toLowerCase()] : null;
    final movies = await _tmdbService.discoverMoviesWithFilters(
      genreId: genreId,
      sortBy: nextSort.apiValue,
      minRating: nextRating,
      minYear: nextYear.minYear,
      maxYear: nextYear.maxYear,
      page: 1,
    );

    state = state.copyWith(
      categoryMovies: movies,
      isLoading: false,
      hasMore: movies.length >= 10,
    );
  }

  Future<void> resetFilters() async {
    state = state.copyWith(
      clearGenre: true,
      clearMinRating: true,
      discoverSort: DiscoverSortOption.popularityDesc,
      yearRange: YearRangeFilter.all,
    );
    await setCategory(state.selectedCategory);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoadingMore: true);

    List<Movie> newMovies = [];
    try {
      if (state.searchQuery.isNotEmpty) {
        newMovies = await _tmdbService.searchMovies(state.searchQuery, page: nextPage);
        final existingIds = state.searchResults.map((m) => m.id).toSet();
        final unique = newMovies.where((m) => !existingIds.contains(m.id)).toList();
        state = state.copyWith(
          searchResults: [...state.searchResults, ...unique],
          currentPage: nextPage,
          hasMore: newMovies.isNotEmpty,
          isLoadingMore: false,
        );
        return;
      }

      if (state.isCustomFilterActive) {
        final genreId = state.selectedGenre != null
            ? TmdbService.genreNameToId[state.selectedGenre!.toLowerCase()]
            : null;
        newMovies = await _tmdbService.discoverMoviesWithFilters(
          genreId: genreId,
          sortBy: state.discoverSort.apiValue,
          minRating: state.minRating,
          minYear: state.yearRange.minYear,
          maxYear: state.yearRange.maxYear,
          page: nextPage,
        );
      } else if (state.selectedGenre != null) {
        final genreId = TmdbService.genreNameToId[state.selectedGenre!.toLowerCase()];
        if (genreId != null) {
          newMovies = await _tmdbService.discoverMoviesByGenre(genreId: genreId, page: nextPage);
        }
      } else {
        switch (state.selectedCategory) {
          case DiscoverCategory.trending:
            newMovies = await _tmdbService.getTrendingMovies(page: nextPage);
            break;
          case DiscoverCategory.popular:
            newMovies = await _tmdbService.getPopularMovies(page: nextPage);
            break;
          case DiscoverCategory.topRated:
            newMovies = await _tmdbService.getTopRatedMovies(page: nextPage);
            break;
          case DiscoverCategory.nowPlaying:
            newMovies = await _tmdbService.getNowPlayingMovies(page: nextPage);
            break;
        }
      }

      final existingIds = state.categoryMovies.map((m) => m.id).toSet();
      final unique = newMovies.where((m) => !existingIds.contains(m.id)).toList();
      state = state.copyWith(
        categoryMovies: [...state.categoryMovies, ...unique],
        currentPage: nextPage,
        hasMore: newMovies.isNotEmpty,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
    }
  }
}

final tmdbProvider = StateNotifierProvider<TmdbNotifier, TmdbState>((ref) {
  return TmdbNotifier(tmdbService: ref.watch(tmdbServiceProvider));
});
