import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/local_storage.dart';
import '../../domain/enums/movie_status.dart';
import '../models/movie.dart';
import '../repositories/movie_repository.dart';

enum SyncStatus {
  synced,
  syncing,
  offline,
  error,
}

enum ConflictResolutionChoice {
  deviceWins, // Delete cloud movies, upload device movies
  cloudWins,  // Delete device movies, download cloud movies
  merge,      // Merge both, device rating/date wins on conflict
}

class AccountCheckResult {
  final bool hasConflict;
  final String cloudUserId;
  final String email;
  final int cloudMovieCount;
  final int localMovieCount;

  const AccountCheckResult({
    required this.hasConflict,
    required this.cloudUserId,
    required this.email,
    required this.cloudMovieCount,
    required this.localMovieCount,
  });
}

class SyncEngine {
  final MovieRepository _movieRepo;
  final http.Client _client;
  final _uuid = const Uuid();

  SyncStatus _status = SyncStatus.synced;
  DateTime? _lastSyncTime;

  SyncEngine({
    required MovieRepository movieRepo,
    http.Client? client,
  })  : _movieRepo = movieRepo,
        _client = client ?? http.Client();

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;

  static const String keyAutoSyncEnabled = 'cineai_auto_sync_enabled';
  bool? _autoSyncEnabled;

  bool get isAutoSyncEnabled {
    if (_autoSyncEnabled != null) return _autoSyncEnabled!;
    final val = LocalStorageHelper.getItem(keyAutoSyncEnabled);
    _autoSyncEnabled = val != 'false';
    return _autoSyncEnabled!;
  }

  void setAutoSyncEnabled(bool enabled) {
    _autoSyncEnabled = enabled;
    LocalStorageHelper.setItem(keyAutoSyncEnabled, enabled ? 'true' : 'false');
  }

