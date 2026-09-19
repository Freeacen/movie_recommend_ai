import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/movie.dart';
import '../../data/services/tmdb_service.dart';
import 'settings_provider.dart';

class TmdbState {
  final List<Movie> trendingMovies;
  final List<Movie> searchResults;
  final String searchQuery;
  final String? selectedGenre;
  final bool isLoading;

  const TmdbState({
    this.trendingMovies = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.selectedGenre,
    this.isLoading = false,
  });

  TmdbState copyWith({
    List<Movie>? trendingMovies,
    List<Movie>? searchResults,
    String? searchQuery,
    String? selectedGenre,
    bool? isLoading,
  }) {
    return TmdbState(
      trendingMovies: trendingMovies ?? this.trendingMovies,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGenre: selectedGenre ?? this.selectedGenre,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<Movie> get displayedMovies {
    var list = searchQuery.isNotEmpty ? searchResults : trendingMovies;
    if (selectedGenre != null && selectedGenre!.isNotEmpty) {
      list = list.where((m) => (m.genres ?? '').contains(selectedGenre!)).toList();
    }
    return list;
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
    state = state.copyWith(isLoading: true);
    final movies = await _tmdbService.getTrendingMovies();
    state = state.copyWith(trendingMovies: movies, isLoading: false);
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }

    state = state.copyWith(isLoading: true);
    final results = await _tmdbService.searchMovies(query);
    state = state.copyWith(searchResults: results, isLoading: false);
  }

  Future<void> searchWithAi(String query) async {
    state = state.copyWith(searchQuery: query);
    if (query.trim().isEmpty) return;

    state = state.copyWith(isLoading: true);
    final results = await _tmdbService.searchMoviesWithAi(query);
    state = state.copyWith(searchResults: results, isLoading: false);
  }

  void selectGenre(String? genre) {
    if (state.selectedGenre == genre) {
      state = state.copyWith(selectedGenre: null);
    } else {
      state = state.copyWith(selectedGenre: genre);
    }
  }
}

final tmdbProvider = StateNotifierProvider<TmdbNotifier, TmdbState>((ref) {
  return TmdbNotifier(tmdbService: ref.watch(tmdbServiceProvider));
});
