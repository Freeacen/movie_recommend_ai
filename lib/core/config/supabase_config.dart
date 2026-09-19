import 'local_secrets.dart';

class SupabaseConfig {
  SupabaseConfig._();

  // Project URL and Public Anon Key
  // Safe to be included in client apps (access is strictly guarded by PostgreSQL RLS)
  static const String defaultSupabaseUrl = 'https://ntnwaztcefqggawcydqq.supabase.co';
  static const String defaultSupabaseAnonKey = 'sb_publishable_QCi8XlcbSzZKSZcztLrlIA_L3Shi55u';

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
