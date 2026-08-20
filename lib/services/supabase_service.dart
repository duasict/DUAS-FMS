import 'dart:io';
import 'package:flutter/foundation.dart';
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

  static Future<AuthResponse> signUp(String email, String password) =>
      client.auth.signUp(email: email, password: password);

  static Future<void> signOut() => client.auth.signOut();

  static Future<void> sendPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(email);

  // ── Profile ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchProfile(String userId) =>
      client.from('profiles').select().eq('id', userId).maybeSingle();

  static Future<void> upsertProfile(Map<String, dynamic> data) =>
      client.from('profiles').upsert(data);

  /// Creates a new organization row and returns its Supabase UUID.
  /// Requires an authenticated session (RLS INSERT policy enforces this).
  static Future<String> createOrganization(Map<String, dynamic> data) async {
    final result = await client
        .from('organizations')
        .insert(data)
        .select('id')
        .single();
    return result['id'] as String;
  }

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

  // ── Remote CRP Concurrence (Change 5) ─────────────────────────────────────

  /// Returns missions in [orgId] that need CRP concurrence but have not yet
  /// received a decision.  Called on every CRP alert-refresh when online.
  static Future<List<Map<String, dynamic>>> fetchPendingConcurrences(
      String orgId) async {
    try {
      final rows = await client
          .from('missions')
          .select('mission_ref, title')
          .eq('organization_id', orgId)
          .eq('crp_concurrence_required', true)
          .eq('crp_concurrence_status', '')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return [];
    }
  }

  /// Writes the CRP's decision directly to the Supabase missions row so the
  /// RPIC's 60-second poll picks it up without waiting for a full sync cycle.
  static Future<void> updateConcurrenceDecision({
    required String missionRef,
    required String orgId,
    required String status,
  }) =>
      client
          .from('missions')
          .update({'crp_concurrence_status': status})
          .eq('mission_ref', missionRef)
          .eq('organization_id', orgId);

  // ── Mission Flights ───────────────────────────────────────────────────────

  /// Replaces all flight legs for a mission (delete existing + insert new).
  static Future<void> replaceMissionFlights(
      String missionUuid, List<Map<String, dynamic>> flights) async {
    await client
        .from('mission_flights')
        .delete()
        .eq('mission_id', missionUuid);
    if (flights.isNotEmpty) {
      await client.from('mission_flights').insert(flights);
    }
  }

  // ── Standalone Logs ───────────────────────────────────────────────────────

  static Future<void> upsertMaintenanceLogs(List<Map<String, dynamic>> rows) =>
      client.from('maintenance_logs').upsert(rows);

  static Future<void> upsertBatteryLogs(List<Map<String, dynamic>> rows) =>
      client.from('battery_logs').upsert(rows);

  static Future<void> upsertIncidentReports(List<Map<String, dynamic>> rows) =>
      client.from('incident_reports').upsert(rows);

  // ── Equipment ─────────────────────────────────────────────────────────────

  /// Upserts equipment rows and returns [{id, equipment_code}] for each row
  /// so the caller can store the Supabase UUID locally.
  static Future<List<Map<String, dynamic>>> upsertEquipment(
      List<Map<String, dynamic>> rows) async {
    final result = await client
        .from('equipment')
        .upsert(rows, onConflict: 'equipment_code,organization_id')
        .select('id,equipment_code');
    return List<Map<String, dynamic>>.from(result as List);
  }

  // ── Aircraft ──────────────────────────────────────────────────────────────

  /// Upserts aircraft rows and returns [{id, serial_number}] for each row.
  static Future<List<Map<String, dynamic>>> upsertAircraft(
      List<Map<String, dynamic>> rows) async {
    final result = await client
        .from('aircraft')
        .upsert(rows, onConflict: 'serial_number,organization_id')
        .select('id,serial_number');
    return List<Map<String, dynamic>>.from(result as List);
  }

  // ── Mission Equipment ─────────────────────────────────────────────────────

  /// Replaces all equipment assignments for a mission (delete + insert).
  static Future<void> replaceMissionEquipment(
      String missionUuid, List<Map<String, dynamic>> rows) async {
    await client
        .from('mission_equipment')
        .delete()
        .eq('mission_id', missionUuid);
    if (rows.isNotEmpty) {
      await client.from('mission_equipment').insert(rows);
    }
  }

  // ── Fit-to-Fly Battery Selections ─────────────────────────────────────────

  /// Replaces all fit-to-fly battery slots for a mission (delete + insert).
  static Future<void> replaceFitToFlyBatteries(
      String missionUuid, List<Map<String, dynamic>> rows) async {
    await client
        .from('fit_to_fly_batteries')
        .delete()
        .eq('mission_id', missionUuid);
    if (rows.isNotEmpty) {
      await client.from('fit_to_fly_batteries').insert(rows);
    }
  }

  // ── Mission Documents ─────────────────────────────────────────────────────

  /// Uploads a document file to the `mission-documents` bucket.
  /// Returns the storage path on success, null on failure.
  static Future<String?> uploadMissionDocument(
      String orgId, String missionRef, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final filename = localPath.split(RegExp(r'[/\\]')).last;
      final storagePath = '$orgId/$missionRef/$filename';
      await client.storage
          .from('mission-documents')
          .upload(storagePath, file,
              fileOptions: const FileOptions(upsert: true));
      return storagePath;
    } catch (e) {
      debugPrint('[SupabaseService] doc upload failed for $localPath: $e');
      return null;
    }
  }
}
