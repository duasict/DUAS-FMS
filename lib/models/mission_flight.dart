class MissionFlight {
  int? id;
  int missionId;
  int flightNum;
  String takeoffTime;
  String landingTime;
  double? takeoffLat;
  double? takeoffLon;
  double? landingLat;
  double? landingLon;

  MissionFlight({
    this.id,
    required this.missionId,
    required this.flightNum,
    this.takeoffTime = '',
    this.landingTime = '',
    this.takeoffLat,
    this.takeoffLon,
    this.landingLat,
    this.landingLon,
  });

  factory MissionFlight.fromMap(Map<String, dynamic> m) => MissionFlight(
        id: m['id'] as int?,
        missionId: m['mission_id'] as int,
        flightNum: m['flight_num'] as int,
        takeoffTime: m['takeoff_time'] as String? ?? '',
        landingTime: m['landing_time'] as String? ?? '',
        takeoffLat: m['takeoff_lat'] != null
            ? (m['takeoff_lat'] as num).toDouble()
            : null,
        takeoffLon: m['takeoff_lon'] != null
            ? (m['takeoff_lon'] as num).toDouble()
            : null,
        landingLat: m['landing_lat'] != null
            ? (m['landing_lat'] as num).toDouble()
            : null,
        landingLon: m['landing_lon'] != null
            ? (m['landing_lon'] as num).toDouble()
            : null,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'mission_id': missionId,
        'flight_num': flightNum,
        'takeoff_time': takeoffTime,
        'landing_time': landingTime,
        'takeoff_lat': takeoffLat,
        'takeoff_lon': takeoffLon,
        'landing_lat': landingLat,
        'landing_lon': landingLon,
      };

  int get totalMin {
    try {
      final t = takeoffTime.split(':');
      final l = landingTime.split(':');
      if (t.length == 2 && l.length == 2) {
        final a = int.parse(t[0]) * 60 + int.parse(t[1]);
        final b = int.parse(l[0]) * 60 + int.parse(l[1]);
        return (b - a).clamp(0, 9999);
      }
    } catch (_) {}
    return 0;
  }
}
