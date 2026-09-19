import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/local_storage.dart';
import '../models/user_taste_profile.dart';

class UserTasteRepository {
  final AppDatabase _appDb;

  static UserTasteProfile _memoryProfile = const UserTasteProfile(
    likedThemes: [
      'zamanda yolculuk ve paradokslar',
      'akıl yakan bilim kurgu',
      'kara delik fiziği ve görelilik',
      'Tarantino diyalogları',
      'rüya ve hafıza kurguları',
    ],
    dislikedThemes: ['klişe sonlar'],
    preferredGenres: ['Bilim Kurgu', 'Macera', 'Gerilim', 'Dram'],
    lastUpdated: '2025-12-04T00:00:00.000Z',
  );

  static bool _hasLoadedFromStorage = false;

  static void _loadFromStorageIfNeeded() {
    if (_hasLoadedFromStorage) return;
    _hasLoadedFromStorage = true;
    try {
      final jsonStr = LocalStorageHelper.getItem(LocalStorageHelper.keyTasteProfile);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _memoryProfile = UserTasteProfile.fromMap(map);
      }
    } catch (_) {}
  }

  static void _saveToStorage() {
    try {
      LocalStorageHelper.setItem(
        LocalStorageHelper.keyTasteProfile,
        jsonEncode(_memoryProfile.toMap()),
      );
    } catch (_) {}
  }

  UserTasteRepository({AppDatabase? appDb}) : _appDb = appDb ?? AppDatabase.instance;

  Future<Database?> _getSafeDb() async {
    _loadFromStorageIfNeeded();
    if (kIsWeb) return null;
    try {
      return await _appDb.database.timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      return null;
    }
  }

  /// Retrieve the current user taste profile
  Future<UserTasteProfile> getUserTasteProfile() async {
    _loadFromStorageIfNeeded();
    try {
      final db = await _getSafeDb();
      if (db != null) {
        final results = await db.query(
          'user_taste_profile',
          where: 'id = 1',
          limit: 1,
        );
        if (results.isNotEmpty) {
          _memoryProfile = UserTasteProfile.fromMap(results.first);
          _saveToStorage();
          return _memoryProfile;
        }
      }
    } catch (e) {
      debugPrint('getUserTasteProfile safe memory fallback: $e');
    }
    return _memoryProfile;
  }

  /// Update taste profile by appending newly learned aspects
  Future<UserTasteProfile> appendPreferences({
    List<String> newLiked = const [],
    List<String> newDisliked = const [],
    List<String> newGenres = const [],
  }) async {
    _loadFromStorageIfNeeded();
    final updatedLiked = <String>{..._memoryProfile.likedThemes, ...newLiked}.toList();
    final updatedDisliked = <String>{..._memoryProfile.dislikedThemes, ...newDisliked}.toList();
    final updatedGenres = <String>{..._memoryProfile.preferredGenres, ...newGenres}.toList();

    _memoryProfile = _memoryProfile.copyWith(
      likedThemes: updatedLiked,
      dislikedThemes: updatedDisliked,
      preferredGenres: updatedGenres,
      lastUpdated: DateTime.now().toIso8601String(),
    );
    _saveToStorage();

    try {
      final db = await _getSafeDb();
      if (db != null) {
        await db.update(
          'user_taste_profile',
          _memoryProfile.toMap(),
          where: 'id = 1',
        );
      }
    } catch (e) {
      debugPrint('appendPreferences SQLite sync error (safe in memory): $e');
    }

    return _memoryProfile;
  }
}
