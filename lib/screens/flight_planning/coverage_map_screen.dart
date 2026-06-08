import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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
    area += (pts[j].longitudeInRad - pts[i].longitudeInRad) *
        (2 + sin(pts[i].latitudeInRad) + sin(pts[j].latitudeInRad));
  }
  return (area.abs() * R * R / 2) / 10000;
}

/// Full-screen map for drawing a UAV coverage-area polygon.
///
/// Features:
/// - Tap to add vertices; long-press a marker to delete it.
/// - GPS button centres the map on the device's current location.
/// - Search bar queries Nominatim (OSM) to fly to any named place.
/// - Live area badge (hectares / km²) updates as the polygon changes.
///
/// Returns `List<LatLng>` via `Navigator.pop` when "Done" is tapped,
/// or `null` on back.
class CoverageMapScreen extends StatefulWidget {
  /// Pre-existing vertices to resume editing, if any.
  final List<LatLng>? initialPoints;

  /// Starting map centre. When non-null the map opens at this coordinate and
  /// GPS auto-locate is skipped. When null, the map falls back to GPS (or the
  /// Philippines default if GPS is unavailable).
  final LatLng? initialCenter;

  const CoverageMapScreen({
    super.key,
    this.initialPoints,
    this.initialCenter,
  });

  @override
  State<CoverageMapScreen> createState() => _CoverageMapScreenState();
}

class _CoverageMapScreenState extends State<CoverageMapScreen> {
  final _mapCtrl = MapController();
  final _searchCtrl = TextEditingController();
  late final List<LatLng> _pts;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _pts = List.of(widget.initialPoints ?? []);
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Map interaction ──────────────────────────────────────────────────────────

  void _onMapReady() {
    final hasPoints =
        widget.initialPoints != null && widget.initialPoints!.isNotEmpty;
    if (hasPoints) {
      // Editing an existing polygon — the map already opens at initialCenter
      // (which is the polygon's area); no further action needed.
      return;
    }
    if (widget.initialCenter != null) {
      // Mission coordinates provided — map already starts there via
      // MapOptions.initialCenter; skip GPS auto-locate.
      return;
    }
    // No mission coordinates — fall back to GPS position.
    _autoLocate();
  }

  void _onTap(TapPosition _, LatLng ll) {
    setState(() {
      _pts.add(ll);
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _remove(int i) => setState(() => _pts.removeAt(i));

  // ── GPS location ─────────────────────────────────────────────────────────────

  /// Called once on map ready — silently moves to user location if permission
  /// is already granted, otherwise falls back to the default centre.
  Future<void> _autoLocate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {
      // GPS unavailable — stay at default centre
    }
  }

  /// GPS button handler — requests permission if needed, shows user feedback.
  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Location services are disabled.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 16);
    } catch (_) {
      _snack('Could not get current location.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Place search (Nominatim / OpenStreetMap) ─────────────────────────────────

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'json',
        'limit': '5',
      });
      final res = await http.get(uri,
          headers: {'User-Agent': 'ph.duas.fms/1.0 Flutter'});
      if (res.statusCode == 200 && mounted) {
        setState(() =>
            _searchResults = List<Map<String, dynamic>>.from(jsonDecode(res.body)));
      }
    } catch (_) {
      // Network error — results stay empty
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _goToResult(Map<String, dynamic> r) {
    final lat = double.tryParse(r['lat'] as String? ?? '') ?? 0;
    final lon = double.tryParse(r['lon'] as String? ?? '') ?? 0;
    _mapCtrl.move(LatLng(lat, lon), 15);
    setState(() {
      _searchResults = [];
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
        // ── Map ───────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: widget.initialCenter ?? const LatLng(14.5, 121.0),
            initialZoom: 14,
            onTap: _onTap,
            onMapReady: _onMapReady,
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

        // ── Search panel ──────────────────────────────────────────────────────
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: _buildSearchPanel(),
        ),

        // ── Area badge (hidden while search results are showing) ──────────────
        if (_searchResults.isEmpty && _pts.length >= 3)
          Positioned(
            top: 72,
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

        // ── Instruction hint ──────────────────────────────────────────────────
        if (_pts.isEmpty && _searchResults.isEmpty)
          Positioned(
            bottom: 88,
            left: 24,
            right: 24,
            child: Center(
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
          ),

        // ── GPS button ────────────────────────────────────────────────────────
        Positioned(
          bottom: 24,
          right: 16,
          child: _buildGpsButton(),
        ),
      ]),
    );
  }

  Widget _buildSearchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            const SizedBox(width: 12),
            Icon(Icons.search, size: 18, color: context.colors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(
                    color: context.colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search location…',
                  hintStyle: TextStyle(
                      color: context.colors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                onChanged: (_) {
                  // Rebuild so the clear button shows/hides
                  if (_searchResults.isNotEmpty) {
                    setState(() => _searchResults = []);
                  } else {
                    setState(() {});
                  }
                },
              ),
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              )
            else if (_searchCtrl.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close,
                    size: 16, color: context.colors.textMuted),
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _searchResults = [];
                }),
              ),
          ]),
        ),
        // Results dropdown
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _searchResults.asMap().entries.map((e) {
                final name =
                    e.value['display_name'] as String? ?? '';
                final isFirst = e.key == 0;
                final isLast = e.key == _searchResults.length - 1;
                return InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: isFirst ? const Radius.circular(12) : Radius.zero,
                    bottom:
                        isLast ? const Radius.circular(12) : Radius.zero,
                  ),
                  onTap: () => _goToResult(e.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.place_outlined,
                          size: 15, color: context.colors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildGpsButton() {
    return GestureDetector(
      onTap: _isLocating ? null : _goToMyLocation,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.card,
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Center(
          child: _isLocating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : const Icon(Icons.my_location,
                  size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}
