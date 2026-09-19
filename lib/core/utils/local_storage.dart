import 'local_storage_stub.dart'
    if (dart.library.html) 'local_storage_web.dart';

class LocalStorageHelper {
  static const String keyGeminiApiKey = 'cineai_gemini_api_key';
  static const String keyTmdbApiKey = 'cineai_tmdb_api_key';
  static const String keyWatchedMovies = 'cineai_movies_store';
  static const String keyTasteProfile = 'cineai_taste_profile_store';
  static const String keyChatMessages = 'cineai_chat_messages_store';

  static String? getItem(String key) {
    return platformGetStorageItem(key);
  }

  static void setItem(String key, String value) {
    platformSetStorageItem(key, value);
  }
}
