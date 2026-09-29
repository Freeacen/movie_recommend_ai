import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/config/supabase_config.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/local_storage.dart';
import '../../core/utils/platform_web_helper.dart';
import '../../data/models/movie.dart';
import '../../data/models/user_taste_profile.dart';
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
  final String? userEmail;
  final String? userName;
  final String? avatarUrl;
  final bool isLoggedIn;
  final bool isDarkMode;
  final bool isAnimationsEnabled;
  final bool isMockMode;
  final bool isLoading;
  final bool isAutoSyncEnabled;

  const SettingsState({
    this.syncStatus = SyncStatus.synced,
    this.deviceCloudId = '',
    this.userEmail,
    this.userName,
    this.avatarUrl,
    this.isLoggedIn = false,
    this.isDarkMode = true,
    this.isAnimationsEnabled = true,
    this.isMockMode = false,
    this.isLoading = false,
    this.isAutoSyncEnabled = true,
  });

  String get effectiveDisplayName {
    if (userName != null && userName!.trim().isNotEmpty) {
      return userName!.trim();
    }
    if (userEmail != null && userEmail!.trim().isNotEmpty) {
      final part = userEmail!.split('@').first;
      if (part.isNotEmpty) return part;
    }
    return 'Sinefil';
  }

  // Deprecated backward compatibility getters
  String get tmdbApiKey => '';
  String get geminiApiKey => '';

  SettingsState copyWith({
    SyncStatus? syncStatus,
    String? deviceCloudId,
    String? userEmail,
    String? userName,
    String? avatarUrl,
    bool clearAvatar = false,
    bool? isLoggedIn,
    bool? isDarkMode,
    bool? isAnimationsEnabled,
    bool? isMockMode,
    bool? isLoading,
    bool? isAutoSyncEnabled,
  }) {
    return SettingsState(
      syncStatus: syncStatus ?? this.syncStatus,
      deviceCloudId: deviceCloudId ?? this.deviceCloudId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isAnimationsEnabled: isAnimationsEnabled ?? this.isAnimationsEnabled,
      isMockMode: isMockMode ?? this.isMockMode,
      isLoading: isLoading ?? this.isLoading,
      isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
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
          userEmail: syncEngine.currentEmail,
          userName: syncEngine.currentUserName,
          avatarUrl: syncEngine.currentAvatarUrl,
          isLoggedIn: syncEngine.isLoggedIn,
          isDarkMode: LocalStorageHelper.getItem(LocalStorageHelper.keyDarkMode) != 'false',
          isAnimationsEnabled: LocalStorageHelper.getItem(LocalStorageHelper.keyAnimationsEnabled) != 'false',
          isAutoSyncEnabled: syncEngine.isAutoSyncEnabled,
        )) {
    // Automatically check if page loaded with an OAuth access token fragment
    checkAndProcessOAuthCallback();
  }

  /// Initiate Google OAuth in a popup window without leaving the app
  Future<bool> loginWithGooglePopup([String? redirectOrigin]) async {
    final origin = redirectOrigin ?? Uri.base.origin;
    final authUrl =
        '${SupabaseConfig.defaultSupabaseUrl}/auth/v1/authorize?provider=google&redirect_to=$origin';
    
    final hash = await PlatformWebHelper.openOAuthPopup(authUrl);
    if (hash == null || !hash.contains('access_token=')) {
      return false;
    }
    return _processTokenHash(hash);
  }

  /// Initiate Google OAuth full-page redirect flow via Supabase Auth (fallback)
  void initiateGoogleOAuth([String? redirectOrigin]) {
    final origin = redirectOrigin ?? Uri.base.origin;
    final authUrl =
        '${SupabaseConfig.defaultSupabaseUrl}/auth/v1/authorize?provider=google&redirect_to=$origin';
    PlatformWebHelper.redirectTo(authUrl);
  }

  /// Process OAuth callback fragment (#access_token=...&refresh_token=...) if present
  Future<bool> checkAndProcessOAuthCallback() async {
    final fragment = PlatformWebHelper.getUrlFragment();
    if (!fragment.contains('access_token=')) {
      return false;
    }

    final success = await _processTokenHash(fragment);
    PlatformWebHelper.clearUrlFragment();
    return success;
  }

  Future<bool> _processTokenHash(String fragment) async {
    state = state.copyWith(isLoading: true);
    try {
      final cleanFragment = fragment.startsWith('#') ? fragment.substring(1) : fragment;
      final params = Uri.splitQueryString(cleanFragment);
      final accessToken = params['access_token'];

      if (accessToken != null && accessToken.isNotEmpty) {
        // Query user info from Supabase Auth
        final userUri = Uri.parse('${SupabaseConfig.defaultSupabaseUrl}/auth/v1/user');
        final userRes = await http.get(
          userUri,
          headers: {
            'apikey': SupabaseConfig.defaultSupabaseAnonKey,
            'Authorization': 'Bearer $accessToken',
          },
        ).timeout(const Duration(seconds: 8));

        if (userRes.statusCode == 200) {
          final userData = jsonDecode(userRes.body) as Map<String, dynamic>;
          final email = userData['email']?.toString();
          final meta = userData['user_metadata'] as Map<String, dynamic>? ?? {};
          final fullName = meta['full_name']?.toString() ?? meta['name']?.toString();
          final avatar = meta['avatar_url']?.toString() ?? meta['picture']?.toString();

          // Connect account and register profile with authentic Google data
          if (email != null && email.isNotEmpty) {
            await _syncEngine.checkAccount(
              email,
              username: fullName,
            );
          }
          if (avatar != null && avatar.isNotEmpty) {
            await _syncEngine.updateProfile(
              avatarUrl: avatar,
              displayName: fullName,
            );
          }

          state = state.copyWith(
            isLoading: false,
            userEmail: _syncEngine.currentEmail,
            userName: _syncEngine.currentUserName,
            avatarUrl: _syncEngine.currentAvatarUrl,
            isLoggedIn: _syncEngine.isLoggedIn,
            syncStatus: _syncEngine.status,
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('OAuth token processing error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
    return false;
  }

  /// Update user avatar locally and in profile
  Future<void> updateAvatar(String? newAvatar) async {
    if (newAvatar == null || newAvatar.isEmpty) {
      await _syncEngine.updateProfile(clearAvatar: true);
      state = state.copyWith(clearAvatar: true);
    } else {
      await _syncEngine.updateProfile(avatarUrl: newAvatar);
      state = state.copyWith(avatarUrl: newAvatar);
    }
  }

  /// Update user display name locally and push to cloud
  Future<void> updateUserName(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    await _syncEngine.updateProfile(displayName: clean);
    state = state.copyWith(userName: clean);
  }

  /// Toggle automatic background cloud sync
  void toggleAutoSync() {
    final updated = !_syncEngine.isAutoSyncEnabled;
    _syncEngine.setAutoSyncEnabled(updated);
    state = state.copyWith(isAutoSyncEnabled: updated);
    if (updated) {
      triggerSync(isManual: true);
    }
  }

  /// Trigger cloud sync between local SQLite and Supabase
  Future<void> triggerSync({bool isManual = false}) async {
    state = state.copyWith(syncStatus: SyncStatus.syncing);
    final result = await _syncEngine.sync(isManual: isManual);
    state = state.copyWith(syncStatus: result);
  }

  /// Login with email or username and check for cross-device conflicts
  Future<AccountCheckResult> loginWithEmail(
    String email, {
    String? username,
    String? password,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _syncEngine.checkAccount(
      email,
      username: username,
      password: password,
    );
    state = state.copyWith(
      isLoading: false,
      userEmail: _syncEngine.currentEmail,
      userName: _syncEngine.currentUserName,
      avatarUrl: _syncEngine.currentAvatarUrl,
      isLoggedIn: _syncEngine.isLoggedIn,
      syncStatus: _syncEngine.status,
    );
    return result;
  }

  /// Resolve conflict based on user's choice
  Future<void> resolveConflict({
    required ConflictResolutionChoice choice,
    required String cloudUserId,
    required String email,
    String? username,
  }) async {
    state = state.copyWith(isLoading: true);
    await _syncEngine.resolveConflict(
      choice: choice,
      cloudUserId: cloudUserId,
      email: email,
      username: username,
    );
    state = state.copyWith(
      isLoading: false,
      userEmail: _syncEngine.currentEmail,
      userName: _syncEngine.currentUserName,
      avatarUrl: _syncEngine.currentAvatarUrl,
      isLoggedIn: _syncEngine.isLoggedIn,
      syncStatus: _syncEngine.status,
    );
  }

  /// Logout from account and revert to anonymous device profile
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _syncEngine.logout();
    state = state.copyWith(
      isLoading: false,
      userEmail: null,
      userName: _syncEngine.currentUserName,
      avatarUrl: _syncEngine.currentAvatarUrl,
      isLoggedIn: false,
      syncStatus: _syncEngine.status,
    );
  }

  void toggleTheme() {
    final next = !state.isDarkMode;
    LocalStorageHelper.setItem(LocalStorageHelper.keyDarkMode, next ? 'true' : 'false');
    state = state.copyWith(isDarkMode: next);
  }

  void toggleAnimations() {
    final next = !state.isAnimationsEnabled;
    LocalStorageHelper.setItem(LocalStorageHelper.keyAnimationsEnabled, next ? 'true' : 'false');
    state = state.copyWith(isAnimationsEnabled: next);
  }

  /// Export complete library and taste profile as JSON string
  Future<String> exportLibraryToJson() async {
    final movies = await _movieRepo.getAllMovies();
    final profile = await _tasteRepo.getUserTasteProfile();
    final map = {
      'cineai_export_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'device_cloud_id': state.deviceCloudId,
      'movie_count': movies.length,
      'movies': movies.map((m) => m.toMap()).toList(),
      'taste_profile': profile.toMap(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Import library from JSON string with user's conflict resolution choice
  Future<int> importLibraryFromJson({
    required String jsonStr,
    required ConflictResolutionChoice choice,
  }) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final rawList = data['movies'] as List<dynamic>? ?? [];
    final importedMovies = rawList.map((item) => Movie.fromMap(Map<String, dynamic>.from(item))).toList();

    if (data['taste_profile'] != null) {
      try {
        final rawProf = Map<String, dynamic>.from(data['taste_profile']);
        await _tasteRepo.appendPreferences(
          newLiked: (rawProf['liked_themes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          newDisliked: (rawProf['disliked_themes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          newGenres: (rawProf['preferred_genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        );
      } catch (_) {}
    }

    switch (choice) {
      case ConflictResolutionChoice.merge:
        final localMovies = await _movieRepo.getAllMovies();
        final mergedMap = <int, Movie>{};
        for (final im in importedMovies) {
          mergedMap[im.id] = im;
        }
        for (final lm in localMovies) {
          mergedMap[lm.id] = lm;
        }
        await _movieRepo.replaceAllMovies(mergedMap.values.toList());
        break;

      case ConflictResolutionChoice.deviceWins:
        // Cihaz öncelikli: Yalnızca cihazda bulunmayan yeni filmler eklenir
        final localMovies = await _movieRepo.getAllMovies();
        final localIds = localMovies.map((m) => m.id).toSet();
        final newOnes = importedMovies.where((m) => !localIds.contains(m.id)).toList();
        await _movieRepo.replaceAllMovies([...localMovies, ...newOnes]);
        break;

      case ConflictResolutionChoice.cloudWins:
        // Dosyadakileri geçerli kıl (Cihazı tamamen sil ve üzerine yaz)
        await _movieRepo.replaceAllMovies(importedMovies);
        break;
    }

    if (state.isAutoSyncEnabled) {
      await triggerSync(isManual: true);
    }
    return importedMovies.length;
  }

  /// Check movie count available under a target cloud ID
  Future<int> checkTargetCloudId(String targetCloudId) async {
    final list = await _syncEngine.fetchCloudMoviesByCloudId(targetCloudId);
    return list.length;
  }

  /// Check movie count available under active user's cloud backup
  Future<int> checkActiveCloudMovieCount() async {
    return checkTargetCloudId(_syncEngine.activeUserId);
  }

  /// Restore movies from active user's cloud backup with conflict resolution
  Future<void> restoreFromActiveCloud({
    required ConflictResolutionChoice choice,
  }) async {
    state = state.copyWith(isLoading: true);
    await _syncEngine.resolveCloudIdImport(
      targetCloudId: _syncEngine.activeUserId,
      choice: choice,
    );
    state = state.copyWith(isLoading: false);
  }

  /// Import movies from another device's cloud ID with conflict resolution
  Future<void> importFromCloudId({
    required String targetCloudId,
    required ConflictResolutionChoice choice,
  }) async {
    state = state.copyWith(isLoading: true);
    await _syncEngine.resolveCloudIdImport(
      targetCloudId: targetCloudId,
      choice: choice,
    );
    state = state.copyWith(isLoading: false);
  }

  /// Completely delete all local data AND remote Supabase cloud data, generating a fresh ID
  Future<void> clearAllDataAndCloud() async {
    state = state.copyWith(isLoading: true);
    await _syncEngine.deleteUserDataFromCloud();
    await AppDatabase.instance.clearAllData();
    await _movieRepo.replaceAllMovies([]);
    await _tasteRepo.resetProfile();
    final newId = _syncEngine.resetDeviceCloudId();
    state = state.copyWith(
      isLoading: false,
      deviceCloudId: newId,
      syncStatus: SyncStatus.synced,
    );
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
