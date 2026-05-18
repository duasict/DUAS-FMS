class FlightPlan {
  int? id;
  int missionId;
  String areaOfOperation;
  double? windSpeed;
  double? visibility;
  String weatherForecast;
  String airspaceClass;
  String notams;
  String airspaceRestrictions;
  String missionObjectives;
  String contingencyPlan;
  String createdAt;

  FlightPlan({
    this.id,
    required this.missionId,
    required this.areaOfOperation,
    this.windSpeed,
    this.visibility,
    required this.weatherForecast,
    required this.airspaceClass,
    required this.notams,
    required this.airspaceRestrictions,
    required this.missionObjectives,
    required this.contingencyPlan,
    required this.createdAt,
  });

  factory FlightPlan.fromMap(Map<String, dynamic> map) {
    return FlightPlan(
      id: map['id'],
      missionId: map['mission_id'],
      areaOfOperation: map['area_of_operation'] ?? '',
      windSpeed: map['wind_speed'] != null
          ? (map['wind_speed'] as num).toDouble()
          : null,
      visibility: map['visibility'] != null
          ? (map['visibility'] as num).toDouble()
          : null,
      weatherForecast: map['weather_forecast'] ?? '',
      airspaceClass: map['airspace_class'] ?? '',
      notams: map['notams'] ?? '',
      airspaceRestrictions: map['airspace_restrictions'] ?? '',
      missionObjectives: map['mission_objectives'] ?? '',
      contingencyPlan: map['contingency_plan'] ?? '',
      createdAt: map['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mission_id': missionId,
      'area_of_operation': areaOfOperation,
      'wind_speed': windSpeed,
      'visibility': visibility,
      'weather_forecast': weatherForecast,
      'airspace_class': airspaceClass,
      'notams': notams,
      'airspace_restrictions': airspaceRestrictions,
      'mission_objectives': missionObjectives,
      'contingency_plan': contingencyPlan,
      'created_at': createdAt,
    };
  }
}
