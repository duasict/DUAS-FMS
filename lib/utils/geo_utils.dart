import 'dart:convert';
import 'dart:math';

/// Calculates the area of a GeoJSON Polygon or Feature in hectares.
/// Returns 0 if the GeoJSON is invalid or not a polygon.
double calcAreaHa(String geoJson) {
  try {
    final d = jsonDecode(geoJson) as Map<String, dynamic>;
    final type = d['type'] as String?;
    List<dynamic> coords;
    if (type == 'Polygon') {
      coords = (d['coordinates'] as List).first as List;
    } else if (type == 'Feature') {
      final geo = d['geometry'] as Map<String, dynamic>;
      coords = (geo['coordinates'] as List).first as List;
    } else {
      return 0;
    }
    const R = 6371000.0;
    double area = 0;
    for (int i = 0; i < coords.length; i++) {
      final j = (i + 1) % coords.length;
      final lonI = (coords[i][0] as num).toDouble() * pi / 180;
      final latI = (coords[i][1] as num).toDouble() * pi / 180;
      final lonJ = (coords[j][0] as num).toDouble() * pi / 180;
      final latJ = (coords[j][1] as num).toDouble() * pi / 180;
      area += (lonJ - lonI) * (2 + sin(latI) + sin(latJ));
    }
    return (area.abs() * R * R / 2) / 10000;
  } catch (_) {
    return 0;
  }
}

/// Formats an area in hectares to a human-readable string.
String formatAreaHa(double ha) {
  if (ha <= 0) return '';
  return ha >= 100
      ? '${(ha / 100).toStringAsFixed(2)} km²'
      : '${ha.toStringAsFixed(2)} ha';
}
