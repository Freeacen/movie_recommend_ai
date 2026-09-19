import 'package:flutter_test/flutter_test.dart';
import 'package:movie_recommend_ai/data/models/movie.dart';
import 'package:movie_recommend_ai/data/models/user_taste_profile.dart';
import 'package:movie_recommend_ai/data/services/dynamic_explanation_assembler.dart';
import 'package:movie_recommend_ai/domain/enums/movie_status.dart';

void main() {
  group('DynamicExplanationAssembler Tests', () {
    const assembler = DynamicExplanationAssembler();

    const testMovie = Movie(
      id: 2024,
      title: 'Dark City',
      genres: 'Bilim Kurgu, Gizem, Gerilim',
      overview: 'Geçmişini hatırlamayan bir adam, zamanın her gece durdurulduğu karanlık bir şehirde uyanır.',
      status: MovieStatus.none,
      voteAverage: 8.0,
    );

    test('Assembles personalized pitch blending user tastes and modular hooks', () {
      final tasteProfile = UserTasteProfile(
        likedThemes: ['zaman paradoksları', 'akıl oyunları'],
        dislikedThemes: ['ucuz klişeler'],
        preferredGenres: ['Bilim Kurgu', 'Gizem'],
        lastUpdated: DateTime.now().toIso8601String(),
      );

      final result = assembler.assemble(
        movie: testMovie,
        tasteProfile: tasteProfile,
        templateHookGenre: 'Zihin bükücü kurguları ve gerçeklik sorgulamalarını seven bir izleyici olarak',
        templateHookMood: 'Karanlık neo-noir atmosferi ve şok edici kurgusuyla',
        templateCoreSummary: testMovie.overview,
      );

      expect(result.fullReason, contains('Dark City'));
      expect(result.fullReason, contains('zaman paradoksları'));
      expect(result.matchingAspects, isNotEmpty);
      expect(result.matchingAspects.first, contains('zaman paradoksları'));
      expect(result.coreSummary, equals(testMovie.overview));
    });

    test('Gracefully handles empty hooks using movie fallback', () {
      final emptyTaste = UserTasteProfile(
        lastUpdated: DateTime.now().toIso8601String(),
      );

      final result = assembler.assemble(
        movie: testMovie,
        tasteProfile: emptyTaste,
      );

      expect(result.fullReason, isNotEmpty);
      expect(result.fullReason, contains('Dark City'));
      expect(result.matchingAspects, isNotEmpty);
    });
  });
}
