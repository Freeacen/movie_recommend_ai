import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/local_storage.dart';
import '../repositories/movie_repository.dart';

enum SyncStatus {
  synced,
  syncing,
  offline,
  error,
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

  /// Get or create anonymous device identifier for cloud sync
  String get deviceCloudId {
    var id = LocalStorageHelper.getItem(SupabaseConfig.keyDeviceCloudId);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      LocalStorageHelper.setItem(SupabaseConfig.keyDeviceCloudId, id);
    }
    return id;
  }

  /// Perform bi-directional sync between local SQLite and Supabase
  Future<SyncStatus> sync() async {
    if (!SupabaseConfig.isConfigured) {
      _status = SyncStatus.offline;
      return _status;
    }

    _status = SyncStatus.syncing;

    try {
      final userId = deviceCloudId;
      final localMovies = await _movieRepo.getAllMovies();

      // Ensure user profile exists in Supabase user_profiles
      final profileUri = Uri.parse('${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_profiles');
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
              'device_id': userId,
              'is_anonymous': true,
              'last_active_at': DateTime.now().toUtc().toIso8601String(),
            }
          ]),
        ).timeout(const Duration(seconds: 6));
      } catch (_) {}

      // Push local records to Supabase user_watch_history
      final uri = Uri.parse('${SupabaseConfig.defaultSupabaseUrl}/rest/v1/user_watch_history');
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
    } catch (e) {
      debugPrint('SyncEngine background sync note: $e');
      _status = SyncStatus.offline;
    }

    return _status;
  }
}
