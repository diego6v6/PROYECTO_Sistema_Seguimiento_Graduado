class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
  });

  final String supabaseUrl;
  final String supabaseKey;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    );
  }

  bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseKey.trim().isNotEmpty;
}
