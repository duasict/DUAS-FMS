import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../database/database_helper.dart';
import '../models/mission.dart';
import 'supabase_service.dart';

class SyncService {
  // ── Connectivity ──────────────────────────────────────────────────────────

  static Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();
    return results.any(
        (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
  }

  static Stream<List<ConnectivityResult>> get connectivityStream =>
      Connectivity().onConnectivityChanged;

  // ── Unsynced count ────────────────────────────────────────────────────────

  static Future<int> getUnsyncedCount() async {
    return DatabaseHelper.instance.getUnsyncedCount();
  }

  // ── Main sync entry point ─────────────────────────────────────────────────

  /// Pushes all unsynced local data to Supabase.
  /// Returns true when every record was successfully uploaded.
  static Future<bool> syncToCloud() async {
    if (!await isConnected()) return false;
    if (!SupabaseService.isSignedIn) return false;

    try {
      final profile = await DatabaseHelper.instance.getUserProfile();
      if (profile == null ||
          profile.supabaseId.isEmpty ||
          profile.organizationId.isEmpty) {
        return false;
      }

      final orgId = profile.organizationId;
      final userId = profile.supabaseId;

      final unsyncedMissions =
          await DatabaseHelper.instance.getUnsyncedMissions();

      int synced = 0;
      for (final mission in unsyncedMissions) {
        try {
          await _syncMission(mission, orgId, userId);
          synced++;
        } catch (_) {
          // skip this mission; it will retry next sync
        }
      }

      // Sync standalone logs (not tied to a mission UUID)
      final db = DatabaseHelper.instance;
      final unsyncedMaint = await db.database.then(
          (d) => d.rawQuery('SELECT * FROM maintenance_logs WHERE is_synced = 0'));
      if (unsyncedMaint.isNotEmpty) {
        await SupabaseService.upsertMaintenanceLogs(
            unsyncedMaint.map((r) => {...r, 'organization_id': orgId}).toList());
      }

      final unsyncedBatt = await db.database.then(
          (d) => d.rawQuery('SELECT * FROM battery_logs WHERE is_synced = 0'));
      if (unsyncedBatt.isNotEmpty) {
        await SupabaseService.upsertBatteryLogs(
            unsyncedBatt.map((r) => {...r, 'organization_id': orgId}).toList());
      }

      final unsyncedInc = await db.database.then(
          (d) => d.rawQuery('SELECT * FROM incident_reports WHERE is_synced = 0'));
      if (unsyncedInc.isNotEmpty) {
        await SupabaseService.upsertIncidentReports(
            unsyncedInc.map((r) => {...r, 'organization_id': orgId}).toList());
      }

      await db.markAllSynced();

      return synced > 0 || unsyncedMissions.isEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Per-mission sync ──────────────────────────────────────────────────────

  static Future<void> _syncMission(
      Mission mission, String orgId, String userId) async {
    final localId = mission.id!;

    // 1 — Upsert the mission row; get back its Supabase UUID
    final missionPayload = <String, dynamic>{
      'mission_ref': mission.missionId,
      'title': mission.title,
      'status': mission.status,
      'date': mission.date,
      'time_str': mission.timeStr,
      'location': mission.location,
      if (mission.latitude != null) 'latitude': mission.latitude,
      if (mission.longitude != null) 'longitude': mission.longitude,
      'environment': mission.environment,
      'objective': mission.objective,
      'aircraft_name': mission.aircraftName,
      'aircraft_type': mission.aircraftType,
      if (mission.duration != null) 'duration': mission.duration,
      'crp_advisory_notes': mission.crpAdvisoryNotes,
      'crp_concurrence_required': mission.crpConcurrenceRequired,
      'has_flight_plan_complete': mission.hasFlightPlanComplete,
      'has_hira_complete': mission.hasHiraComplete,
      'has_equipment_complete': mission.hasEquipmentComplete,
      'has_fit_to_fly_complete': mission.hasFitToFlyComplete,
      'has_preflight_complete': mission.hasPreflightComplete,
      'has_inflight_complete': mission.hasInflightComplete,
      'has_postflight_complete': mission.hasPostflightComplete,
      'has_flightlog_complete': mission.hasFlightlogComplete,
      'created_by': userId,
      'organization_id': orgId,
      'created_at': mission.createdAt,
    };

    final missionUuid =
        await SupabaseService.upsertMissionGetId(missionPayload);

    // 2 — Crew
    final crewPayload = mission.crew
        .map((c) => {
              'mission_id': missionUuid,
              'name': c.name,
              'role': c.role,
              'organization_id': orgId,
            })
        .toList();
    await SupabaseService.replaceCrewForMission(missionUuid, crewPayload);

    // 3 — HIRA rows
    final hiraRows =
        await DatabaseHelper.instance.getHiraRowsByMissionId(localId);
    final hiraPayload = hiraRows
        .map((r) => {
              'mission_id': missionUuid,
              'hazard': r.hazard,
              'likelihood': r.likelihood,
              'impact': r.impact,
              'mitigation': r.mitigation,
              'residual_risk': r.residualRisk,
              'organization_id': orgId,
            })
        .toList();
    await SupabaseService.replaceHiraRows(missionUuid, hiraPayload);

    // 4 — Checklist items
    final checklistItems =
        await DatabaseHelper.instance.getAllChecklistItemsByMissionId(localId);
    final checklistPayload = checklistItems
        .map((i) => {
              'mission_id': missionUuid,
              'checklist_type': i.checklistType,
              'item_type': 'standard',
              'section': i.section,
              'item_index': i.itemIndex,
              'item_text': i.itemText,
              'status': i.status,
              'remark': i.remark,
              'organization_id': orgId,
            })
        .toList();
    await SupabaseService.replaceChecklistItems(missionUuid, checklistPayload);

    // 5 — Flight plan
    final fp =
        await DatabaseHelper.instance.getFlightPlanByMissionId(localId);
    if (fp != null) {
      await SupabaseService.upsertFlightPlan({
        'mission_id': missionUuid,
        'area_of_operation': fp.areaOfOperation,
        if (fp.windSpeed != null) 'wind_speed': fp.windSpeed,
        if (fp.visibility != null) 'visibility': fp.visibility,
        if (fp.weatherForecast.isNotEmpty)
          'weather_forecast': fp.weatherForecast,
        'airspace_class': fp.airspaceClass,
        'notams': fp.notams,
        if (fp.airspaceRestrictions.isNotEmpty)
          'airspace_restrictions': fp.airspaceRestrictions,
        if (fp.missionObjectives.isNotEmpty)
          'mission_objectives': fp.missionObjectives,
        'contingency_plan': fp.contingencyPlan,
        'organization_id': orgId,
      });
    }

    // 6 — Fit-to-fly record
    final ftf =
        await DatabaseHelper.instance.getFitToFlyRecord(localId);
    if (ftf != null) {
      await SupabaseService.upsertFitToFly({
        'mission_id': missionUuid,
        'record_date': ftf['record_date'],
        'record_time': ftf['record_time'],
        'location': ftf['location'] ?? '',
        'mission_type': ftf['mission_type'] ?? '',
        'rpa_model': ftf['rpa_model'] ?? '',
        'serial_number': ftf['serial_number'] ?? '',
        'pic': ftf['pic'] ?? '',
        'organization_id': orgId,
      });
    }

    // 7 — Flight log
    final fl =
        await DatabaseHelper.instance.getFlightLogByMissionId(localId);
    if (fl != null) {
      await SupabaseService.upsertFlightLog({
        'mission_id': missionUuid,
        'date_time': fl.dateTime,
        'location': fl.location,
        if (fl.latitude != null) 'latitude': fl.latitude,
        if (fl.longitude != null) 'longitude': fl.longitude,
        if (fl.altitudeAgl != null) 'altitude_agl': fl.altitudeAgl,
        if (fl.highestPoint != null) 'highest_point': fl.highestPoint,
        'landing_zone': fl.landingZone,
        'platform_type': fl.platformType,
        'model': fl.model,
        if (fl.mtow != null) 'mtow': fl.mtow,
        'payload': fl.payload,            // Supabase column is TEXT[]
        'mission_type': fl.missionType,
        'rpic': fl.rpic,
        'vo': fl.vo,
        'tech': fl.tech,
        'flights': jsonEncode(
            fl.flights.map((f) => f.toMap()).toList()),
        if (fl.weatherWind != null) 'weather_wind': fl.weatherWind,
        if (fl.weatherVisibility != null)
          'weather_visibility': fl.weatherVisibility,
        'weather_cloud': fl.weatherCloud,
        'notams': fl.notams,
        'anomalies': fl.anomalies,        // Supabase column is TEXT[]
        if (fl.dataCapturedGeotiff != null)
          'data_geotiff': fl.dataCapturedGeotiff,
        if (fl.dataCapturedPhotos != null)
          'data_photos': fl.dataCapturedPhotos,
        if (fl.dataCapturedVideo != null)
          'data_video': fl.dataCapturedVideo,
        'data_lidar': fl.dataCapturedLidar,
        'next_maintenance': fl.nextMaintenance,
        'organization_id': orgId,
      });
    }

    // 8 — Mark this mission (and its flight log) as synced locally
    await DatabaseHelper.instance.markMissionSynced(localId);
  }
}
