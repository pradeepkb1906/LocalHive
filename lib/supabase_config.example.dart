/// Template for the Supabase read-only mirror.
///
/// Copy this file to lib/supabase_config.dart and fill in the two values from
/// Supabase dashboard → Project Settings → Data API:
///   url      = Project URL,      e.g. https://abcdefgh.supabase.co
///   anonKey  = the `anon` `public` API key
///
/// Both are public client identifiers — the anon key is designed to be
/// shipped in a client, exactly like the Firebase web API key — but
/// lib/supabase_config.dart is gitignored anyway, because the org secret
/// scanner flags anything key-shaped.
///
/// Leave the values empty and the mirror is simply switched off: the app
/// behaves exactly as it does today, with Firestore as the only source.
library;

class SupabaseConfig {
  static const url = '';
  static const anonKey = '';

  /// The mirror only turns on once both values are present.
  static bool get enabled => url.isNotEmpty && anonKey.isNotEmpty;
}
