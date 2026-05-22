import 'crew_member.dart';

class Mission {
  int? id;
  String missionId;      // e.g. 'UAS-2025-001'
  String title;
  String status;         // planning | in_progress | completed | cancelled
  String date;
  String timeStr;
  String location;
  double? latitude;
  double? longitude;
  String environment;
  String objective;
  int? aircraftId;
  String aircraftName;
  String aircraftType;   // multi-rotor | vtol | fixed-wing
  int? duration;         // total flight minutes

  // CRP concurrence fields (replaces approved_by + hazard_risk + risk_level)
  String crpAdvisoryNotes;
  bool crpConcurrenceRequired;

  String organizationId; // Supabase org UUID (empty = not linked yet)
  String? createdBy;     // Supabase user UUID of CRP who created this

  // Step completion flags
  bool hasFlightPlanComplete;
  bool hasHiraComplete;
  bool hasEquipmentComplete;
  bool hasFitToFlyComplete;
  bool hasPreflightComplete;
  bool hasInflightComplete;
  bool hasPostflightComplete;
  bool hasFlightlogComplete;

  bool isSynced;
  String createdAt;
  List<CrewMember> crew;

  Mission({
    this.id,
    required this.missionId,
    required this.title,
    required this.status,
    required this.date,
    required this.timeStr,
    required this.location,
    this.latitude,
    this.longitude,
    required this.environment,
    required this.objective,
    this.aircraftId,
    required this.aircraftName,
    required this.aircraftType,
    this.duration,
    this.crpAdvisoryNotes = '',
    this.crpConcurrenceRequired = false,
    this.organizationId = '',
    this.createdBy,
    this.hasFlightPlanComplete = false,
    this.hasHiraComplete = false,
    this.hasEquipmentComplete = false,
    this.hasFitToFlyComplete = false,
    this.hasPreflightComplete = false,
    this.hasInflightComplete = false,
    this.hasPostflightComplete = false,
    this.hasFlightlogComplete = false,
    this.isSynced = false,
    required this.createdAt,
    this.crew = const [],
  });

  factory Mission.fromMap(Map<String, dynamic> map) {
    return Mission(
      id: map['id'],
      missionId: map['mission_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      status: _normalizeStatus(map['status'] as String? ?? 'planning'),
      date: map['date'] as String? ?? '',
      timeStr: map['time_str'] as String? ?? '',
      location: map['location'] as String? ?? '',
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      environment: map['environment'] as String? ?? '',
      objective: map['objective'] as String? ?? '',
      aircraftId: map['aircraft_id'] as int?,
      aircraftName: map['aircraft_name'] as String? ?? '',
      aircraftType: map['aircraft_type'] as String? ?? '',
      duration: map['duration'] as int?,
      crpAdvisoryNotes: map['crp_advisory_notes'] as String? ?? '',
      crpConcurrenceRequired: (map['crp_concurrence_required'] as int?) == 1,
      organizationId: map['organization_id'] as String? ?? '',
      createdBy: map['created_by'] as String?,
      hasFlightPlanComplete: (map['has_flight_plan_complete'] as int?) == 1,
      hasHiraComplete: (map['has_hira_complete'] as int?) == 1,
      hasEquipmentComplete: (map['has_equipment_complete'] as int?) == 1,
      hasFitToFlyComplete: (map['has_fit_to_fly_complete'] as int?) == 1,
      hasPreflightComplete: (map['has_preflight_complete'] as int?) == 1,
      hasInflightComplete: (map['has_inflight_complete'] as int?) == 1,
      hasPostflightComplete: (map['has_postflight_complete'] as int?) == 1,
      hasFlightlogComplete: (map['has_flightlog_complete'] as int?) == 1,
      isSynced: (map['is_synced'] as int?) == 1,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  // Migrate legacy 'approved' status → 'planning'
  static String _normalizeStatus(String s) =>
      s == 'approved' ? 'planning' : s;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mission_id': missionId,
      'title': title,
      'status': status,
      'date': date,
      'time_str': timeStr,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'environment': environment,
      'objective': objective,
      'aircraft_id': aircraftId,
      'aircraft_name': aircraftName,
      'aircraft_type': aircraftType,
      'duration': duration,
      'crp_advisory_notes': crpAdvisoryNotes,
      'crp_concurrence_required': crpConcurrenceRequired ? 1 : 0,
      'organization_id': organizationId,
      'created_by': createdBy,
      'has_flight_plan_complete': hasFlightPlanComplete ? 1 : 0,
      'has_hira_complete': hasHiraComplete ? 1 : 0,
      'has_equipment_complete': hasEquipmentComplete ? 1 : 0,
      'has_fit_to_fly_complete': hasFitToFlyComplete ? 1 : 0,
      'has_preflight_complete': hasPreflightComplete ? 1 : 0,
      'has_inflight_complete': hasInflightComplete ? 1 : 0,
      'has_postflight_complete': hasPostflightComplete ? 1 : 0,
      'has_flightlog_complete': hasFlightlogComplete ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt,
    };
  }

  // ── Computed ───────────────────────────────────────────────────────────────

  bool get isCompleted => status == 'completed';
  bool get isPlanning => status == 'planning';
  bool get isInProgress => status == 'in_progress';
  bool get isCancelled => status == 'cancelled';

  /// True if the post-flight step is done — at this point navigation is locked.
  bool get isPostFlightDone => hasPostflightComplete;

  String get statusLabel {
    switch (status) {
      case 'planning':
        return 'Planning';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get formattedDuration {
    if (duration == null) return '--';
    final h = duration! ~/ 60;
    final m = duration! % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}
