class SupabaseConfig {
  const SupabaseConfig._();

  static const url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
}
