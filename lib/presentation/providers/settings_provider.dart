import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../data/repositories/movie_repository.dart';
import '../../data/repositories/user_taste_repository.dart';
import '../../data/services/backend_ai_service.dart';
import '../../data/services/dynamic_explanation_assembler.dart';
import '../../data/services/gemini_ai_service.dart';
import '../../data/services/sync_engine.dart';
import '../../data/services/tmdb_service.dart';

class SettingsState {
  final SyncStatus syncStatus;
  final String deviceCloudId;
  final bool isDarkMode;
  final bool isMockMode;
  final bool isLoading;

  const SettingsState({
    this.syncStatus = SyncStatus.synced,
    this.deviceCloudId = '',
    this.isDarkMode = true,
    this.isMockMode = false,
    this.isLoading = false,
  });

  // Deprecated backward compatibility getters
  String get tmdbApiKey => '';
  String get geminiApiKey => '';

  SettingsState copyWith({
    SyncStatus? syncStatus,
    String? deviceCloudId,
    bool? isDarkMode,
    bool? isMockMode,
    bool? isLoading,
  }) {
    return SettingsState(
      syncStatus: syncStatus ?? this.syncStatus,
      deviceCloudId: deviceCloudId ?? this.deviceCloudId,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isMockMode: isMockMode ?? this.isMockMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SyncEngine _syncEngine;
  final MovieRepository _movieRepo;
  final UserTasteRepository _tasteRepo;

  SettingsNotifier({
    required SyncEngine syncEngine,
    required MovieRepository movieRepo,
    required UserTasteRepository tasteRepo,
  })  : _syncEngine = syncEngine,
        _movieRepo = movieRepo,
        _tasteRepo = tasteRepo,
        super(SettingsState(
          syncStatus: syncEngine.status,
          deviceCloudId: syncEngine.deviceCloudId,
        ));

  /// Trigger background cloud sync between local SQLite and Supabase
  Future<void> triggerSync() async {
    state = state.copyWith(syncStatus: SyncStatus.syncing);
    final result = await _syncEngine.sync();
    state = state.copyWith(syncStatus: result);
  }

  void toggleTheme() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  Future<void> seedDemoData() async {
    state = state.copyWith(isLoading: true);
    await _movieRepo.seedDemoData();
    await _tasteRepo.appendPreferences(
      newLiked: ['kara delik fiziği', 'Hans Zimmer müzikleri', 'ters köşe kurgu'],
      newDisliked: ['klişe sonlar'],
      newGenres: ['Bilim Kurgu', 'Gerilim'],
    );
    state = state.copyWith(isLoading: false);
    // Background cloud sync
    triggerSync();
  }

  Future<void> resetAllData() async {
    state = state.copyWith(isLoading: true);
    await AppDatabase.instance.clearAllData();
    state = state.copyWith(isLoading: false);
  }
}

// ------------------------------------------------------------------------------
// Dependency Injection Providers
// ------------------------------------------------------------------------------
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final dynamicExplanationAssemblerProvider = Provider<DynamicExplanationAssembler>((ref) {
  return const DynamicExplanationAssembler();
});

final backendAiServiceProvider = Provider<BackendAiService>((ref) {
  final assembler = ref.watch(dynamicExplanationAssemblerProvider);
  return BackendAiService(assembler: assembler);
});

// Maintained for backward compatibility with existing tests
final geminiAiServiceProvider = Provider<GeminiAiService>((ref) {
  return GeminiAiService();
});

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService();
});

final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MovieRepository(appDb: db);
});

final userTasteRepositoryProvider = Provider<UserTasteRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserTasteRepository(appDb: db);
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final movieRepo = ref.watch(movieRepositoryProvider);
  return SyncEngine(movieRepo: movieRepo);
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(
    syncEngine: ref.watch(syncEngineProvider),
    movieRepo: ref.watch(movieRepositoryProvider),
    tasteRepo: ref.watch(userTasteRepositoryProvider),
  );
});
