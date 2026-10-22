class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY kosong. '
        'Jalankan: flutter run --dart-define-from-file=env.json',
      );
    }
  }
}
