import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';

/// Returns the approximate area of a closed geographic polygon in hectares.
/// Uses the spherical excess formula (Chamberlain & Duquette 2007) — accurate
/// for polygons up to ~1,000 km²; well beyond any UAV operational area.
double polygonAreaHa(List<LatLng> pts) {
  if (pts.length < 3) return 0;
  const R = 6371000.0;
  double area = 0;
  for (int i = 0; i < pts.length; i++) {
    final j = (i + 1) % pts.length;
    final lng1 = pts[i].longitudeInRad;
    final lat1 = pts[i].latitudeInRad;
    final lng2 = pts[j].longitudeInRad;
    final lat2 = pts[j].latitudeInRad;
    area += (lng2 - lng1) * (2 + sin(lat1) + sin(lat2));
  }
  return (area.abs() * R * R / 2) / 10000;
}

/// Full-screen map that lets the user tap to build a coverage-area polygon.
///
/// Returns `List<LatLng>` (the polygon vertices, excluding the closing point)
/// via `Navigator.pop` when the user taps "Done".  Returns `null` on back.
class CoverageMapScreen extends StatefulWidget {
  /// Pre-existing vertices to edit, if any.
  final List<LatLng>? initialPoints;

  /// Starting map position.  Defaults to central Philippines.
  final LatLng initialCenter;

  const CoverageMapScreen({
    super.key,
    this.initialPoints,
    this.initialCenter = const LatLng(14.5, 121.0),
  });

  @override
  State<CoverageMapScreen> createState() => _CoverageMapScreenState();
}

class _CoverageMapScreenState extends State<CoverageMapScreen> {
  final _mapCtrl = MapController();
  late final List<LatLng> _pts;

  @override
  void initState() {
    super.initState();
    _pts = List.of(widget.initialPoints ?? []);
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  void _onTap(TapPosition _, LatLng ll) => setState(() => _pts.add(ll));
  void _remove(int i) => setState(() => _pts.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final ha = polygonAreaHa(_pts);
    final areaLabel = ha >= 100
        ? '${(ha / 100).toStringAsFixed(2)} km²'
        : '${ha.toStringAsFixed(2)} ha';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Coverage Area'),
        actions: [
          if (_pts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear all',
              onPressed: () => setState(() => _pts.clear()),
            ),
          if (_pts.length >= 3)
            TextButton(
              onPressed: () => Navigator.pop(context, List.of(_pts)),
              child: const Text(
                'Done',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: 14,
            onTap: _onTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ph.duas.fms',
            ),
            if (_pts.length >= 3)
              PolygonLayer(polygons: [
                Polygon(
                  points: _pts,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderColor: AppColors.primary,
                  borderStrokeWidth: 2,
                ),
              ]),
            if (_pts.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                  points: [..._pts, _pts.first],
                  color: AppColors.primary.withValues(alpha: 0.6),
                  strokeWidth: 1.5,
                ),
              ]),
            MarkerLayer(
              markers: _pts.asMap().entries.map((e) {
                return Marker(
                  point: e.value,
                  width: 28,
                  height: 28,
                  child: GestureDetector(
                    onLongPress: () => _remove(e.key),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Area badge
        if (_pts.length >= 3)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.card.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.colors.border),
                ),
                child: Text(
                  'Area: $areaLabel',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        // Instruction hint shown before first tap
        if (_pts.isEmpty)
          Positioned(
            bottom: 28,
            left: 24,
            right: 24,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.card.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Text(
                'Tap the map to add vertices\nLong-press a marker to remove it',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 12),
              ),
            ),
          ),
      ]),
    );
  }
}
