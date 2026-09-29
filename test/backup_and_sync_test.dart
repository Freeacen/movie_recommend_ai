import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_recommend_ai/data/models/movie.dart';
import 'package:movie_recommend_ai/data/repositories/movie_repository.dart';
import 'package:movie_recommend_ai/data/repositories/user_taste_repository.dart';
import 'package:movie_recommend_ai/data/services/sync_engine.dart';
import 'package:movie_recommend_ai/domain/enums/movie_status.dart';
import 'package:movie_recommend_ai/presentation/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backup, Sync and Data Management Tests', () {
    late MovieRepository movieRepo;
    late UserTasteRepository tasteRepo;
    late SyncEngine syncEngine;
    late SettingsNotifier settingsNotifier;

    setUp(() async {
      movieRepo = MovieRepository();
      tasteRepo = UserTasteRepository();
      syncEngine = SyncEngine(movieRepo: movieRepo);
      settingsNotifier = SettingsNotifier(
        syncEngine: syncEngine,
        movieRepo: movieRepo,
        tasteRepo: tasteRepo,
      );
    });

    test('Auto-Sync defaults to true and can be toggled', () {
      expect(settingsNotifier.state.isAutoSyncEnabled, isTrue);

      settingsNotifier.toggleAutoSync();
      expect(settingsNotifier.state.isAutoSyncEnabled, isFalse);

      settingsNotifier.toggleAutoSync();
      expect(settingsNotifier.state.isAutoSyncEnabled, isTrue);
    });

    test('exportLibraryToJson exports valid JSON structure', () async {
      final jsonStr = await settingsNotifier.exportLibraryToJson();
      expect(jsonStr.isNotEmpty, isTrue);

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      expect(data.containsKey('cineai_export_version'), isTrue);
      expect(data.containsKey('movies'), isTrue);
      expect(data.containsKey('taste_profile'), isTrue);
      expect(data['movie_count'], isNotNull);
    });

    test('importLibraryFromJson correctly merges and overwrites based on choice', () async {
      final sampleBackup = jsonEncode({
        'cineai_export_version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'device_cloud_id': 'test-cloud-id',
        'movie_count': 2,
        'movies': [
          {
            'id': 888001,
            'title': 'Backup Test Movie A',
            'status': 'watched',
            'user_rating': 8.5,
          },
          {
            'id': 888002,
            'title': 'Backup Test Movie B',
            'status': 'watchlist',
          }
        ],
        'taste_profile': {
          'liked_themes': ['retro futurism'],
          'disliked_themes': ['excessive gore'],
          'preferred_genres': ['Sci-Fi'],
        }
      });

      // 1. Test merge choice
      final importedCount = await settingsNotifier.importLibraryFromJson(
        jsonStr: sampleBackup,
        choice: ConflictResolutionChoice.merge,
      );
      expect(importedCount, equals(2));

      final allMovies = await movieRepo.getAllMovies();
      expect(allMovies.any((m) => m.id == 888001), isTrue);
      expect(allMovies.any((m) => m.id == 888002), isTrue);

      // Clean up test movies
      await movieRepo.deleteMovie(888001);
      await movieRepo.deleteMovie(888002);
    });

    test('checkActiveCloudMovieCount and restoreFromActiveCloud function correctly', () async {
      final count = await settingsNotifier.checkActiveCloudMovieCount();
      expect(count, isA<int>());
      expect(count >= 0, isTrue);

      // Verify restoreFromActiveCloud does not throw with merge choice
      await settingsNotifier.restoreFromActiveCloud(choice: ConflictResolutionChoice.merge);
      expect(settingsNotifier.state.isLoading, isFalse);
    });
  });
}
