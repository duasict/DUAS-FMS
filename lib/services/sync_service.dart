import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  ///
  /// Missions are synced individually; a per-mission failure is logged and
  /// retried on the next cycle without aborting the rest.  Standalone log
  /// tables (maintenance, battery, incident) are each isolated in their own
  /// try/catch and are marked synced only if their upload succeeds.
  ///
  /// Returns true when all unsynced missions were uploaded successfully or
  /// there were no unsynced missions to begin with.  Log-table outcomes are
  /// handled independently and do not affect the return value.
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

      final db = DatabaseHelper.instance;
      final dbRaw = await db.database;

      // Aircraft — must sync before missions so supabase_ids are ready for
      // junction table lookups. Aircraft without a serial_number are skipped
      // (they cannot be uniquely upserted on the Supabase partial unique index).
      try {
        final unsyncedAircraft = await db.getUnsyncedAircraft();
        if (unsyncedAircraft.isNotEmpty) {
          final snToLocalId = <String, int>{};
          final payload = <Map<String, dynamic>>[];
          for (final r in unsyncedAircraft) {
            final localId = r['id'] as int;
            final sn = r['serial_number'] as String? ?? '';
            snToLocalId[sn] = localId;
            final m = Map<String, dynamic>.from(r);
            m.remove('id');
            m.remove('is_synced');
            m.remove('supabase_id');
            // Supabase column is photo_url (nullable); local column is photo_path
            m.remove('photo_path');
            m['organization_id'] = orgId;
            // Empty created_at would be rejected by Supabase TIMESTAMPTZ; let
            // the column default (NOW()) apply instead.
            final ca = m['created_at'] as String? ?? '';
            if (ca.isEmpty) m.remove('created_at');
            payload.add(m);
          }
          final returned = await SupabaseService.upsertAircraft(payload);
          for (final row in returned) {
            final sn = row['serial_number'] as String? ?? '';
            final supabaseId = row['id'] as String?;
            final localId = snToLocalId[sn];
            if (supabaseId != null && localId != null) {
              await db.updateAircraftSupabaseId(localId, supabaseId);
            }
          }
        }
      } catch (e, st) {
        debugPrint('[SyncService] aircraft sync error: $e\n$st');
      }

      // Equipment — must sync before missions so supabase_ids are ready for
      // mission_equipment and fit_to_fly_batteries junction tables.
      try {
        final unsyncedEquipment = await db.getUnsyncedEquipment();
        if (unsyncedEquipment.isNotEmpty) {
          final codeToLocalId = <String, int>{};
          final payload = <Map<String, dynamic>>[];
          for (final r in unsyncedEquipment) {
            final localId = r['id'] as int;
            final code = r['equipment_code'] as String? ?? '';
            codeToLocalId[code] = localId;
            final m = Map<String, dynamic>.from(r);
            m.remove('id');
            m.remove('is_synced');
            m.remove('supabase_id');
            m['organization_id'] = orgId;
            final ca = m['created_at'] as String? ?? '';
            if (ca.isEmpty) m.remove('created_at');
            payload.add(m);
          }
          final returned = await SupabaseService.upsertEquipment(payload);
          for (final row in returned) {
            final code = row['equipment_code'] as String? ?? '';
            final supabaseId = row['id'] as String?;
            final localId = codeToLocalId[code];
            if (supabaseId != null && localId != null) {
              await db.updateEquipmentSupabaseId(localId, supabaseId);
            }
          }
        }
      } catch (e, st) {
        debugPrint('[SyncService] equipment sync error: $e\n$st');
      }

      // Missions — runs after aircraft/equipment so junction tables have UUIDs.
      final unsyncedMissions = await DatabaseHelper.instance.getUnsyncedMissions();

      int synced = 0;
      for (final mission in unsyncedMissions) {
        try {
          await _syncMission(mission, orgId, userId);
          synced++;
        } catch (e, st) {
          debugPrint('[SyncService] mission ${mission.missionId} sync error: $e\n$st');
          // Skip this mission; it will retry on next sync
        }
      }

      // Standalone logs (not tied to a mission UUID).
      // Each table is wrapped in its own try/catch so a failure in one table
      // does not abort the others, and only successfully-uploaded rows are
      // marked synced locally.
      var maintSyncedIds = <int>[], incSyncedIds = <int>[];
      bool battSynced = false;

      try {
        final rows = await dbRaw
            .rawQuery('SELECT * FROM maintenance_logs WHERE is_synced = 0');
        if (rows.isNotEmpty) {
          final uploaded = await Future.wait(
              rows.map((r) => _uploadPhotosInRow(r, 'maintenance')));
          // Only push rows where every photo upload succeeded; rows with
          // remaining local paths stay is_synced=0 and retry next cycle.
          final ready = uploaded.where((r) => !_hasLocalPhotoPaths(r)).toList();
          if (ready.isNotEmpty) {
            await SupabaseService.upsertMaintenanceLogs(
                ready.map((r) => _cleanLogRow(r, orgId)).toList());
            maintSyncedIds = ready.map((r) => r['id'] as int).toList();
          }
        }
      } catch (e, st) {
        debugPrint('[SyncService] maintenance_logs sync error: $e\n$st');
      }

      try {
        final rows = await dbRaw
            .rawQuery('SELECT * FROM battery_logs WHERE is_synced = 0');
        if (rows.isNotEmpty) {
          await SupabaseService.upsertBatteryLogs(
              rows.map((r) => _cleanLogRow(r, orgId)).toList());
        }
        battSynced = true;
      } catch (e, st) {
        debugPrint('[SyncService] battery_logs sync error: $e\n$st');
      }

      try {
        final rows = await dbRaw
            .rawQuery('SELECT * FROM incident_reports WHERE is_synced = 0');
        if (rows.isNotEmpty) {
          final uploaded = await Future.wait(
              rows.map((r) => _uploadPhotosInRow(r, 'incidents')));
          final ready = uploaded.where((r) => !_hasLocalPhotoPaths(r)).toList();
          if (ready.isNotEmpty) {
            await SupabaseService.upsertIncidentReports(
                ready.map((r) => _cleanLogRow(r, orgId)).toList());
            incSyncedIds = ready.map((r) => r['id'] as int).toList();
          }
        }
      } catch (e, st) {
        debugPrint('[SyncService] incident_reports sync error: $e\n$st');
      }

      // Mark only fully-uploaded rows as synced. Maintenance and incident rows
      // are tracked by ID so that any row whose photo upload failed remains
      // is_synced=0 and will be retried on the next sync cycle.
      final batch = dbRaw.batch();
      if (maintSyncedIds.isNotEmpty) {
        final ph = List.filled(maintSyncedIds.length, '?').join(',');
        batch.rawUpdate(
            'UPDATE maintenance_logs SET is_synced = 1 WHERE id IN ($ph)',
            maintSyncedIds);
      }
      if (battSynced) {
        batch.update('battery_logs', {'is_synced': 1},
            where: 'is_synced = 0');
      }

      if (incSyncedIds.isNotEmpty) {
        final ph = List.filled(incSyncedIds.length, '?').join(',');
        batch.rawUpdate(
            'UPDATE incident_reports SET is_synced = 1 WHERE id IN ($ph)',
            incSyncedIds);
      }
      await batch.commit(noResult: true);

      // Retry mission_documents whose file upload failed on initial creation.
      try {
        final unsyncedDocs = await db.getUnsyncedMissionDocuments();
        for (final doc in unsyncedDocs) {
          try {
            final docId = doc['id'] as int;
            final localPath = doc['file_path'] as String? ?? '';
            if (localPath.isEmpty) continue;
            final missionLocalId = doc['mission_id'] as int?;
            if (missionLocalId == null) continue;
            final missionRef = await db.getMissionRef(missionLocalId);
            if (missionRef == null || missionRef.isEmpty) continue;
            final storagePath = await SupabaseService.uploadMissionDocument(
                orgId, missionRef, localPath);
            if (storagePath != null) {
              await db.updateMissionDocumentUrl(docId, storagePath);
            }
          } catch (e, st) {
            debugPrint('[SyncService] doc retry error: $e\n$st');
          }
        }
      } catch (e, st) {
        debugPrint('[SyncService] mission_documents retry error: $e\n$st');
      }

      return synced > 0 || unsyncedMissions.isEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Standalone log row cleaner ────────────────────────────────────────────

  /// Strips local-only and type-incompatible fields before pushing a
  /// maintenance / battery / incident row to Supabase.
  ///
  /// Local SQLite rows carry:
  ///   • `id`          — INTEGER PK; Supabase uses UUID (auto-generated)
  ///   • `is_synced`   — local-only flag; column doesn't exist in Supabase
  ///   • `aircraft_id` — local INTEGER; Supabase expects UUID (nullable)
  ///   • `mission_id`  — local INTEGER; Supabase expects UUID (nullable)
  ///   • `reporter_id` / `technician_id` — same issue
  ///
  /// We clear the UUID-ref columns to null rather than dropping them so
  /// Supabase receives an explicit null and doesn't reject missing keys.
  static Map<String, dynamic> _cleanLogRow(
      Map<String, dynamic> r, String orgId) {
    final m = Map<String, dynamic>.from(r);
    // Remove local-only columns that don't exist in Supabase
    m.remove('id');
    m.remove('is_synced');
    // Clear local integer FKs — they are not valid Supabase UUIDs
    for (final k in ['aircraft_id', 'mission_id', 'reporter_id',
                     'technician_id', 'equipment_id']) {
      if (m.containsKey(k)) m[k] = null;
    }
    m['organization_id'] = orgId;
    return m;
  }

  // ── Photo upload helpers ──────────────────────────────────────────────────

  static bool _isLocalPath(String p) =>
      p.startsWith('/') || (p.length > 2 && p[1] == ':');

  /// Returns true when a row's photo_paths JSON still contains at least one
  /// local file path, meaning one or more uploads failed and the row should
  /// not be marked as synced yet.
  static bool _hasLocalPhotoPaths(Map<String, dynamic> row) {
    final raw = row['photo_paths'];
    if (raw == null || raw.toString().isEmpty) return false;
    try {
      return List<String>.from(jsonDecode(raw as String)).any(_isLocalPath);
    } catch (_) {
      return false;
    }
  }

  /// Uploads a single local file to the `uas-photos` bucket.
  /// Returns the storage path on success, null on failure.
  static Future<String?> uploadPhoto(String localPath, String folder) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final ext = localPath.split('.').last.toLowerCase();
      final name =
          '$folder/${DateTime.now().millisecondsSinceEpoch}_${localPath.hashCode.abs()}.$ext';
      await Supabase.instance.client.storage
          .from('uas-photos')
          .upload(name, file, fileOptions: const FileOptions(upsert: false));
      return name;
    } catch (e) {
      debugPrint('[SyncService] photo upload failed for $localPath: $e');
      return null;
    }
  }

  /// Returns a 1-hour signed URL for a storage path from the `uas-photos` bucket.
  static Future<String> getPhotoUrl(String storagePath) =>
      Supabase.instance.client.storage
          .from('uas-photos')
          .createSignedUrl(storagePath, 3600);

  /// Replaces local file paths in a row's `photo_paths` JSON with storage paths.
  static Future<Map<String, dynamic>> _uploadPhotosInRow(
      Map<String, dynamic> row, String folder) async {
    final m = Map<String, dynamic>.from(row);
    final raw = m['photo_paths'];
    if (raw == null || raw.toString().isEmpty) return m;
    try {
      final paths = List<String>.from(jsonDecode(raw as String));
      final uploaded = <String>[];
      for (final p in paths) {
        if (_isLocalPath(p)) {
          uploaded.add(await uploadPhoto(p, folder) ?? p);
        } else {
          uploaded.add(p);
        }
      }
      m['photo_paths'] = jsonEncode(uploaded);
    } catch (_) {}
    return m;
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
      'crp_concurrence_status': mission.crpConcurrenceStatus,
      'takeoff_time': mission.takeoffTime,
      'landing_time': mission.landingTime,
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
    if (missionUuid.isEmpty) {
      throw Exception(
          'upsertMissionGetId returned empty UUID for mission ${mission.missionId}');
    }

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
        if (fp.coverageAreaGeoJson != null && fp.coverageAreaGeoJson!.isNotEmpty)
          'coverage_area_geojson': fp.coverageAreaGeoJson,
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
      final flPhotoPaths = <String>[];
      for (final p in fl.photoPaths) {
        flPhotoPaths.add(
            _isLocalPath(p) ? (await uploadPhoto(p, 'flight-logs') ?? p) : p);
      }
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
        'photo_paths': jsonEncode(flPhotoPaths),
        'next_maintenance': fl.nextMaintenance,
        'organization_id': orgId,
      });
    }

    // 8 — Mission flight legs (takeoff/landing times + GPS per flight)
    final missionFlights =
        await DatabaseHelper.instance.getMissionFlights(localId);
    if (missionFlights.isNotEmpty) {
      final flightPayload = missionFlights
          .map((f) => {
                'mission_id': missionUuid,
                'flight_num': f.flightNum,
                'takeoff_time': f.takeoffTime,
                'landing_time': f.landingTime,
                if (f.takeoffLat != null) 'takeoff_lat': f.takeoffLat,
                if (f.takeoffLon != null) 'takeoff_lon': f.takeoffLon,
                if (f.landingLat != null) 'landing_lat': f.landingLat,
                if (f.landingLon != null) 'landing_lon': f.landingLon,
                'organization_id': orgId,
              })
          .toList();
      await SupabaseService.replaceMissionFlights(missionUuid, flightPayload);
    }

    // 10 — Mission equipment (junction table — equipment supabase_ids populated above)
    final meRows =
        await DatabaseHelper.instance.getMissionEquipmentIds(localId);
    if (meRows.isNotEmpty) {
      final mePayload = <Map<String, dynamic>>[];
      for (final row in meRows) {
        final localEquipId = row['equipment_id'] as int?;
        final equipSupabaseId = localEquipId != null
            ? await DatabaseHelper.instance.getEquipmentSupabaseId(localEquipId)
            : null;
        mePayload.add({
          'mission_id': missionUuid,
          'equipment_id': equipSupabaseId,
          'purpose': row['purpose'] as String? ?? '',
          'notes': row['notes'] as String? ?? '',
          'organization_id': orgId,
        });
      }
      await SupabaseService.replaceMissionEquipment(missionUuid, mePayload);
    }

    // 11 — Fit-to-fly battery slots (junction table — equipment supabase_ids populated above)
    final ftfRows =
        await DatabaseHelper.instance.getFitToFlyBatteries(localId);
    if (ftfRows.isNotEmpty) {
      final ftfPayload = <Map<String, dynamic>>[];
      for (final row in ftfRows) {
        final localEquipId = row['equipment_id'] as int?;
        final equipSupabaseId = localEquipId != null
            ? await DatabaseHelper.instance.getEquipmentSupabaseId(localEquipId)
            : null;
        ftfPayload.add({
          'mission_id': missionUuid,
          'slot_index': row['slot_index'] as int,
          'equipment_id': equipSupabaseId,
          'battery_label': row['battery_label'] as String? ?? '',
          'organization_id': orgId,
        });
      }
      await SupabaseService.replaceFitToFlyBatteries(missionUuid, ftfPayload);
    }

    // 9 — Mark this mission (and its flight log) as synced locally
    await DatabaseHelper.instance.markMissionSynced(localId);
  }
}
