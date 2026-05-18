import 'crew_member.dart';

class Mission {
  int? id;
  String missionId;
  String title;
  String status; // approved, in_progress, completed
  String date;
  String timeStr;
  String location;
  double? latitude;
  double? longitude;
  String environment;
  String objective;
  int? aircraftId;
  String aircraftName;
  String aircraftType; // multi-rotor, vtol
  String hazardRisk;
  String riskLevel; // low, medium, high
  String approvedBy;
  int? duration; // minutes
  bool hasFlightPlanComplete;
  bool hasHiraComplete;
  bool hasApprovalComplete;
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
    required this.hazardRisk,
    required this.riskLevel,
    required this.approvedBy,
    this.duration,
    this.hasFlightPlanComplete = false,
    this.hasHiraComplete = false,
    this.hasApprovalComplete = false,
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
      missionId: map['mission_id'],
      title: map['title'],
      status: map['status'],
      date: map['date'],
      timeStr: map['time_str'],
      location: map['location'],
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      environment: map['environment'],
      objective: map['objective'],
      aircraftId: map['aircraft_id'],
      aircraftName: map['aircraft_name'],
      aircraftType: map['aircraft_type'],
      hazardRisk: map['hazard_risk'],
      riskLevel: map['risk_level'],
      approvedBy: map['approved_by'],
      duration: map['duration'],
      hasFlightPlanComplete: map['has_flight_plan_complete'] == 1,
      hasHiraComplete: map['has_hira_complete'] == 1,
      hasApprovalComplete: map['has_approval_complete'] == 1,
      hasEquipmentComplete: map['has_equipment_complete'] == 1,
      hasFitToFlyComplete: map['has_fit_to_fly_complete'] == 1,
      hasPreflightComplete: map['has_preflight_complete'] == 1,
      hasInflightComplete: map['has_inflight_complete'] == 1,
      hasPostflightComplete: map['has_postflight_complete'] == 1,
      hasFlightlogComplete: map['has_flightlog_complete'] == 1,
      isSynced: map['is_synced'] == 1,
      createdAt: map['created_at'],
    );
  }

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
      'hazard_risk': hazardRisk,
      'risk_level': riskLevel,
      'approved_by': approvedBy,
      'duration': duration,
      'has_flight_plan_complete': hasFlightPlanComplete ? 1 : 0,
      'has_hira_complete': hasHiraComplete ? 1 : 0,
      'has_approval_complete': hasApprovalComplete ? 1 : 0,
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

  bool get isCompleted => status == 'completed';
  bool get isApproved => status == 'approved';
  bool get isInProgress => status == 'in_progress';

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'approved':
        return 'Approved';
      case 'in_progress':
        return 'In Progress';
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
