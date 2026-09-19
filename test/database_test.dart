import 'package:flutter_test/flutter_test.dart';
import 'package:movie_recommend_ai/data/models/movie.dart';
import 'package:movie_recommend_ai/domain/enums/movie_status.dart';

void main() {
  group('Movie Model & Timestamp Preservation Tests', () {
    test('Strict Timestamp Rule: Confirming watched preserves original recommended_at', () {
      const initialProposedDate = '2024-01-10T12:00:00.000Z';

      // 1. Movie proposed by AI
      const proposedMovie = Movie(
        id: 101,
        title: 'Memento',
        status: MovieStatus.recommended,
        initialProposedAt: initialProposedDate,
        recommendedAt: null, // deliberately not committed until watched
        reviewed: false,
      );

      expect(proposedMovie.status, MovieStatus.recommended);
      expect(proposedMovie.initialProposedAt, initialProposedDate);
      expect(proposedMovie.recommendedAt, isNull);

      // 2. User confirms watched today
      final updatedMovie = proposedMovie.copyWith(
        status: MovieStatus.watched,
        recommendedAt: proposedMovie.initialProposedAt, // Strictly anchored to proposal date!
        userRating: 4.5,
        ratingSource: 'ai_inferred',
        likedAspects: ['ters köşe kurgu', 'akıl oyunları'],
        reviewed: true,
      );

      // Verify status and timestamp
      expect(updatedMovie.status, MovieStatus.watched);
      expect(updatedMovie.reviewed, isTrue);
      expect(updatedMovie.userRating, 4.5);
      expect(updatedMovie.ratingSource, 'ai_inferred');
      expect(updatedMovie.recommendedAt, equals(initialProposedDate)); // NEVER overwritten!
      expect(updatedMovie.likedAspects.length, 2);
    });

    test('Movie Serialization and Deserialization to SQLite Map', () {
      const movie = Movie(
        id: 202,
        title: 'Arrival',
        overview: 'Dilbilimci Dr. Louise Banks uzaylılarla iletişim kurmaya çalışır.',
        posterPath: '/arrival.jpg',
        backdropPath: '/arrival_backdrop.jpg',
        releaseDate: '2016-11-11',
        voteAverage: 7.9,
        genres: 'Bilim Kurgu, Gizem',
        status: MovieStatus.watched,
        initialProposedAt: '2024-03-01T10:00:00.000Z',
        recommendedAt: '2024-03-01T10:00:00.000Z',
        userRating: 4.8,
        ratingSource: 'manual',
        likedAspects: ['dilbilimsel kurgu', 'derin atmosfer'],
        dislikedAspects: [],
        userReview: 'Muhteşem bir bilim kurgu başyapıtı.',
        reviewed: true,
      );

      final map = movie.toMap();
      final restored = Movie.fromMap(map);

      expect(restored.id, movie.id);
      expect(restored.title, movie.title);
      expect(restored.status, MovieStatus.watched);
      expect(restored.recommendedAt, '2024-03-01T10:00:00.000Z');
      expect(restored.userRating, 4.8);
      expect(restored.likedAspects, contains('dilbilimsel kurgu'));
      expect(restored.reviewed, isTrue);
    });

    test('User Manual Watch Date Update: Allows explicit date override from Library', () {
      const movie = Movie(
        id: 303,
        title: 'Interstellar',
        status: MovieStatus.watched,
        recommendedAt: '2024-01-01T00:00:00.000Z',
      );

      final manualDate = DateTime.utc(2023, 5, 15);
      final updated = movie.copyWith(
        recommendedAt: manualDate.toIso8601String(),
      );

      expect(updated.recommendedAt, '2023-05-15T00:00:00.000Z');
      expect(updated.status, MovieStatus.watched);
    });
  });
}
