import 'dart:convert';

class FlightDuration {
  String flightNum;
  String takeoff;
  String landing;
  int totalMin;

  FlightDuration({
    required this.flightNum,
    required this.takeoff,
    required this.landing,
    required this.totalMin,
  });

  factory FlightDuration.fromMap(Map<String, dynamic> map) {
    return FlightDuration(
      flightNum: map['flightNum'] ?? '',
      takeoff: map['takeoff'] ?? '',
      landing: map['landing'] ?? '',
      totalMin: map['totalMin'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flightNum': flightNum,
      'takeoff': takeoff,
      'landing': landing,
      'totalMin': totalMin,
    };
  }
}

class FlightLog {
  int? id;
  int missionId;
  String dateTime;
  String location;
  double? latitude;
  double? longitude;
  double? altitudeAgl;
  double? highestPoint;
  String landingZone;
  String platformType; // multi-rotor, vtol
  String model;
  double? mtow;
  List<String> payload;
  String missionType;
  String rpic;
  String vo;
  String tech;
  List<FlightDuration> flights;
  double? weatherWind;
  double? weatherVisibility;
  String weatherCloud;
  String notams;
  List<String> anomalies;
  String? dataCapturedGeotiff;
  String? dataCapturedPhotos;
  String? dataCapturedVideo;
  bool dataCapturedLidar;
  String nextMaintenance;
  bool isSynced;

  FlightLog({
    this.id,
    required this.missionId,
    required this.dateTime,
    required this.location,
    this.latitude,
    this.longitude,
    this.altitudeAgl,
    this.highestPoint,
    this.landingZone = '',
    required this.platformType,
    required this.model,
    this.mtow,
    this.payload = const [],
    required this.missionType,
    required this.rpic,
    required this.vo,
    required this.tech,
    this.flights = const [],
    this.weatherWind,
    this.weatherVisibility,
    this.weatherCloud = '',
    this.notams = '',
    this.anomalies = const [],
    this.dataCapturedGeotiff,
    this.dataCapturedPhotos,
    this.dataCapturedVideo,
    this.dataCapturedLidar = false,
    this.nextMaintenance = '',
    this.isSynced = false,
  });

  factory FlightLog.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic val) {
      if (val == null || val.toString().isEmpty) return [];
      try {
        return List<String>.from(jsonDecode(val));
      } catch (_) {
        return [];
      }
    }

    List<FlightDuration> parseFlights(dynamic val) {
      if (val == null || val.toString().isEmpty) return [];
      try {
        final list = jsonDecode(val) as List;
        return list.map((e) => FlightDuration.fromMap(e)).toList();
      } catch (_) {
        return [];
      }
    }

    return FlightLog(
      id: map['id'],
      missionId: map['mission_id'],
      dateTime: map['date_time'] ?? '',
      location: map['location'] ?? '',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      altitudeAgl: map['altitude_agl'] != null ? (map['altitude_agl'] as num).toDouble() : null,
      highestPoint: map['highest_point'] != null ? (map['highest_point'] as num).toDouble() : null,
      landingZone: map['landing_zone'] ?? '',
      platformType: map['platform_type'] ?? 'multi-rotor',
      model: map['model'] ?? '',
      mtow: map['mtow'] != null ? (map['mtow'] as num).toDouble() : null,
      payload: parseStringList(map['payload']),
      missionType: map['mission_type'] ?? '',
      rpic: map['rpic'] ?? '',
      vo: map['vo'] ?? '',
      tech: map['tech'] ?? '',
      flights: parseFlights(map['flights']),
      weatherWind: map['weather_wind'] != null ? (map['weather_wind'] as num).toDouble() : null,
      weatherVisibility: map['weather_visibility'] != null ? (map['weather_visibility'] as num).toDouble() : null,
      weatherCloud: map['weather_cloud'] ?? '',
      notams: map['notams'] ?? '',
      anomalies: parseStringList(map['anomalies']),
      dataCapturedGeotiff: map['data_geotiff'],
      dataCapturedPhotos: map['data_photos'],
      dataCapturedVideo: map['data_video'],
      dataCapturedLidar: map['data_lidar'] == 1,
      nextMaintenance: map['next_maintenance'] ?? '',
      isSynced: map['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mission_id': missionId,
      'date_time': dateTime,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'altitude_agl': altitudeAgl,
      'highest_point': highestPoint,
      'landing_zone': landingZone,
      'platform_type': platformType,
      'model': model,
      'mtow': mtow,
      'payload': jsonEncode(payload),
      'mission_type': missionType,
      'rpic': rpic,
      'vo': vo,
      'tech': tech,
      'flights': jsonEncode(flights.map((f) => f.toMap()).toList()),
      'weather_wind': weatherWind,
      'weather_visibility': weatherVisibility,
      'weather_cloud': weatherCloud,
      'notams': notams,
      'anomalies': jsonEncode(anomalies),
      'data_geotiff': dataCapturedGeotiff,
      'data_photos': dataCapturedPhotos,
      'data_video': dataCapturedVideo,
      'data_lidar': dataCapturedLidar ? 1 : 0,
      'next_maintenance': nextMaintenance,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  int get totalFlightMinutes =>
      flights.fold(0, (sum, f) => sum + f.totalMin);
}
