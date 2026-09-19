import '../config/local_secrets.dart';

class ApiConstants {
  // TMDB API constants
  // Prioritizes --dart-define=TMDB_API_KEY, then local_secrets.dart
  static String get defaultTmdbApiKey {
    const envKey = String.fromEnvironment('TMDB_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return localTmdbApiKey;
  }

  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbImageBaseUrlW500 = 'https://image.tmdb.org/t/p/w500';
  static const String tmdbImageBaseUrlOriginal = 'https://image.tmdb.org/t/p/original';

  // Google Gemini API constants
  static const String geminiModel = 'gemini-3.6-flash';
  static const String geminiModelFallback = 'gemini-flash-latest';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  // SharedPreferences / Storage keys
  static const String keyTmdbApiKey = 'pref_tmdb_api_key';
  static const String keyGeminiApiKey = 'pref_gemini_api_key';
  static const String keyUseMockData = 'pref_use_mock_data';
}
