import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client singleton and helper methods.
class SupabaseService {
  SupabaseService._();

  static const _url = 'https://delknimidhqermqjlfja.supabase.co';
  static const _anonKey =
      'sb_publishable_ATMMxw1bEICrfw2MdFN6hw_DvLjc5V1';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isSignedIn => currentUser != null;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<AuthResponse> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => client.auth.signOut();

  static Future<void> sendPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(email);

  // ── Profile ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchProfile(String userId) =>
      client.from('profiles').select().eq('id', userId).maybeSingle();

  static Future<void> upsertProfile(Map<String, dynamic> data) =>
      client.from('profiles').upsert(data);

  // ── Sync helpers ─────────────────────────────────────────────────────────
  // These will be fleshed out once auth + profile flow is stable.

  static Future<void> upsertMission(Map<String, dynamic> data) =>
      client.from('missions').upsert(data);

  static Future<void> upsertChecklist(List<Map<String, dynamic>> rows) =>
      client.from('checklist_items').upsert(rows);

  static Future<void> upsertFlightLog(Map<String, dynamic> data) =>
      client.from('flight_logs').upsert(data);
}
