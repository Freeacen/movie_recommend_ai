import 'local_secrets.dart';

class SupabaseConfig {
  SupabaseConfig._();

  // Project URL and Public Anon Key
  // Prioritizes environment variables, then local_secrets.dart
  static String get defaultSupabaseUrl {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return localSupabaseUrl;
  }

  static String get defaultSupabaseAnonKey {
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envKey.isNotEmpty) return envKey;
    return localSupabaseAnonKey;
  }

  // Groq API Key Rotation Pool
  // Prioritizes environment variable --dart-define=GROQ_API_KEY, then local_secrets.dart
  static List<String> get defaultGroqApiKeys {
    const envKey = String.fromEnvironment('GROQ_API_KEY');
    if (envKey.isNotEmpty) return [envKey];
    if (localGroqApiKey.isNotEmpty) return [localGroqApiKey];
    return [];
  }

  // Custom user override storage keys if needed
  static const String keySupabaseUrl = 'cineai_supabase_url';
  static const String keySupabaseAnonKey = 'cineai_supabase_anon_key';
  static const String keyDeviceCloudId = 'cineai_device_cloud_id';

  /// Check whether remote Supabase instance is actively configured
  static bool get isConfigured {
    return defaultSupabaseUrl.isNotEmpty && 
           !defaultSupabaseUrl.contains('YOUR_PROJECT_REF') &&
           defaultSupabaseAnonKey.isNotEmpty &&
           !defaultSupabaseAnonKey.contains('YOUR_SUPABASE');
  }

  /// Edge function AI proxy endpoint URL
  static String get edgeFunctionProxyUrl {
    return '$defaultSupabaseUrl/functions/v1/movie-ai-proxy';
  }
}
