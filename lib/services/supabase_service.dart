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

  // ── Org Members (Change 5) ────────────────────────────────────────────────

  /// Returns all user profiles that belong to [orgId].
  static Future<List<Map<String, dynamic>>> fetchOrgMembers(
      String orgId) async {
    final rows = await client
        .from('profiles')
        .select('id, name, email, role, license_verified, license_number')
        .eq('organization_id', orgId)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Updates the [role] field of a member in the remote profiles table.
  static Future<void> updateMemberRole(
          String userId, String role) =>
      client.from('profiles').update({'role': role}).eq('id', userId);

  /// Removes a member from the org by clearing their organization_id.
  static Future<void> removeOrgMember(String userId) => client
      .from('profiles')
      .update({'organization_id': ''}).eq('id', userId);

  // ── Concurrence Polling (Change 5) ───────────────────────────────────────

  /// Polls Supabase for the latest concurrence status of a mission.
  /// Used as the online polling fallback instead of Realtime subscriptions.
  static Future<String?> fetchRemoteConcurrenceStatus({
    required String missionRef,
    required String organizationId,
  }) async {
    try {
      final result = await client
          .from('missions')
          .select('crp_concurrence_status')
          .eq('mission_ref', missionRef)
          .eq('organization_id', organizationId)
          .maybeSingle();
      return result?['crp_concurrence_status'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Standalone Logs ───────────────────────────────────────────────────────

  static Future<void> upsertMaintenanceLogs(List<Map<String, dynamic>> rows) =>
      client.from('maintenance_logs').upsert(rows);

  static Future<void> upsertBatteryLogs(List<Map<String, dynamic>> rows) =>
      client.from('battery_logs').upsert(rows);

  static Future<void> upsertIncidentReports(List<Map<String, dynamic>> rows) =>
      client.from('incident_reports').upsert(rows);
}
