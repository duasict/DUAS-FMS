import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/mission.dart';
import '../models/aircraft.dart';
import '../models/alert_model.dart';
import '../models/crew_member.dart';
import '../models/checklist_item.dart';
import '../models/flight_log.dart';
import '../models/flight_plan.dart';
import '../models/hira_row.dart';
import '../models/user_profile.dart';
import '../utils/app_constants.dart';

class DatabaseHelper {
  static const _dbName = 'uas_fms.db';
  static const _dbVersion = 6;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final col in [
        'has_flight_plan_complete INTEGER DEFAULT 0',
        'has_hira_complete INTEGER DEFAULT 0',
        'has_approval_complete INTEGER DEFAULT 0',
        'has_equipment_complete INTEGER DEFAULT 0',
        'has_fit_to_fly_complete INTEGER DEFAULT 0',
      ]) {
        await db.execute('ALTER TABLE missions ADD COLUMN $col');
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS flight_plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mission_id INTEGER NOT NULL UNIQUE,
          area_of_operation TEXT NOT NULL,
          wind_speed REAL,
          visibility REAL,
          weather_forecast TEXT,
          airspace_class TEXT,
          notams TEXT,
          airspace_restrictions TEXT,
          mission_objectives TEXT,
          contingency_plan TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hira_rows (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mission_id INTEGER NOT NULL,
          hazard TEXT NOT NULL,
          likelihood INTEGER NOT NULL DEFAULT 1,
          impact INTEGER NOT NULL DEFAULT 1,
          mitigation TEXT DEFAULT '',
          residual_risk INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fit_to_fly_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mission_id INTEGER NOT NULL UNIQUE,
          record_date TEXT,
          record_time TEXT,
          location TEXT,
          mission_type TEXT,
          rpa_model TEXT,
          serial_number TEXT,
          payload TEXT,
          pic TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL DEFAULT '',
          rank TEXT NOT NULL DEFAULT '',
          email TEXT NOT NULL DEFAULT '',
          unit TEXT NOT NULL DEFAULT '',
          license_number TEXT NOT NULL DEFAULT '',
          phone TEXT NOT NULL DEFAULT '',
          photo_path TEXT DEFAULT ''
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE aircraft ADD COLUMN serial_number TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 5) {
      // ── user_profile: add role, license_expiry_date, organization_id, supabase_id
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN role TEXT NOT NULL DEFAULT 'rpic'");
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN license_expiry_date TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN organization_id TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN supabase_id TEXT NOT NULL DEFAULT ''");

      // ── missions: add crp_advisory_notes, crp_concurrence_required, organization_id, created_by
      await db.execute(
          "ALTER TABLE missions ADD COLUMN crp_advisory_notes TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE missions ADD COLUMN crp_concurrence_required INTEGER NOT NULL DEFAULT 0");
      await db.execute(
          "ALTER TABLE missions ADD COLUMN organization_id TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE missions ADD COLUMN created_by TEXT");

      // Migrate legacy 'approved' status → 'planning'
      await db.execute(
          "UPDATE missions SET status = 'planning' WHERE status = 'approved'");

      // ── checklist_items: add item_type for contingency differentiation
      await db.execute(
          "ALTER TABLE checklist_items ADD COLUMN item_type TEXT NOT NULL DEFAULT 'standard'");

      // ── New tables: maintenance_logs, battery_logs, incident_reports
      await db.execute('''
        CREATE TABLE IF NOT EXISTS maintenance_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          aircraft_id INTEGER,
          mission_id INTEGER,
          technician_id INTEGER,
          maintenance_date TEXT NOT NULL,
          maintenance_type TEXT NOT NULL DEFAULT 'scheduled',
          description TEXT NOT NULL DEFAULT '',
          parts_replaced TEXT NOT NULL DEFAULT '',
          flight_hours REAL,
          cycle_count INTEGER,
          next_maintenance_date TEXT,
          next_maintenance_hours REAL,
          airworthiness_status TEXT NOT NULL DEFAULT 'serviceable',
          signed_by TEXT NOT NULL DEFAULT '',
          remarks TEXT NOT NULL DEFAULT '',
          organization_id TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS battery_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          aircraft_id INTEGER,
          mission_id INTEGER,
          battery_id TEXT NOT NULL,
          log_date TEXT NOT NULL,
          charge_cycles INTEGER,
          voltage_before REAL,
          voltage_after REAL,
          charge_time_min INTEGER,
          status TEXT NOT NULL DEFAULT 'good',
          remarks TEXT NOT NULL DEFAULT '',
          organization_id TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS incident_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mission_id INTEGER,
          aircraft_id INTEGER,
          reporter_id INTEGER,
          incident_date TEXT NOT NULL,
          incident_time TEXT,
          location TEXT NOT NULL DEFAULT '',
          incident_type TEXT NOT NULL DEFAULT '',
          severity TEXT NOT NULL DEFAULT 'minor',
          description TEXT NOT NULL DEFAULT '',
          immediate_actions TEXT NOT NULL DEFAULT '',
          five_whys TEXT NOT NULL DEFAULT '',
          corrective_actions TEXT NOT NULL DEFAULT '',
          reported_to_caap INTEGER NOT NULL DEFAULT 0,
          caap_reference TEXT,
          organization_id TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 6) {
      // ── user_profile: add license_verified and face_verified booleans
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN license_verified INTEGER NOT NULL DEFAULT 0");
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN face_verified INTEGER NOT NULL DEFAULT 0");
      // Migrate legacy 'rpic' profile roles → 'pic'
      await db.execute("UPDATE user_profile SET role = 'pic' WHERE role = 'rpic'");
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE missions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'planning',
        date TEXT NOT NULL,
        time_str TEXT NOT NULL,
        location TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        environment TEXT NOT NULL,
        objective TEXT NOT NULL,
        aircraft_id INTEGER,
        aircraft_name TEXT NOT NULL,
        aircraft_type TEXT NOT NULL,
        duration INTEGER,
        crp_advisory_notes TEXT NOT NULL DEFAULT '',
        crp_concurrence_required INTEGER NOT NULL DEFAULT 0,
        organization_id TEXT NOT NULL DEFAULT '',
        created_by TEXT,
        has_flight_plan_complete INTEGER DEFAULT 0,
        has_hira_complete INTEGER DEFAULT 0,
        has_equipment_complete INTEGER DEFAULT 0,
        has_fit_to_fly_complete INTEGER DEFAULT 0,
        has_preflight_complete INTEGER DEFAULT 0,
        has_inflight_complete INTEGER DEFAULT 0,
        has_postflight_complete INTEGER DEFAULT 0,
        has_flightlog_complete INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE crew_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE aircraft (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        model TEXT NOT NULL,
        serial_number TEXT NOT NULL DEFAULT '',
        mtow REAL NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        status TEXT NOT NULL,
        mission_id INTEGER,
        mission_title TEXT,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE checklist_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL,
        checklist_type TEXT NOT NULL,
        item_type TEXT NOT NULL DEFAULT 'standard',
        section TEXT NOT NULL,
        item_index INTEGER NOT NULL,
        item_text TEXT NOT NULL,
        status INTEGER DEFAULT 0,
        remark TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE flight_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL,
        date_time TEXT NOT NULL,
        location TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        altitude_agl REAL,
        highest_point REAL,
        landing_zone TEXT,
        platform_type TEXT NOT NULL,
        model TEXT NOT NULL,
        mtow REAL,
        payload TEXT,
        mission_type TEXT NOT NULL,
        rpic TEXT NOT NULL,
        vo TEXT NOT NULL,
        tech TEXT NOT NULL,
        flights TEXT,
        weather_wind REAL,
        weather_visibility REAL,
        weather_cloud TEXT,
        notams TEXT,
        anomalies TEXT,
        data_geotiff TEXT,
        data_photos TEXT,
        data_video TEXT,
        data_lidar INTEGER DEFAULT 0,
        next_maintenance TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE flight_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL UNIQUE,
        area_of_operation TEXT NOT NULL,
        wind_speed REAL,
        visibility REAL,
        weather_forecast TEXT,
        airspace_class TEXT,
        notams TEXT,
        airspace_restrictions TEXT,
        mission_objectives TEXT,
        contingency_plan TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE hira_rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL,
        hazard TEXT NOT NULL,
        likelihood INTEGER NOT NULL DEFAULT 1,
        impact INTEGER NOT NULL DEFAULT 1,
        mitigation TEXT DEFAULT '',
        residual_risk INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE fit_to_fly_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL UNIQUE,
        record_date TEXT,
        record_time TEXT,
        location TEXT,
        mission_type TEXT,
        rpa_model TEXT,
        serial_number TEXT,
        payload TEXT,
        pic TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supabase_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL DEFAULT 'vo',
        email TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT '',
        license_number TEXT NOT NULL DEFAULT '',
        license_expiry_date TEXT NOT NULL DEFAULT '',
        license_verified INTEGER NOT NULL DEFAULT 0,
        face_verified INTEGER NOT NULL DEFAULT 0,
        phone TEXT NOT NULL DEFAULT '',
        photo_path TEXT DEFAULT '',
        organization_id TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        aircraft_id INTEGER,
        mission_id INTEGER,
        technician_id INTEGER,
        maintenance_date TEXT NOT NULL,
        maintenance_type TEXT NOT NULL DEFAULT 'scheduled',
        description TEXT NOT NULL DEFAULT '',
        parts_replaced TEXT NOT NULL DEFAULT '',
        flight_hours REAL,
        cycle_count INTEGER,
        next_maintenance_date TEXT,
        next_maintenance_hours REAL,
        airworthiness_status TEXT NOT NULL DEFAULT 'serviceable',
        signed_by TEXT NOT NULL DEFAULT '',
        remarks TEXT NOT NULL DEFAULT '',
        organization_id TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE battery_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        aircraft_id INTEGER,
        mission_id INTEGER,
        battery_id TEXT NOT NULL,
        log_date TEXT NOT NULL,
        charge_cycles INTEGER,
        voltage_before REAL,
        voltage_after REAL,
        charge_time_min INTEGER,
        status TEXT NOT NULL DEFAULT 'good',
        remarks TEXT NOT NULL DEFAULT '',
        organization_id TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE incident_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER,
        aircraft_id INTEGER,
        reporter_id INTEGER,
        incident_date TEXT NOT NULL,
        incident_time TEXT,
        location TEXT NOT NULL DEFAULT '',
        incident_type TEXT NOT NULL DEFAULT '',
        severity TEXT NOT NULL DEFAULT 'minor',
        description TEXT NOT NULL DEFAULT '',
        immediate_actions TEXT NOT NULL DEFAULT '',
        five_whys TEXT NOT NULL DEFAULT '',
        corrective_actions TEXT NOT NULL DEFAULT '',
        reported_to_caap INTEGER NOT NULL DEFAULT 0,
        caap_reference TEXT,
        organization_id TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    if (kDebugMode) await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    // Aircraft
    await db.insert('aircraft', {
      'name': 'DJI Agras T40',
      'type': 'multi-rotor',
      'model': 'T40',
      'mtow': 75.0,
      'status': 'serviceable',
    });
    await db.insert('aircraft', {
      'name': 'DJI Matrice 350 RTK',
      'type': 'multi-rotor',
      'model': 'M350 RTK',
      'mtow': 6.47,
      'status': 'serviceable',
    });
    await db.insert('aircraft', {
      'name': 'WingtraOne GEN II',
      'type': 'vtol',
      'model': 'WingtraOne GEN II',
      'mtow': 4.5,
      'status': 'serviceable',
    });

    // Mission 1 — Completed
    final m1 = await db.insert('missions', {
      'mission_id': 'UAS-2025-001',
      'title': 'Agricultural Survey — Cagayan Valley',
      'status': 'completed',
      'date': '2025-04-15',
      'time_str': '06:30',
      'location': 'Cagayan Valley, Isabela',
      'latitude': 16.9754,
      'longitude': 121.8107,
      'environment': 'Rural / Agricultural',
      'objective':
          'Multi-spectral aerial imaging for crop health assessment covering approximately 450 hectares of rice and corn fields.',
      'aircraft_id': 1,
      'aircraft_name': 'DJI Agras T40',
      'aircraft_type': 'multi-rotor',
      'crp_advisory_notes': '',
      'crp_concurrence_required': 0,
      'duration': 145,
      'has_preflight_complete': 1,
      'has_inflight_complete': 1,
      'has_postflight_complete': 1,
      'has_flightlog_complete': 1,
      'is_synced': 1,
      'created_at': '2025-04-01T08:00:00',
    });
    await _seedCrew(db, m1, [
      {'name': 'Capt. Juan B. dela Cruz', 'role': 'rpic'},
      {'name': 'SSgt. Maria L. Santos', 'role': 'vo'},
      {'name': 'Cpl. Pedro G. Reyes', 'role': 'tech'},
    ]);

    // Mission 2 — Planning (upcoming)
    final m2 = await db.insert('missions', {
      'mission_id': 'UAS-2025-002',
      'title': 'Infrastructure Inspection — NLEX Viaduct',
      'status': 'planning',
      'date': '2025-05-10',
      'time_str': '07:00',
      'location': 'NLEX Viaduct, Bulacan',
      'latitude': 14.8527,
      'longitude': 120.9865,
      'environment': 'Urban / Infrastructure',
      'objective':
          'High-resolution visual and thermal inspection of NLEX viaduct structure for maintenance assessment and defect detection.',
      'aircraft_id': 2,
      'aircraft_name': 'DJI Matrice 350 RTK',
      'aircraft_type': 'multi-rotor',
      'crp_advisory_notes':
          'Coordinate with NLEX Operations Center. Monitor overhead power lines. Wind limit: ≤10 m/s.',
      'crp_concurrence_required': 0,
      'duration': null,
      'is_synced': 1,
      'created_at': '2025-04-20T09:00:00',
    });
    await _seedCrew(db, m2, [
      {'name': 'Capt. Juan B. dela Cruz', 'role': 'rpic'},
      {'name': 'Sgt. Robert T. Lim', 'role': 'vo'},
      {'name': 'Cpl. Ana P. Mendoza', 'role': 'tech'},
    ]);

    // Mission 3 — Planning / HIGH RISK → CRP concurrence required
    final m3 = await db.insert('missions', {
      'mission_id': 'UAS-2025-003',
      'title': 'Emergency Response — SAR Sierra Madre',
      'status': 'planning',
      'date': '2025-05-12',
      'time_str': '05:30',
      'location': 'Sierra Madre Mountains, Quezon',
      'latitude': 14.4298,
      'longitude': 121.5765,
      'environment': 'Mountainous / Remote',
      'objective':
          'Search and rescue support for three missing hikers. Wide-area thermal imaging and LiDAR terrain mapping to locate missing persons.',
      'aircraft_id': 3,
      'aircraft_name': 'WingtraOne GEN II',
      'aircraft_type': 'vtol',
      'crp_advisory_notes': '',
      'crp_concurrence_required': 1,
      'duration': null,
      'is_synced': 1,
      'created_at': '2025-05-01T14:00:00',
    });
    await _seedCrew(db, m3, [
      {'name': 'Capt. Juan B. dela Cruz', 'role': 'rpic'},
      {'name': 'SSgt. Maria L. Santos', 'role': 'vo'},
      {'name': 'Cpl. Pedro G. Reyes', 'role': 'tech'},
    ]);

    // Mission 4 — Planning (upcoming)
    final m4 = await db.insert('missions', {
      'mission_id': 'UAS-2025-004',
      'title': 'Coastal LiDAR Survey — Manila Bay',
      'status': 'planning',
      'date': '2025-05-15',
      'time_str': '06:00',
      'location': 'Manila Bay Coastline, Metro Manila',
      'latitude': 14.5833,
      'longitude': 120.9685,
      'environment': 'Coastal / Maritime',
      'objective':
          'LiDAR bathymetric and topographic mapping of Manila Bay coastline for DENR coastal management and erosion assessment.',
      'aircraft_id': 3,
      'aircraft_name': 'WingtraOne GEN II',
      'aircraft_type': 'vtol',
      'crp_advisory_notes':
          'CAAP coordination required. Monitor NAIA TFR. Salt-air post-flight rinse for LiDAR payload.',
      'crp_concurrence_required': 0,
      'duration': null,
      'is_synced': 1,
      'created_at': '2025-04-25T10:00:00',
    });
    await _seedCrew(db, m4, [
      {'name': 'Lt. Carlos M. Reyes', 'role': 'rpic'},
      {'name': 'Sgt. Robert T. Lim', 'role': 'vo'},
      {'name': 'Cpl. Ana P. Mendoza', 'role': 'tech'},
    ]);

    // Alerts
    await db.insert('alerts', {
      'type': 'concurrence',
      'title': 'Concurrence Required — UAS-2025-005',
      'message':
          'Mission UAS-2025-005 (Training — Clark Air Base) is pending your concurrence approval. Review mission details and provide your approval or remarks before May 8, 2025.',
      'status': 'pending',
      'mission_id': null,
      'mission_title': 'Training Exercise — Clark Air Base',
      'is_read': 0,
      'created_at': '2025-05-05T08:00:00',
      'is_synced': 1,
    });
    await db.insert('alerts', {
      'type': 'notification',
      'title': 'Weather Advisory — Bulacan, May 10',
      'message':
          'PAGASA issues wind advisory for Bulacan Province on May 10, 2025. Sustained winds of 11–14 m/s expected between 10:00–14:00 local time. Monitor conditions prior to UAS-2025-002 operations.',
      'status': 'info',
      'mission_id': m2,
      'mission_title': 'Infrastructure Inspection — NLEX Viaduct',
      'is_read': 0,
      'created_at': '2025-05-05T10:30:00',
      'is_synced': 1,
    });
    await db.insert('alerts', {
      'type': 'notification',
      'title': 'Mission Completed — UAS-2025-001',
      'message':
          'Agricultural Survey mission UAS-2025-001 has been successfully completed. Flight log and report are available for review. Total flight time: 2h 25m.',
      'status': 'info',
      'mission_id': m1,
      'mission_title': 'Agricultural Survey — Cagayan Valley',
      'is_read': 1,
      'created_at': '2025-04-15T11:45:00',
      'is_synced': 1,
    });
    await db.insert('alerts', {
      'type': 'notification',
      'title': 'Maintenance Due — DJI Agras T40',
      'message':
          'DJI Agras T40 (S/N: AG40-24-00382) is due for its 50-hour scheduled maintenance check. Current cycle count: 48.5 hours. Schedule maintenance before next deployment.',
      'status': 'info',
      'mission_id': null,
      'mission_title': null,
      'is_read': 0,
      'created_at': '2025-05-03T09:00:00',
      'is_synced': 1,
    });

    // Seed completed checklist and flight log for Mission 1
    await _seedCompletedChecklist(db, m1);
    await _seedFlightLog(db, m1);
  }

  Future<void> _seedCrew(Database db, int missionId,
      List<Map<String, String>> members) async {
    for (final m in members) {
      await db.insert('crew_members', {
        'mission_id': missionId,
        'name': m['name'],
        'role': m['role'],
      });
    }
  }

  Future<void> _seedCompletedChecklist(Database db, int missionId) async {
    final preflight = [
      {'section': 'A. MISSION & CREW', 'text': 'Flight Plan approved (Ch 3.4)'},
      {'section': 'A. MISSION & CREW', 'text': 'RPIC assigned and briefed (Annex I signed)'},
      {'section': 'A. MISSION & CREW', 'text': 'VO assigned (if required; no RPL needed)'},
      {'section': 'A. MISSION & CREW', 'text': 'Maintenance Head present (if post-maintenance/new platform)'},
      {'section': 'A. MISSION & CREW', 'text': 'Crew fitness confirmed (no fatigue, illness, impairment)'},
      {'section': 'B. AIRCRAFT & PAYLOAD', 'text': 'Visual inspection: airframe, arms, motors, props (no cracks/damage)'},
      {'section': 'B. AIRCRAFT & PAYLOAD', 'text': 'Propellers: no chips/warping; torque verified (MR: 0.8 Nm, VFW: 1.2 Nm)'},
      {'section': 'B. AIRCRAFT & PAYLOAD', 'text': 'Battery: ≥95% charge, ≥3.8 V/cell, no swelling, cycle count logged'},
      {'section': 'B. AIRCRAFT & PAYLOAD', 'text': 'Payload: mounted securely, gimbal free-moving, power on'},
      {'section': 'B. AIRCRAFT & PAYLOAD', 'text': 'Airworthiness tag: Serviceable (per Annex E)'},
      {'section': 'C. GCS & COMMUNICATION', 'text': 'GCS powered, OS/firmware updated, QBase/Mission Planner loaded'},
      {'section': 'C. GCS & COMMUNICATION', 'text': 'RC transmitter calibrated, sticks centered, failsafe triggers tested'},
      {'section': 'C. GCS & COMMUNICATION', 'text': 'Link test: RSSI ≥70%, latency <100 ms, CSL encrypted (if equipped)'},
      {'section': 'C. GCS & COMMUNICATION', 'text': 'Compass & IMU calibrated (green status in GCS)'},
      {'section': 'C. GCS & COMMUNICATION', 'text': 'RTH altitude set: ≥120 m AGL (Multi-rotor), ≥200 m AGL (VTOL)'},
      {'section': 'D. ENVIRONMENT & SAFETY', 'text': 'NOTAMs checked (no activity in ops area)'},
      {'section': 'D. ENVIRONMENT & SAFETY', 'text': 'Weather: wind ≤12 m/s (MR), ≤16 m/s (VFW), no rain/fog'},
      {'section': 'D. ENVIRONMENT & SAFETY', 'text': 'VLOS zone confirmed: clear, ≥500 m radius, no obstacles'},
      {'section': 'D. ENVIRONMENT & SAFETY', 'text': 'Emergency landing zones identified'},
      {'section': 'D. ENVIRONMENT & SAFETY', 'text': 'Manned aircraft activity monitored (VO positioned)'},
    ];

    for (var i = 0; i < preflight.length; i++) {
      await db.insert('checklist_items', {
        'mission_id': missionId,
        'checklist_type': 'preflight',
        'section': preflight[i]['section'],
        'item_index': i,
        'item_text': preflight[i]['text'],
        'status': 1,
        'remark': '',
      });
    }

    final inflight = [
      {'section': 'A. LAUNCH CHECKLIST', 'text': 'GCS final telemetry OK (GPS 3D, AHRS stable)'},
      {'section': 'A. LAUNCH CHECKLIST', 'text': 'Takeoff clearance given by RPIC'},
      {'section': 'A. LAUNCH CHECKLIST', 'text': 'VO confirms VLOS maintained'},
      {'section': 'B. EN ROUTE CHECKLIST', 'text': 'Telemetry Link Stable; Link strength ≥60%'},
      {'section': 'B. EN ROUTE CHECKLIST', 'text': 'Flight path followed'},
      {'section': 'B. EN ROUTE CHECKLIST', 'text': 'Altitude within plan (±10 m)'},
      {'section': 'B. EN ROUTE CHECKLIST', 'text': 'Battery ≥30% (VTOL) / ≥20% (Quad)'},
      {'section': 'B. EN ROUTE CHECKLIST', 'text': 'VO continuously scanning airspace'},
      {'section': 'B. EN ROUTE CHECKLIST', 'text': 'Payload recording (video/photo count increasing)'},
      {'section': 'B. EN ROUTE CHECKLIST', 'text': 'Weather stable (no sudden gusts/visibility loss)'},
      {'section': 'C. CONTINGENCY CHECKLIST', 'text': 'RTH triggered (if link loss >20 sec)'},
      {'section': 'C. CONTINGENCY CHECKLIST', 'text': 'Manual takeover executed (if ATTI mode required)'},
      {'section': 'C. CONTINGENCY CHECKLIST', 'text': 'Emergency landing initiated (if battery <20%)'},
    ];

    for (var i = 0; i < inflight.length; i++) {
      await db.insert('checklist_items', {
        'mission_id': missionId,
        'checklist_type': 'inflight',
        'section': inflight[i]['section'],
        'item_index': i,
        'item_text': inflight[i]['text'],
        'status': i >= 10 ? 2 : 1, // Contingency items marked as N/A (fail) — not triggered
        'remark': i >= 10 ? 'N/A — no contingency triggered' : '',
      });
    }

    final postflight = [
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Aircraft secured, power off'},
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Visual inspection: airframe damage'},
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Visual inspection: propeller'},
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Visual inspection: motor'},
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Visual inspection: gimbal alignment'},
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Battery cooled and logged'},
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Battery discharged to 3.8 V/cell within 24 hrs'},
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Flight Data downloaded'},
      {'section': 'A. AIRCRAFT & PAYLOAD', 'text': 'Data offloaded: photos/videos verified and complete'},
      {'section': 'B. DOCUMENTATION', 'text': 'Flight Log (Annex D) completed'},
      {'section': 'B. DOCUMENTATION', 'text': 'Anomalies logged (e.g., link drop, wind shear)'},
      {'section': 'B. DOCUMENTATION', 'text': 'Debrief conducted (RPIC, VO)'},
      {'section': 'C. MAINTENANCE ACTIONS', 'text': 'Propellers inspected/replaced'},
      {'section': 'C. MAINTENANCE ACTIONS', 'text': 'Motors/ESCs checked for heat/dust'},
      {'section': 'C. MAINTENANCE ACTIONS', 'text': 'Airframe stress points examined'},
      {'section': 'C. MAINTENANCE ACTIONS', 'text': 'Next maintenance due: hrs / date'},
    ];

    for (var i = 0; i < postflight.length; i++) {
      await db.insert('checklist_items', {
        'mission_id': missionId,
        'checklist_type': 'postflight',
        'section': postflight[i]['section'],
        'item_index': i,
        'item_text': postflight[i]['text'],
        'status': 1,
        'remark': i == 15 ? '50 hrs / 2025-06-01' : '',
      });
    }
  }

  Future<void> _seedFlightLog(Database db, int missionId) async {
    await db.insert('flight_logs', {
      'mission_id': missionId,
      'date_time': '2025-04-15T06:30:00+08:00',
      'location': 'Cagayan Valley, Isabela',
      'latitude': 16.9754,
      'longitude': 121.8107,
      'altitude_agl': 110.0,
      'highest_point': 118.0,
      'landing_zone': 'Designated LZ — Brgy. Sta. Rosa Field',
      'platform_type': 'multi-rotor',
      'model': 'DJI Agras T40',
      'mtow': 75.0,
      'payload': '["Multispectral"]',
      'mission_type': 'Agri',
      'rpic': 'Capt. Juan B. dela Cruz',
      'vo': 'SSgt. Maria L. Santos',
      'tech': 'Cpl. Pedro G. Reyes',
      'flights': '[{"flightNum":"1","takeoff":"06:30","landing":"07:45","totalMin":75},{"flightNum":"2","takeoff":"08:10","landing":"09:00","totalMin":50},{"flightNum":"3","takeoff":"09:20","landing":"09:40","totalMin":20}]',
      'weather_wind': 4.2,
      'weather_visibility': 12.0,
      'weather_cloud': 'SCT018 (Scattered at 1800 ft)',
      'notams': 'None',
      'anomalies': '["None"]',
      'data_geotiff': '452.3',
      'data_photos': '1842',
      'data_video': '18',
      'data_lidar': 0,
      'next_maintenance': '50 hrs / 2025-06-01',
      'is_synced': 1,
    });
  }

  // ─── Missions ────────────────────────────────────────────────────────────────

  Future<List<Mission>> getMissions() async {
    final db = await database;
    final rows = await db.query('missions', orderBy: 'date ASC');
    final missions = rows.map(Mission.fromMap).toList();
    for (final m in missions) {
      m.crew = await getCrewForMission(m.id!);
    }
    return missions;
  }

  Future<Mission?> getMissionById(int id) async {
    final db = await database;
    final rows =
        await db.query('missions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final m = Mission.fromMap(rows.first);
    m.crew = await getCrewForMission(id);
    return m;
  }

  Future<int> insertMission(Mission m) async {
    final db = await database;
    return db.insert('missions', m.toMap());
  }

  Future<void> updateMission(Mission m) async {
    final db = await database;
    await db.update('missions', m.toMap(),
        where: 'id = ?', whereArgs: [m.id]);
  }

  // ─── Crew ─────────────────────────────────────────────────────────────────

  Future<List<CrewMember>> getCrewForMission(int missionId) async {
    final db = await database;
    final rows = await db
        .query('crew_members', where: 'mission_id = ?', whereArgs: [missionId]);
    return rows.map(CrewMember.fromMap).toList();
  }

  Future<int> insertCrewMember(CrewMember cm) async {
    final db = await database;
    return db.insert('crew_members', cm.toMap());
  }

  // ─── Aircraft ─────────────────────────────────────────────────────────────

  Future<List<Aircraft>> getAircraft() async {
    final db = await database;
    final rows = await db.query('aircraft');
    return rows.map(Aircraft.fromMap).toList();
  }

  Future<Aircraft?> getAircraftById(int id) async {
    final db = await database;
    final rows =
        await db.query('aircraft', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Aircraft.fromMap(rows.first);
  }

  Future<int> insertAircraft(Aircraft a) async {
    final db = await database;
    return db.insert('aircraft', a.toMap());
  }

  Future<void> updateAircraft(Aircraft a) async {
    final db = await database;
    await db.update('aircraft', a.toMap(),
        where: 'id = ?', whereArgs: [a.id]);
  }

  Future<void> deleteAircraft(int id) async {
    final db = await database;
    await db.delete('aircraft', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Alerts ───────────────────────────────────────────────────────────────

  Future<List<AlertModel>> getAlerts() async {
    final db = await database;
    final rows =
        await db.query('alerts', orderBy: 'is_read ASC, created_at DESC');
    return rows.map(AlertModel.fromMap).toList();
  }

  Future<void> markAlertRead(int id) async {
    final db = await database;
    await db.update('alerts', {'is_read': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertAlert(AlertModel a) async {
    final db = await database;
    return db.insert('alerts', a.toMap());
  }

  // ─── Checklist ────────────────────────────────────────────────────────────

  Future<List<ChecklistItem>> getChecklistItems(
      int missionId, String type) async {
    final db = await database;
    final rows = await db.query(
      'checklist_items',
      where: 'mission_id = ? AND checklist_type = ?',
      whereArgs: [missionId, type],
      orderBy: 'item_index ASC',
    );
    return rows.map(ChecklistItem.fromMap).toList();
  }

  Future<void> saveChecklistItems(List<ChecklistItem> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      if (item.id != null) {
        batch.update(
          'checklist_items',
          item.toMap(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      } else {
        batch.insert('checklist_items', item.toMap());
      }
    }
    await batch.commit(noResult: true);
  }

  // ─── Flight Log ───────────────────────────────────────────────────────────

  Future<FlightLog?> getFlightLogByMissionId(int missionId) async {
    final db = await database;
    final rows = await db.query(
      'flight_logs',
      where: 'mission_id = ?',
      whereArgs: [missionId],
    );
    if (rows.isEmpty) return null;
    return FlightLog.fromMap(rows.first);
  }

  Future<int> insertFlightLog(FlightLog log) async {
    final db = await database;
    return db.insert('flight_logs', log.toMap());
  }

  Future<void> updateFlightLog(FlightLog log) async {
    final db = await database;
    await db.update('flight_logs', log.toMap(),
        where: 'id = ?', whereArgs: [log.id]);
  }

  // ─── Sync helpers ─────────────────────────────────────────────────────────

  /// Returns all missions that have not yet been pushed to Supabase,
  /// with their crew already populated.
  Future<List<Mission>> getUnsyncedMissions() async {
    final db = await database;
    final rows = await db.query(
      'missions',
      where: 'is_synced = 0',
      orderBy: 'created_at ASC',
    );
    final missions = <Mission>[];
    for (final row in rows) {
      final m = Mission.fromMap(row);
      if (m.id != null) {
        final crewRows = await db.query(
          'crew_members',
          where: 'mission_id = ?',
          whereArgs: [m.id],
        );
        m.crew = crewRows.map(CrewMember.fromMap).toList();
      }
      missions.add(m);
    }
    return missions;
  }

  /// Returns all checklist items for a mission across all checklist types.
  Future<List<ChecklistItem>> getAllChecklistItemsByMissionId(
      int missionId) async {
    final db = await database;
    final rows = await db.query(
      'checklist_items',
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: 'checklist_type ASC, item_index ASC',
    );
    return rows.map(ChecklistItem.fromMap).toList();
  }

  /// Marks a single mission (and its associated flight_log) as synced.
  Future<void> markMissionSynced(int localMissionId) async {
    final db = await database;
    final batch = db.batch();
    batch.update(
      'missions',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [localMissionId],
    );
    batch.update(
      'flight_logs',
      {'is_synced': 1},
      where: 'mission_id = ? AND is_synced = 0',
      whereArgs: [localMissionId],
    );
    await batch.commit(noResult: true);
  }

  // ─── Sync ─────────────────────────────────────────────────────────────────

  Future<int> getUnsyncedCount() async {
    final db = await database;
    int total = 0;
    for (final table in [
      'missions', 'alerts', 'flight_logs',
      'maintenance_logs', 'battery_logs', 'incident_reports',
    ]) {
      final result = await db
          .rawQuery('SELECT COUNT(*) as c FROM $table WHERE is_synced = 0');
      total += (result.first['c'] as int? ?? 0);
    }
    return total;
  }

  Future<void> markAllSynced() async {
    final db = await database;
    final batch = db.batch();
    for (final table in [
      'missions', 'alerts', 'flight_logs',
      'maintenance_logs', 'battery_logs', 'incident_reports',
    ]) {
      batch.update(table, {'is_synced': 1}, where: 'is_synced = 0');
    }
    await batch.commit(noResult: true);
  }

  // ─── Maintenance Logs ─────────────────────────────────────────────────────

  Future<int> insertMaintenanceLog(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('maintenance_logs', data);
  }

  Future<List<Map<String, dynamic>>> getMaintenanceLogs() async {
    final db = await database;
    return db.query('maintenance_logs', orderBy: 'maintenance_date DESC');
  }

  // ─── Battery Logs ─────────────────────────────────────────────────────────

  Future<int> insertBatteryLog(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('battery_logs', data);
  }

  Future<List<Map<String, dynamic>>> getBatteryLogs() async {
    final db = await database;
    return db.query('battery_logs', orderBy: 'log_date DESC');
  }

  // ─── Incident Reports ─────────────────────────────────────────────────────

  Future<int> insertIncidentReport(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('incident_reports', data);
  }

  Future<List<Map<String, dynamic>>> getIncidentReports() async {
    final db = await database;
    return db.query('incident_reports', orderBy: 'incident_date DESC');
  }

  // ─── Flight Plans ─────────────────────────────────────────────────────────

  Future<FlightPlan?> getFlightPlanByMissionId(int missionId) async {
    final db = await database;
    final rows = await db.query('flight_plans',
        where: 'mission_id = ?', whereArgs: [missionId]);
    if (rows.isEmpty) return null;
    return FlightPlan.fromMap(rows.first);
  }

  Future<void> saveFlightPlan(FlightPlan fp) async {
    final db = await database;
    await db.insert(
      'flight_plans',
      fp.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── HIRA Rows ────────────────────────────────────────────────────────────

  Future<List<HiraRow>> getHiraRowsByMissionId(int missionId) async {
    final db = await database;
    final rows = await db.query('hira_rows',
        where: 'mission_id = ?', whereArgs: [missionId]);
    return rows.map(HiraRow.fromMap).toList();
  }

  Future<void> saveHiraRows(int missionId, List<HiraRow> rows) async {
    final db = await database;
    await db.delete('hira_rows', where: 'mission_id = ?', whereArgs: [missionId]);
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('hira_rows', row.toMap());
    }
    await batch.commit(noResult: true);
  }

  // ─── Fit-to-Fly Records ───────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getFitToFlyRecord(int missionId) async {
    final db = await database;
    final rows = await db.query('fit_to_fly_records',
        where: 'mission_id = ?', whereArgs: [missionId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveFitToFlyRecord(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'fit_to_fly_records',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<String> nextMissionId() async {
    final db = await database;
    final year = DateTime.now().year;
    final prefix = '${AppConstants.missionPrefix}-$year-';
    final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM missions WHERE mission_id LIKE '$prefix%'");
    final count = ((result.first['c'] as int?) ?? 0) + 1;
    return '$prefix${count.toString().padLeft(3, '0')}';
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final missions = await db.rawQuery('SELECT COUNT(*) as c FROM missions');
    final aircraft = await db.rawQuery('SELECT COUNT(*) as c FROM aircraft');
    final concurrences = await db.rawQuery(
        "SELECT COUNT(*) as c FROM alerts WHERE type = 'concurrence' AND status = 'pending'");
    final durationResult = await db.rawQuery(
        "SELECT SUM(duration) as total FROM missions WHERE status = 'completed'");
    final totalMin =
        (durationResult.first['total'] as int?) ?? 0;
    return {
      'missions': (missions.first['c'] as int?) ?? 0,
      'aircraft': (aircraft.first['c'] as int?) ?? 0,
      'pendingConcurrences': (concurrences.first['c'] as int?) ?? 0,
      'totalFlightHours':
          double.parse((totalMin / 60.0).toStringAsFixed(1)),
    };
  }

  // ── User Profile ─────────────────────────────────────────────────────────

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    final existing = await db.query('user_profile', limit: 1);
    if (existing.isEmpty) {
      await db.insert('user_profile', profile.toMap());
    } else {
      await db.update(
        'user_profile',
        profile.toMap(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  /// Returns all local profiles eligible as RPIC (role = 'pic' or 'crp',
  /// license_verified = 1, license not expired or no expiry set).
  /// Used for the RPIC picker in mission creation.
  Future<List<UserProfile>> getEligiblePilots() async {
    final db = await database;
    // Fetch pic + crp users who have a verified license
    final rows = await db.query(
      'user_profile',
      where: "role IN ('pic', 'crp') AND license_verified = 1",
    );
    final today = DateTime.now();
    return rows
        .map(UserProfile.fromMap)
        .where((p) {
          if (p.licenseExpiryDate == null) return true;
          try {
            return !DateTime.parse(p.licenseExpiryDate!).isBefore(today);
          } catch (_) {
            return true;
          }
        })
        .toList();
  }
}
