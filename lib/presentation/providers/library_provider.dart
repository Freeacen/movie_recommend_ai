import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/movie.dart';
import '../../data/models/user_taste_profile.dart';
import '../../data/repositories/movie_repository.dart';
import '../../data/repositories/user_taste_repository.dart';
import '../../domain/enums/movie_status.dart';
import 'settings_provider.dart';

class LibraryState {
  final List<Movie> watchlist;
  final List<Movie> watched;
  final List<Movie> rewatchCandidates;
  final UserTasteProfile? tasteProfile;
  final bool isLoading;
  final int selectedTabIndex;

  const LibraryState({
    this.watchlist = const [],
    this.watched = const [],
    this.rewatchCandidates = const [],
    this.tasteProfile,
    this.isLoading = false,
    this.selectedTabIndex = 0,
  });

  LibraryState copyWith({
    List<Movie>? watchlist,
    List<Movie>? watched,
    List<Movie>? rewatchCandidates,
    UserTasteProfile? tasteProfile,
    bool? isLoading,
    int? selectedTabIndex,
  }) {
    return LibraryState(
      watchlist: watchlist ?? this.watchlist,
      watched: watched ?? this.watched,
      rewatchCandidates: rewatchCandidates ?? this.rewatchCandidates,
      tasteProfile: tasteProfile ?? this.tasteProfile,
      isLoading: isLoading ?? this.isLoading,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
    );
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
      var watched = await _movieRepo.getWatchedMovies();
      if (watched.isEmpty) {
        await _movieRepo.seedDemoData();
        await _tasteRepo.appendPreferences(
          newLiked: [
            'zamanda yolculuk ve paradokslar',
            'akıl yakan bilim kurgu',
            'kara delik fiziği ve görelilik',
            'Tarantino diyalogları',
            'rüya ve hafıza kurguları',
          ],
          newGenres: ['Bilim Kurgu', 'Macera', 'Gerilim', 'Dram'],
        );
        watched = await _movieRepo.getWatchedMovies();
      }
      final watchlist = await _movieRepo.getWatchlist();
      final rewatch = await _movieRepo.getRewatchCandidates();
      final profile = await _tasteRepo.getUserTasteProfile();

      state = state.copyWith(
        watchlist: watchlist,
        watched: watched,
        rewatchCandidates: rewatch,
        tasteProfile: profile,
        selectedTabIndex: 1, // Default to Watched tab so user immediately sees their 20 movies
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
