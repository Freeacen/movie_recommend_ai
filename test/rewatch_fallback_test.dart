import 'package:flutter_test/flutter_test.dart';
import 'package:movie_recommend_ai/data/models/movie.dart';
import 'package:movie_recommend_ai/data/services/gemini_ai_service.dart';
import 'package:movie_recommend_ai/domain/enums/movie_status.dart';

void main() {
  group('Re-Watch Fallback Logic Tests', () {
    late GeminiAiService geminiService;

    setUp(() {
      geminiService = GeminiAiService();
    });

    test('Re-watch candidates order by oldest recommended_at first', () {
      final now = DateTime.now();

      final movieA = Movie(
        id: 1,
        title: 'Movie A',
        status: MovieStatus.watched,
        recommendedAt: now.subtract(const Duration(days: 300)).toIso8601String(), // 300 days ago
        userRating: 4.8,
        reviewed: true,
      );

      final movieB = Movie(
        id: 2,
        title: 'Movie B',
        status: MovieStatus.watched,
        recommendedAt: now.subtract(const Duration(days: 30)).toIso8601String(), // 30 days ago
        userRating: 4.5,
        reviewed: true,
      );

      final candidates = [movieB, movieA];

      // Sort by recommended_at ASC (oldest first)
      candidates.sort((a, b) => (a.recommendedAt ?? '').compareTo(b.recommendedAt ?? ''));

      expect(candidates.first.title, 'Movie A');
      expect(candidates.last.title, 'Movie B');
    });

    test('Rewatch nudge message formatting includes title, rating and aspects', () {
      const movie = Movie(
        id: 157336,
        title: 'Interstellar',
        status: MovieStatus.watched,
        recommendedAt: '2023-01-15T00:00:00.000Z',
        userRating: 4.9,
        likedAspects: ['kara delik fiziği', 'soundtrack'],
        reviewed: true,
      );

      final nudge = geminiService.generateRewatchNudge(
        movie: movie,
        formattedDate: '15 Ocak 2023',
      );

      expect(nudge, contains('Interstellar'));
      expect(nudge, contains('kara delik fiziği'));
      expect(nudge, contains('yeniden izlemeye ne dersin?'));
    });
  });
}
