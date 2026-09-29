import 'package:flutter_test/flutter_test.dart';
import 'package:movie_recommend_ai/data/models/movie.dart';
import 'package:movie_recommend_ai/domain/enums/filter_enums.dart';
import 'package:movie_recommend_ai/domain/enums/movie_status.dart';
import 'package:movie_recommend_ai/presentation/providers/library_provider.dart';

void main() {
  group('LibraryState Filter and Sort Tests', () {
    final m1 = Movie(
      id: 1,
      title: 'Inception',
      releaseDate: '2010-07-16',
      userRating: 9.5,
      voteAverage: 8.4,
      genres: 'Bilim Kurgu, Aksiyon',
      status: MovieStatus.watched,
    );

    final m2 = Movie(
      id: 2,
      title: 'Interstellar',
      releaseDate: '2014-11-07',
      userRating: 9.8,
      voteAverage: 8.6,
      genres: 'Bilim Kurgu, Dram',
      status: MovieStatus.watched,
    );

    final m3 = Movie(
      id: 3,
      title: 'Pulp Fiction',
      releaseDate: '1994-09-10',
      userRating: 8.0,
      voteAverage: 8.9,
      genres: 'Gerilim, Suç',
      status: MovieStatus.watched,
    );

    final m4 = Movie(
      id: 4,
      title: 'The Dark Knight',
      releaseDate: '2008-07-18',
      userRating: 9.5,
      voteAverage: 9.0,
      genres: 'Aksiyon, Suç, Dram',
      status: MovieStatus.watched,
    );

    final rawList = [m1, m2, m3, m4];

    test('Filter by search query matches title or genre case-insensitively', () {
      final stateTitle = LibraryState(searchQuery: 'dark');
      final resultTitle = stateTitle.filterAndSort(rawList);
      expect(resultTitle.length, 1);
      expect(resultTitle.first.title, 'The Dark Knight');

      final stateGenre = LibraryState(searchQuery: 'gerilim');
      final resultGenre = stateGenre.filterAndSort(rawList);
      expect(resultGenre.length, 1);
      expect(resultGenre.first.title, 'Pulp Fiction');
    });

    test('Filter by selectedGenre filters accurately', () {
      final state = LibraryState(selectedGenre: 'Aksiyon');
      final result = state.filterAndSort(rawList);
      expect(result.length, 2);
      expect(result.map((m) => m.title).toSet(), {'Inception', 'The Dark Knight'});
    });

    test('Sort by userRatingDesc sorts highest user rating first with TMDB tie-breaker', () {
      final state = LibraryState(sortOption: LibrarySortOption.userRatingDesc);
      final result = state.filterAndSort(rawList);
      // 9.8 (Interstellar), then 9.5 (The Dark Knight voteAverage 9.0 > Inception 8.4), then 8.0 (Pulp Fiction)
      expect(result[0].title, 'Interstellar');
      expect(result[1].title, 'The Dark Knight');
      expect(result[2].title, 'Inception');
      expect(result[3].title, 'Pulp Fiction');
    });

    test('Sort by userRatingAsc sorts lowest user rating first', () {
      final state = LibraryState(sortOption: LibrarySortOption.userRatingAsc);
      final result = state.filterAndSort(rawList);
      expect(result.first.title, 'Pulp Fiction');
      expect(result.last.title, 'Interstellar');
    });

    test('Sort by yearDesc sorts newest release first', () {
      final state = LibraryState(sortOption: LibrarySortOption.yearDesc);
      final result = state.filterAndSort(rawList);
      expect(result[0].title, 'Interstellar'); // 2014
      expect(result[1].title, 'Inception'); // 2010
      expect(result[2].title, 'The Dark Knight'); // 2008
      expect(result[3].title, 'Pulp Fiction'); // 1994
    });

    test('Sort by yearAsc sorts oldest release first', () {
      final state = LibraryState(sortOption: LibrarySortOption.yearAsc);
      final result = state.filterAndSort(rawList);
      expect(result[0].title, 'Pulp Fiction'); // 1994
      expect(result[3].title, 'Interstellar'); // 2014
    });

    test('Sort by tmdbRatingDesc sorts highest TMDB score first', () {
      final state = LibraryState(sortOption: LibrarySortOption.tmdbRatingDesc);
      final result = state.filterAndSort(rawList);
      expect(result[0].title, 'The Dark Knight'); // 9.0
      expect(result[1].title, 'Pulp Fiction'); // 8.9
      expect(result[2].title, 'Interstellar'); // 8.6
      expect(result[3].title, 'Inception'); // 8.4
    });

    test('Sort by titleAsc sorts alphabetically', () {
      final state = LibraryState(sortOption: LibrarySortOption.titleAsc);
      final result = state.filterAndSort(rawList);
      expect(result[0].title, 'Inception');
      expect(result[1].title, 'Interstellar');
      expect(result[2].title, 'Pulp Fiction');
      expect(result[3].title, 'The Dark Knight');
    });

    test('Filter by minRating filters accurately', () {
      final state = LibraryState(minRating: 9.0);
      final result = state.filterAndSort(rawList);
      // Inception (9.5), Interstellar (9.8), The Dark Knight (9.5) >= 9.0
      expect(result.length, 3);
      expect(result.any((m) => m.title == 'Pulp Fiction'), false);
    });

    test('Filter by yearRange filters accurately', () {
      final stateTens = LibraryState(yearRange: YearRangeFilter.tens); // 2010 - 2019
      final resultTens = stateTens.filterAndSort(rawList);
      expect(resultTens.length, 2);
      expect(resultTens.map((m) => m.title).toSet(), {'Inception', 'Interstellar'});

      final stateNineties = LibraryState(yearRange: YearRangeFilter.nineties); // 1990 - 1999
      final resultNineties = stateNineties.filterAndSort(rawList);
      expect(resultNineties.length, 1);
      expect(resultNineties.first.title, 'Pulp Fiction');
    });

    test('activeFilterCount and isFiltered compute correctly', () {
      const emptyState = LibraryState();
      expect(emptyState.activeFilterCount, 0);
      expect(emptyState.isFiltered, false);

      final filteredState = LibraryState(
        selectedGenre: 'Aksiyon',
        minRating: 8.0,
        sortOption: LibrarySortOption.userRatingDesc,
      );
      expect(filteredState.activeFilterCount, 3);
      expect(filteredState.isFiltered, true);
    });
  });
}