  /// Get or create anonymous device identifier for cloud sync
  String get deviceCloudId {
    var id = LocalStorageHelper.getItem(SupabaseConfig.keyDeviceCloudId);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      LocalStorageHelper.setItem(SupabaseConfig.keyDeviceCloudId, id);
    }
    return id;
  }

  /// Generate and store a fresh anonymous device cloud ID
  String resetDeviceCloudId() {
    final newId = _uuid.v4();
    LocalStorageHelper.setItem(SupabaseConfig.keyDeviceCloudId, newId);
    return newId;
  }

  String? get currentEmail => LocalStorageHelper.getItem(LocalStorageHelper.keyUserEmail);
  String? get currentUserName => LocalStorageHelper.getItem(LocalStorageHelper.keyUserName);
  String? get currentAccountUserId => LocalStorageHelper.getItem(LocalStorageHelper.keyAccountUserId);
  String? get currentAvatarUrl => LocalStorageHelper.getItem(LocalStorageHelper.keyUserAvatar);
  bool get isLoggedIn => currentEmail != null && currentEmail!.trim().isNotEmpty;

  String get activeUserId {
    final accountId = currentAccountUserId;
    if (accountId != null && accountId.isNotEmpty) {
      return accountId;
    }
    return deviceCloudId;
  }

  /// Delete all watch history for active user/device from Supabase cloud
  Future<void> deleteUserDataFromCloud() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final userId = activeUserId;
      final uri = Uri.parse(
        '${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_watch_history?user_id=eq.$userId',
      );
      await _client.delete(
        uri,
        headers: {
          'apikey': SupabaseConfig.defaultSupabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 8));

      // Also clean user_profiles if anonymous
      if (!isLoggedIn) {
        final profileUri = Uri.parse(
          '${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_profiles?id=eq.$userId',
        );
        await _client.delete(
          profileUri,
          headers: {
            'apikey': SupabaseConfig.defaultSupabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
          },
        ).timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      debugPrint('deleteUserDataFromCloud error: $e');
    }
  }

  /// Fetch movies from a specified cloud ID (for cross-device cloud ID import)
  Future<List<Movie>> fetchCloudMoviesByCloudId(String targetCloudId) async {
    return _fetchCloudMovies(targetCloudId.trim());
  }

  /// Check account status for login & detect cross-device conflicts
  Future<AccountCheckResult> checkAccount(
    String identifier, {
    String? username,
    String? password,
  }) async {
    final cleanInput = identifier.trim();
    final isEmail = cleanInput.contains('@');
    var cleanEmail = isEmail ? cleanInput.toLowerCase() : '';
    final localMovies = await _movieRepo.getAllMovies();

    if (username != null && username.isNotEmpty) {
      LocalStorageHelper.setItem(LocalStorageHelper.keyUserName, username.trim());
    }
    if (password != null && password.isNotEmpty) {
      LocalStorageHelper.setItem(LocalStorageHelper.keyUserPassword, password);
    }

    if (!SupabaseConfig.isConfigured || cleanInput.isEmpty) {
      if (cleanEmail.isNotEmpty) {
        LocalStorageHelper.setItem(LocalStorageHelper.keyUserEmail, cleanEmail);
      }
      LocalStorageHelper.setItem(LocalStorageHelper.keyAccountUserId, deviceCloudId);
      return AccountCheckResult(
        hasConflict: false,
        cloudUserId: deviceCloudId,
        email: cleanEmail,
        cloudMovieCount: 0,
        localMovieCount: localMovies.length,
      );
    }

    try {
      final queryParam = isEmail ? 'email=eq.$cleanEmail' : 'display_name=eq.$cleanInput';
      final profileUri = Uri.parse(
        '${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_profiles?$queryParam&select=id,device_id,email,display_name',
      );
      final profileRes = await _client.get(
        profileUri,
        headers: {
          'apikey': SupabaseConfig.defaultSupabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 6));

      if (profileRes.statusCode == 200) {
        final profiles = jsonDecode(profileRes.body) as List<dynamic>;
        if (profiles.isNotEmpty) {
          final cloudUserId = profiles.first['id'].toString();
          final previousDeviceId = profiles.first['device_id']?.toString();
          final foundEmail = profiles.first['email']?.toString();
          final foundName = profiles.first['display_name']?.toString();

          if (foundEmail != null && foundEmail.isNotEmpty) {
            cleanEmail = foundEmail;
          }
          if (foundName != null && foundName.isNotEmpty) {
            LocalStorageHelper.setItem(LocalStorageHelper.keyUserName, foundName);
          }

          // Query cloud movies count
          final historyUri = Uri.parse(
            '${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_watch_history?user_id=eq.$cloudUserId&select=movie_id',
          );
          final historyRes = await _client.get(
            historyUri,
            headers: {
              'apikey': SupabaseConfig.defaultSupabaseAnonKey,
              'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
            },
          ).timeout(const Duration(seconds: 6));

          int cloudCount = 0;
          if (historyRes.statusCode == 200) {
            final historyData = jsonDecode(historyRes.body) as List<dynamic>;
            cloudCount = historyData.length;
          }

          final isDifferentDevice = previousDeviceId != null &&
              previousDeviceId.isNotEmpty &&
              previousDeviceId != deviceCloudId;
          final hasConflict = isDifferentDevice && cloudCount > 0 && localMovies.isNotEmpty;

          if (!hasConflict) {
            if (cleanEmail.isNotEmpty) {
              LocalStorageHelper.setItem(LocalStorageHelper.keyUserEmail, cleanEmail);
            }
            LocalStorageHelper.setItem(LocalStorageHelper.keyAccountUserId, cloudUserId);

            if (localMovies.isEmpty && cloudCount > 0) {
              await _pullAndReplaceFromCloud(cloudUserId);
            } else {
              await sync();
            }
          }

          return AccountCheckResult(
            hasConflict: hasConflict,
            cloudUserId: cloudUserId,
            email: cleanEmail,
            cloudMovieCount: cloudCount,
            localMovieCount: localMovies.length,
          );
        }
      }

      // Brand new account: link immediately to current device
      if (cleanEmail.isNotEmpty) {
        LocalStorageHelper.setItem(LocalStorageHelper.keyUserEmail, cleanEmail);
      }
      LocalStorageHelper.setItem(LocalStorageHelper.keyAccountUserId, deviceCloudId);
      await _registerProfileInCloud(deviceCloudId, cleanEmail, username ?? cleanInput);
      await sync();

      return AccountCheckResult(
        hasConflict: false,
        cloudUserId: deviceCloudId,
        email: cleanEmail,
        cloudMovieCount: 0,
        localMovieCount: localMovies.length,
      );
    } catch (e) {
      debugPrint('checkAccount error: $e');
      if (cleanEmail.isNotEmpty) {
        LocalStorageHelper.setItem(LocalStorageHelper.keyUserEmail, cleanEmail);
      }
      LocalStorageHelper.setItem(LocalStorageHelper.keyAccountUserId, deviceCloudId);
      return AccountCheckResult(
        hasConflict: false,
        cloudUserId: deviceCloudId,
        email: cleanEmail,
        cloudMovieCount: 0,
        localMovieCount: localMovies.length,
      );
    }
  }

  /// Resolve conflict based on user's explicit choice
  Future<void> resolveConflict({
    required ConflictResolutionChoice choice,
    required String cloudUserId,
    required String email,
    String? username,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isNotEmpty) {
      LocalStorageHelper.setItem(LocalStorageHelper.keyUserEmail, cleanEmail);
    }
    if (username != null && username.isNotEmpty) {
      LocalStorageHelper.setItem(LocalStorageHelper.keyUserName, username);
    }
    LocalStorageHelper.setItem(LocalStorageHelper.keyAccountUserId, cloudUserId);

    switch (choice) {
      case ConflictResolutionChoice.deviceWins:
        // 1. Delete all movies in cloud for cloudUserId
        try {
          final delUri = Uri.parse(
            '${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_watch_history?user_id=eq.$cloudUserId',
          );
          await _client.delete(
            delUri,
            headers: {
              'apikey': SupabaseConfig.defaultSupabaseAnonKey,
              'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
            },
          ).timeout(const Duration(seconds: 8));
        } catch (_) {}

        // 2. Upload current device movies to cloud
        await _registerProfileInCloud(cloudUserId, cleanEmail);
        await sync();
        break;

      case ConflictResolutionChoice.cloudWins:
        // 1. Pull all movies from cloud and replace local library
        await _pullAndReplaceFromCloud(cloudUserId);
        // 2. Update device ID in profile
        await _registerProfileInCloud(cloudUserId, cleanEmail);
        _lastSyncTime = DateTime.now();
        _status = SyncStatus.synced;
        break;

      case ConflictResolutionChoice.merge:
        // 1. Fetch cloud movies
        final cloudMovies = await _fetchCloudMovies(cloudUserId);
        final localMovies = await _movieRepo.getAllMovies();

        // 2. Merge: cloud movies first, then local movies overwrite duplicates (device rating/date wins!)
        final mergedMap = <int, Movie>{};
        for (final cm in cloudMovies) {
          mergedMap[cm.id] = cm;
        }
        for (final lm in localMovies) {
          mergedMap[lm.id] = lm;
        }

        // 3. Save merged list locally and push to cloud
        final mergedList = mergedMap.values.toList();
        await _movieRepo.replaceAllMovies(mergedList);
        await _registerProfileInCloud(cloudUserId, cleanEmail);
        await sync();
        break;
    }
  }

  /// Update user profile details (display name, email, avatar) and push to Supabase
  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    if (displayName != null) {
      LocalStorageHelper.setItem(LocalStorageHelper.keyUserName, displayName.trim());
    }
    if (email != null) {
      LocalStorageHelper.setItem(LocalStorageHelper.keyUserEmail, email.trim().toLowerCase());
    }
    if (clearAvatar) {
      LocalStorageHelper.removeItem(LocalStorageHelper.keyUserAvatar);
    } else if (avatarUrl != null) {
      LocalStorageHelper.setItem(LocalStorageHelper.keyUserAvatar, avatarUrl.trim());
    }

    await _registerProfileInCloud(
      activeUserId,
      email ?? currentEmail,
      displayName ?? currentUserName,
    );
  }

  /// Logout from account and return to anonymous device profile
  Future<void> logout() async {
    LocalStorageHelper.setItem(LocalStorageHelper.keyUserEmail, '');
    LocalStorageHelper.setItem(LocalStorageHelper.keyUserPassword, '');
    LocalStorageHelper.setItem(LocalStorageHelper.keyAccountUserId, '');
    _status = SyncStatus.synced;
  }

  Future<List<Movie>> _fetchCloudMovies(String userId) async {
    if (!SupabaseConfig.isConfigured) return [];
    try {
      final uri = Uri.parse(
        '${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_watch_history?user_id=eq.$userId',
      );
      final res = await _client.get(
        uri,
        headers: {
          'apikey': SupabaseConfig.defaultSupabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((item) => _movieFromCloudRow(Map<String, dynamic>.from(item))).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _pullAndReplaceFromCloud(String userId) async {
    final cloudMovies = await _fetchCloudMovies(userId);
    if (cloudMovies.isNotEmpty) {
      await _movieRepo.replaceAllMovies(cloudMovies);
    }
  }

  Future<void> _registerProfileInCloud(String userId, [String? email, String? displayName]) async {
    if (!SupabaseConfig.isConfigured) return;
    final profileUri = Uri.parse('${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_profiles?on_conflict=id');
    final name = displayName ?? currentUserName;
    final userMail = email ?? currentEmail;
    try {
      await _client.post(
        profileUri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.defaultSupabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode([
          {
            'id': userId,
            'device_id': deviceCloudId,
            'is_anonymous': (userMail == null || userMail.isEmpty) && (name == null || name.isEmpty),
            if (userMail != null && userMail.isNotEmpty) 'email': userMail,
            if (name != null && name.isNotEmpty) 'display_name': name,
            'last_active_at': DateTime.now().toUtc().toIso8601String(),
          }
        ]),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Movie _movieFromCloudRow(Map<String, dynamic> row) {
    MovieStatus parseStatus(String? s) {
      switch (s) {
        case 'watched': return MovieStatus.watched;
        case 'watchlist': return MovieStatus.watchlist;
        case 'recommended': return MovieStatus.recommended;
        default: return MovieStatus.none;
      }
    }

    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return Movie(
      id: (row['movie_id'] as num).toInt(),
      title: row['movie_title']?.toString() ?? '',
      posterPath: row['poster_path']?.toString(),
      genres: row['genres']?.toString(),
      status: parseStatus(row['status']?.toString()),
      userRating: (row['user_rating'] as num?)?.toDouble(),
      ratingSource: row['rating_source']?.toString(),
      likedAspects: parseList(row['liked_aspects']),
      dislikedAspects: parseList(row['disliked_aspects']),
      userReview: row['user_review']?.toString(),
      reviewed: row['reviewed'] == true,
      initialProposedAt: row['initial_proposed_at']?.toString(),
      recommendedAt: row['recommended_at']?.toString(),
    );
  }

  /// Perform bi-directional sync between local SQLite and Supabase
  Future<SyncStatus> sync({bool isManual = false}) async {
    if (!SupabaseConfig.isConfigured) {
      _status = SyncStatus.offline;
      return _status;
    }

    // If auto sync is disabled and this is not a manual sync, skip
    if (!isAutoSyncEnabled && !isManual) {
      return _status;
    }

    _status = SyncStatus.syncing;

    try {
      final userId = activeUserId;
      final localMovies = await _movieRepo.getAllMovies();

      // Ensure user profile exists in Supabase user_profiles
      await _registerProfileInCloud(userId, currentEmail);

      // Push local records to Supabase user_watch_history
      final uri = Uri.parse('${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_watch_history?on_conflict=user_id,movie_id');
      final payload = localMovies.map((m) {
        return {
          'user_id': userId,
          'movie_id': m.id,
          'movie_title': m.title,
          'poster_path': m.posterPath,
          'genres': m.genres,
          'status': m.status.name,
          'user_rating': m.userRating,
          'rating_source': m.ratingSource,
          'liked_aspects': m.likedAspects,
          'disliked_aspects': m.dislikedAspects,
          'user_review': m.userReview,
          'reviewed': m.reviewed,
          // CRITICAL: Strictly preserve original recommendation & proposal timestamps!
          'initial_proposed_at': m.initialProposedAt,
          'recommended_at': m.recommendedAt,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
      }).toList();

      if (payload.isNotEmpty) {
        final response = await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.defaultSupabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _status = SyncStatus.synced;
          _lastSyncTime = DateTime.now();
        } else {
          _status = SyncStatus.error;
        }
      } else {
        _status = SyncStatus.synced;
        _lastSyncTime = DateTime.now();
      }

      // Çift Yönlü Eşitleme (Two-Way Sync):
      // Buluttaki filmleri çekip cihazda henüz bulunmayanları güvenle yerel SQLite'a ekle
      if (_status == SyncStatus.synced) {
        final cloudMovies = await _fetchCloudMovies(userId);
        if (cloudMovies.isNotEmpty) {
          final localIdMap = {for (final m in localMovies) m.id: m};
          bool hasNewCloudMovies = false;
          final mergedList = List<Movie>.from(localMovies);

          for (final cm in cloudMovies) {
            if (!localIdMap.containsKey(cm.id)) {
              mergedList.add(cm);
              hasNewCloudMovies = true;
            }
          }

          if (hasNewCloudMovies) {
            await _movieRepo.replaceAllMovies(mergedList);
          }
        }
      }
    } catch (e) {
      debugPrint('SyncEngine background sync note: $e');
      _status = SyncStatus.offline;
    }

    return _status;
  }

  /// Resolve conflict when importing movies from another cloud ID
  Future<void> resolveCloudIdImport({
    required String targetCloudId,
    required ConflictResolutionChoice choice,
  }) async {
    final cleanTargetId = targetCloudId.trim();
    final cloudMovies = await _fetchCloudMovies(cleanTargetId);

    switch (choice) {
      case ConflictResolutionChoice.merge:
        final localMovies = await _movieRepo.getAllMovies();
        final mergedMap = <int, Movie>{};
        for (final cm in cloudMovies) {
          mergedMap[cm.id] = cm;
        }
        for (final lm in localMovies) {
          mergedMap[lm.id] = lm;
        }
        final mergedList = mergedMap.values.toList();
        await _movieRepo.replaceAllMovies(mergedList);
        await sync(isManual: true);
        break;

      case ConflictResolutionChoice.deviceWins:
        // Delete target cloud movies and upload current device movies to target ID
        try {
          final delUri = Uri.parse(
            '${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_watch_history?user_id=eq.$cleanTargetId',
          );
          await _client.delete(
            delUri,
            headers: {
              'apikey': SupabaseConfig.defaultSupabaseAnonKey,
              'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
            },
          ).timeout(const Duration(seconds: 8));
        } catch (_) {}

        final localMovies = await _movieRepo.getAllMovies();
        final uri = Uri.parse('${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_watch_history?on_conflict=user_id,movie_id');
        final payload = localMovies.map((m) {
          return {
            'user_id': cleanTargetId,
            'movie_id': m.id,
            'movie_title': m.title,
            'poster_path': m.posterPath,
            'genres': m.genres,
            'status': m.status.name,
            'user_rating': m.userRating,
            'rating_source': m.ratingSource,
            'liked_aspects': m.likedAspects,
            'disliked_aspects': m.dislikedAspects,
            'user_review': m.userReview,
            'reviewed': m.reviewed,
            'initial_proposed_at': m.initialProposedAt,
            'recommended_at': m.recommendedAt,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
        }).toList();

        if (payload.isNotEmpty) {
          await _client.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.defaultSupabaseAnonKey,
              'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 10));
        }
        break;

      case ConflictResolutionChoice.cloudWins:
        if (cloudMovies.isNotEmpty) {
          await _movieRepo.replaceAllMovies(cloudMovies);
        }
        break;
    }
  }
}
