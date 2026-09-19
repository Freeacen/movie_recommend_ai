class ApiConstants {
  // TMDB API constants
  static const String defaultTmdbApiKey = '3c0b5093d8658b3bea645bad32e80924';
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
