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

  // ── Missions ─────────────────────────────────────────────────────────────

  /// Upserts a mission and returns its Supabase UUID.
  /// Conflict key: (mission_ref, organization_id) — must be UNIQUE in schema.
  static Future<String> upsertMissionGetId(
      Map<String, dynamic> data) async {
    final result = await client
        .from('missions')
        .upsert(data, onConflict: 'mission_ref,organization_id')
        .select('id')
        .single();
    return result['id'] as String;
  }

  // ── Mission Crew ──────────────────────────────────────────────────────────

  /// Replaces all crew records for a mission (delete + insert).
  static Future<void> replaceCrewForMission(
      String missionUuid, List<Map<String, dynamic>> crew) async {
    await client
        .from('mission_crew')
        .delete()
        .eq('mission_id', missionUuid);
    if (crew.isNotEmpty) {
      await client.from('mission_crew').insert(crew);
    }
  }

  // ── HIRA Rows ─────────────────────────────────────────────────────────────

  /// Replaces all HIRA rows for a mission (delete + insert).
  static Future<void> replaceHiraRows(
      String missionUuid, List<Map<String, dynamic>> rows) async {
    await client
        .from('hira_rows')
        .delete()
        .eq('mission_id', missionUuid);
    if (rows.isNotEmpty) {
      await client.from('hira_rows').insert(rows);
    }
  }

  // ── Checklist Items ───────────────────────────────────────────────────────

  /// Replaces all checklist items for a mission (delete + insert).
  static Future<void> replaceChecklistItems(
      String missionUuid, List<Map<String, dynamic>> items) async {
    await client
        .from('checklist_items')
        .delete()
        .eq('mission_id', missionUuid);
    if (items.isNotEmpty) {
      await client.from('checklist_items').insert(items);
    }
  }

  // ── Flight Plans ──────────────────────────────────────────────────────────

  static Future<void> upsertFlightPlan(Map<String, dynamic> data) =>
      client
          .from('flight_plans')
          .upsert(data, onConflict: 'mission_id');

  // ── Fit-to-Fly Records ────────────────────────────────────────────────────

  static Future<void> upsertFitToFly(Map<String, dynamic> data) =>
      client
          .from('fit_to_fly_records')
          .upsert(data, onConflict: 'mission_id');

  // ── Flight Logs ───────────────────────────────────────────────────────────

  static Future<void> upsertFlightLog(Map<String, dynamic> data) =>
      client
          .from('flight_logs')
          .upsert(data, onConflict: 'mission_id');
}
