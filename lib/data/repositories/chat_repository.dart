import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/local_storage.dart';
import '../models/chat_message.dart';
import 'movie_repository.dart';

class ChatRepository {
  final AppDatabase _appDb;
  final MovieRepository _movieRepo;

  static final List<ChatMessage> _memoryMessages = [];
  static bool _hasLoadedFromStorage = false;

  ChatRepository({AppDatabase? appDb, MovieRepository? movieRepo})
      : _appDb = appDb ?? AppDatabase.instance,
        _movieRepo = movieRepo ?? MovieRepository(appDb: appDb);

  Future<Database?> _getSafeDb() async {
    if (kIsWeb) return null;
    try {
      return await _appDb.database.timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      return null;
    }
  }

  void _loadFromStorageIfNeeded() {
    if (_hasLoadedFromStorage) return;
    _hasLoadedFromStorage = true;
    try {
      final jsonStr = LocalStorageHelper.getItem(LocalStorageHelper.keyChatMessages);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        for (final item in list) {
          final msg = ChatMessage.fromMap(Map<String, dynamic>.from(item));
          if (!_memoryMessages.any((m) => m.id == msg.id)) {
            _memoryMessages.add(msg);
          }
        }
      }
    } catch (_) {}
  }

  void _saveToStorage() {
    try {
      final list = _memoryMessages.map((m) => m.toMap()).toList();
      LocalStorageHelper.setItem(LocalStorageHelper.keyChatMessages, jsonEncode(list));
    } catch (_) {}
  }

  /// Load all chat messages ordered by timestamp ascending
  Future<List<ChatMessage>> getMessages() async {
    _loadFromStorageIfNeeded();
    try {
      final db = await _getSafeDb();
      if (db != null) {
        final results = await db.query(
          'chat_messages',
          orderBy: 'timestamp ASC',
        );

        final messages = <ChatMessage>[];
        for (final row in results) {
          final msg = ChatMessage.fromMap(row);
          if (msg.relatedMovieId != null) {
            final movie = await _movieRepo.getMovieById(msg.relatedMovieId!);
            messages.add(msg.copyWith(attachedMovie: movie));
          } else {
            messages.add(msg);
          }
        }
        if (messages.isNotEmpty) {
          _memoryMessages.clear();
          _memoryMessages.addAll(messages);
          _saveToStorage();
          return messages;
        }
      }
    } catch (e) {
      debugPrint('getMessages safe memory fallback: $e');
    }
    return List.from(_memoryMessages);
  }

  /// Save single message to SQLite and memory
  Future<void> saveMessage(ChatMessage message) async {
    _memoryMessages.removeWhere((m) => m.id == message.id);
    _memoryMessages.add(message);
    _saveToStorage();

    try {
      final db = await _getSafeDb();
      if (db != null) {
        await db.insert(
          'chat_messages',
          message.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('saveMessage SQLite sync error (safe in memory): $e');
    }
  }

  /// Clear all chat history
  Future<void> clearChat() async {
    _memoryMessages.clear();
    try {
      LocalStorageHelper.setItem(LocalStorageHelper.keyChatMessages, '');
    } catch (_) {}
    try {
      final db = await _getSafeDb();
      if (db != null) {
        await db.delete('chat_messages');
      }
    } catch (_) {}
  }
}
