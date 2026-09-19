import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database factory for desktop platforms
  static void initializeFfiIfNeeded() {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    } catch (_) {}
  }

  Future<Database> _initDatabase() async {
    initializeFfiIfNeeded();

    String dbPath = inMemoryDatabasePath;
    try {
      if (kIsWeb) {
        throw UnsupportedError('Web uses in-memory repository store');
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        try {
          final docDir = await getApplicationSupportDirectory();
          dbPath = join(docDir.path, 'movie_recommend_ai.db');
        } catch (e) {
          debugPrint('Path provider unavailable, using local or in-memory DB: $e');
          dbPath = 'movie_recommend_ai.db';
        }
      } else {
        try {
          final defaultDatabasesPath = await getDatabasesPath();
          dbPath = join(defaultDatabasesPath, 'movie_recommend_ai.db');
        } catch (_) {
          dbPath = 'movie_recommend_ai.db';
        }
      }
    } catch (_) {
      dbPath = inMemoryDatabasePath;
    }

    try {
      return await openDatabase(
        dbPath,
        version: 1,
        onCreate: _onCreate,
      );
    } catch (e) {
      debugPrint('Warning: Database open failed for $dbPath ($e). Falling back to in-memory database.');
      try {
        return await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: _onCreate,
        );
      } catch (e2) {
        debugPrint('Critical: In-memory openDatabase also failed ($e2).');
        rethrow;
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Movies table
    await db.execute('''
      CREATE TABLE movies (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        overview TEXT,
        poster_path TEXT,
        backdrop_path TEXT,
        release_date TEXT,
        vote_average REAL,
        genres TEXT,
        status TEXT NOT NULL,
        initial_proposed_at TEXT,
        recommended_at TEXT,
        user_rating REAL,
        rating_source TEXT,
        liked_aspects TEXT,
        disliked_aspects TEXT,
        user_review TEXT,
        reviewed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. User taste profile table
    await db.execute('''
      CREATE TABLE user_taste_profile (
        id INTEGER PRIMARY KEY DEFAULT 1,
        liked_themes TEXT,
        disliked_themes TEXT,
        preferred_genres TEXT,
        last_updated TEXT
      )
    ''');

    // Initial default profile
    await db.rawInsert('''
      INSERT INTO user_taste_profile (id, liked_themes, disliked_themes, preferred_genres, last_updated)
      VALUES (1, '[]', '[]', '[]', '${DateTime.now().toIso8601String()}')
    ''');

    // 3. Chat messages table
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        sender TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        related_movie_id INTEGER,
        message_type TEXT,
        options TEXT,
        FOREIGN KEY(related_movie_id) REFERENCES movies(id)
      )
    ''');
  }

  /// Reset database for testing or fresh start
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('movies');
    await db.delete('chat_messages');
    await db.update(
      'user_taste_profile',
      {
        'liked_themes': '[]',
        'disliked_themes': '[]',
        'preferred_genres': '[]',
        'last_updated': DateTime.now().toIso8601String(),
      },
      where: 'id = 1',
    );
  }
}
